# Gathr — Security Audit & Threat Model

**Date:** 2026-07-07
**Scope:** Full platform — Supabase backend (RLS, edge functions, RPCs, Realtime), Flutter client (`apps/flutter_app`) + admin console (`apps/admin_web`), game integrity / anti-cheat, monetization & economy, CI / infra / supply-chain.
**Method:** Four parallel code-reading audits. Every finding below was verified against actual source (file paths + line numbers cited), not inferred.

> This is a defensive audit for the platform owner. Findings describe how a malicious *player* (holding only the app's public anon key and a throwaway account) could exploit the current code, and how to close each hole.

---

## 1. Executive summary

The **edge-function layer is well built** — game-end rewards, tournament money flows, and move validation are server-authoritative, idempotent, and race-guarded. The **weak point is the database RLS layer beneath it**, plus a few fail-open webhooks and a client-authoritative game-state model for half the games.

One root cause dominates: **RLS policies gate *row ownership* but not *column mutability*.** A user can update their own `profiles` row — including `coins`, `gems`, and `subscription_tier`. That single gap makes the entire carefully-built economy bypassable, and the same pattern repeats across tournaments, challenges, season pass, and leaderboards. The whole edge-function economy is moot if the balance column is client-writable.

Second structural issue: **private card hands live in a world-readable `game_states` row**, so opponents can read each other's cards in real time. Redaction logic exists but only guards one of several read paths.

### Severity tally

| Severity | Count | Themes |
|---|---|---|
| **Critical** | 7 | Client-writable balances/tier; self-rigged tournament standings; free tournament entry; unclamped gem minting; hidden hands readable by opponents; anonymous accounts amplify everything; passthrough games trust the client for legality |
| **High** | 8 | Fail-open RevenueCat & push webhooks; client-writable challenge/season/leaderboard progress; self-hosted CI on personal Mac; client-side bots let host cheat; no rate limiting; plaintext session tokens; friend-request spam |
| **Medium** | ~12 | Missing `WITH CHECK`; `password_hash` world-readable; `record_game_completion` callable by anyone; admin console gated on session not admin; ATS/dev-env leaks in release builds; ads without SSV; guest farming |
| **Low / Info** | ~15 | Logging hygiene, CORS `*`, floating deps, Shorebird governance, gitignore leaks, etc. |

### Fix priority (do these first)

1. **C1 — Lock down `profiles` column writes.** The master key; most economy exploits collapse once balances are service-role-only.
2. **C5 — Move private hands out of the world-readable `game_states` row.**
3. **C2 / C4 / H-series — Remove client INSERT/UPDATE on `tournament_participants`, `user_challenges`, `user_season_progress`, `leaderboards`.**
4. **C3 — Clamp `gem_cup` and gate tournament creation on tier.**
5. **H1 / H4(push) — Make RevenueCat and notify-dispatch webhooks fail *closed*.**
6. **Passthrough game validation + rate limiting.**
7. **H — Get untrusted-branch CI off the personal dev Mac.**

---

## 2. Critical findings

### C1 — Any user can mint unlimited coins/gems and grant themselves Max tier
**Where:** `supabase/migrations/20260226000000_initial_schema.sql:666`; client proof `apps/flutter_app/lib/features/shop/data/supabase_currency_repository.dart:91`

```sql
create policy "profiles_update_own" on profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
```

The policy restricts *which row* but not *which columns*. `coins`, `gems`, `xp`, `level`, `subscription_tier`, `account_type`, `referred_by`, `daily_earn_state` are all directly writable by the row owner (only guarded by `CHECK (coins >= 0)`). The Flutter shop repo already writes balances straight to `profiles`, proving the `authenticated` role has this grant.

**Exploit:** with the embedded anon key + own JWT (both trivially extractable):
```
PATCH /rest/v1/profiles?id=eq.<myuid>  {"coins":1e9,"gems":1e9,"subscription_tier":"max"}
```
→ instant unlimited hard currency + permanent Max (unlocks paywalled features, tournament hosting, earn multipliers). Every server-side guard (daily caps, ledgers, double-credit indexes) is bypassed because the attacker never calls the edge functions.

**Fix:** Remove client write access to sensitive columns. Preferred: split balances into a `wallets` table with **no client UPDATE policy** and make edge functions the only mutation path (delete the client's direct `profiles.update`). Minimum: `REVOKE UPDATE (coins, gems, xp, level, subscription_tier, subscription_expires_at, account_type, daily_earn_state, referred_by) ON profiles FROM authenticated;` and grant UPDATE only on safe columns (`display_name, avatar_url, bio, preferred_*, tz_offset_min`). Move all client "spend" flows server-side.

---

### C2 — Tournament players can rewrite their own standings and win the prize pool
**Where:** `supabase/migrations/20260310000000_add_tournaments.sql:221-224`; consumer `supabase/functions/_shared/tournament_report.ts:496-511`

```sql
create policy "Users can update own participation"
  on tournament_participants for update using (user_id = auth.uid());
```

No `WITH CHECK`, no column restriction. `completeTournament` ranks purely by `wins desc, points desc, losses asc, seed asc`.

**Exploit:** a registered participant sets `wins = 9999` on their own row → ranked #1 at completion → receives the prize pool funded by everyone else's real entry fees. Can also flip own `status` from `eliminated` back to `active`.

**Fix:** Remove the client UPDATE policy — standings are server-authoritative and already flow through edge functions. Compute payouts strictly from `tournament_entry_ledger`.

---

### C3 — Player-created tournaments + unclamped `gem_cup` = unlimited gem minting
**Where:** creation RLS `20260310000000_add_tournaments.sql:203-205`; payout `_shared/tournament_report.ts:531-554`

Any authenticated user can insert a tournament with arbitrary `settings` and `prize_pool` — the "Pro/Max-only hosting" design rule is **not enforced anywhere** in SQL or the create path. Coin/gem `prize_pool` payouts are correctly clamped to the net entry pool (`:528-529`), **but `gem_cup` bonuses are not** (`:539,553`).

**Exploit:** insert a tournament with `min_participants=2`, `settings={gem_cup:{"1":1000000}}`, register two controlled accounts, start it (organizer check passes), finish → 1,000,000 gems minted from nothing to place 1. This survives a C1 fix, so it must be closed independently.

**Fix:** Enforce Pro/Max hosting server-side; forbid `gem_cup` on player-created tournaments (admin/official only); clamp all gem payouts (including `gem_cup`) to a funded budget.

---

### C4 — Free entry into paid tournaments via direct INSERT
**Where:** `20260310000000_add_tournaments.sql:217-219`

```sql
create policy "Users can register themselves"
  on tournament_participants for insert with check (user_id = auth.uid());
```

`tournament-register` debits entry fees, enforces tier gates and caps, and writes the ledger — but nothing forces registration through it. The client can `INSERT` a participant row directly, skipping payment.

**Exploit:** `insert({tournament_id, user_id: myUid})` → enter any gem/coin tournament free, then compete for prizes.

**Fix:** Remove the client INSERT policy; make `tournament-register` the only path.

---

### C5 — Opponents can read each other's hidden card hands in real time
**Where:** `20260226000000_initial_schema.sql:682-683`; Realtime `20260311000000_enable_realtime.sql:2`; redaction proof `supabase/functions/reconcile-state/index.ts:413-435`

```sql
create policy "game_states_select_room_members" on game_states for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = game_states.room_id and rp.user_id = auth.uid()));
```

`game_states.state_data` holds the full authoritative state including every player's `hands` and the unrevealed `trumpSuit` (confirmed by `redactForSpectator()` which strips exactly those fields). RLS grants **any** room member — including spectators — SELECT on the raw, unredacted row, and the table is in the Realtime publication.

**Exploit:** in any card game (twenty_nine, oh_hell, hearts, bridge, rummy), a player runs `supabase.from('game_states').select('state_data').eq('room_id', id)` or subscribes via Realtime and reads every opponent's hand + hidden trump. The `reconcile-state` redaction is irrelevant because it isn't the only read path. Complete defeat of card-game secrecy.

**Fix (structural):** Store private hands in a separate `player_hands` table with RLS `user_id = auth.uid()`, keeping only public state in `game_states`; **or** remove `game_states` from client-readable RLS/Realtime entirely and serve per-player redacted views exclusively through an edge function that filters by caller.

---

### C6 — Passthrough games trust the client for move legality and game state
**Where:** `supabase/functions/_shared/game_rules/passthrough.ts:7-44`; dispatch `_shared/game_rules/index.ts:26-28`; validate `supabase/functions/validate-move/index.ts:64-71`; client `apps/flutter_app/lib/features/game/providers/game_provider.dart:187-208`

Two-tier validation: **fully validated** games (twenty_nine, oh_hell, bridge, ludo) re-compute state server-side; **passthrough** games (chess, hearts, spades, sequence, rummy) only check "is it your turn?" — `passthroughValidate` does no legality checking and `passthroughApply` only records `lastMove` without computing new state. Hearts and Spades have server-side *setup* but fall through to passthrough on *moves* (no `validateHeartsMove`/`validateSpadesMove`). The client's `deserializeGameState` returns `null` for these games, so clients ignore the server response and treat their own local computation as authoritative.

**Exploit:** In chess, submit `{type:'movePiece', player_id: me, from:'e7', to:'e5'}` on your turn to move the opponent's piece, or `{type:'resign', player_id: opponent}` — the server accepts anything as long as `currentPlayerId` matches. Illegal moves, out-of-phase win claims, and permanent client desyncs are all possible.

**Fix:** Implement `validateChessMove`/`validateHeartsMove`/`validateSpadesMove`/`validateSequenceMove`/`validateRummyMove` that check legality and re-compute authoritative state server-side; add `fromJson` for those states so clients adopt server state. Prioritize chess/hearts/spades (most popular).

---

### C7 — Anonymous sign-ins amplify every write flaw to zero-cost, throwaway attackers
**Where:** `supabase/config.toml:39,44`

```toml
enable_anonymous_sign_ins = true
[auth.email] enable_confirmations = false
```

Anyone can obtain a valid `authenticated` JWT instantly with the public anon key — no email, no verification. Every "authenticated"-role RLS hole above (C1–C5, H-series) is therefore exploitable by disposable identities at scale, and abusive accounts cost nothing to recreate.

**Fix:** Guest play is an intentional feature, so the real mitigation is making the RLS policies safe (C1–C5). Additionally: enable email confirmation for the registered path in staging/prod, and gate write-heavy/economy tables to `account_type='registered'`. (The local `config.toml` value doesn't govern prod — verify the hosted project config.)

---

## 3. High findings

### H1 — RevenueCat webhook fails open, trusts client user-id, and replays currency grants
**Where:** `supabase/functions/verify-subscription/index.ts:24-30,52-80,631-636`

`if (webhookSecret && authHeader !== ...)` — if `REVENUECAT_WEBHOOK_SECRET` is unset, the auth check is **skipped entirely**. `app_user_id` comes from the request body and is used verbatim as the profile to upgrade. No RevenueCat signature verification. `RENEWAL`/`INITIAL_PURCHASE` grant coins+gems with no idempotency guard.

**Exploit:** POST `{event:{type:"INITIAL_PURCHASE", app_user_id:"<any>", product_id:"max"}}` → free Max on any account + minted currency; replay `RENEWAL` to farm gems.

**Fix:** Fail closed (reject if secret unset). Verify RevenueCat's signature per their spec. Dedupe on `event.id`. Explicitly set `verify_jwt=false` in `config.toml` so reachability is intentional and reviewed.

---

### H2 — notify-dispatch webhook fails open on a committed default secret, sends spoofed pushes to anyone
**Where:** `supabase/functions/notify-dispatch/index.ts:33-36`; `config.toml:74-75` (`verify_jwt = false`); default seeded in `20260707000000_push_backbone.sql:71`

```js
const secret = Deno.env.get('NOTIFY_WEBHOOK_SECRET') ?? 'local-dev-webhook-secret';
if (req.headers.get('x-webhook-secret') !== secret) return errorResponse('Unauthorized', 401);
```

Publicly reachable (`verify_jwt=false`). If the env var is unset in prod, it falls back to the literal string committed to the repo. The handler then builds a push from attacker-supplied `record` with a spoofed `sender_id`.

**Exploit:** POST a fake `dm` event with `recipient_id:<victim>` and phishing `content` → spoofed-sender phishing push delivered to arbitrary users.

**Fix:** Fail closed if `NOTIFY_WEBHOOK_SECRET` is unset. Never commit a usable fallback. Require a strong random secret in staging/prod for both the function and `webhook_config`.

---

### H3 — Challenge, season-pass, and leaderboard progress are client-writable, and reward functions trust them
**Where:** `user_challenges` `initial_schema.sql:755-756`; `user_season_progress` `:762-764`; `leaderboards` `:694-695`; consumers `claim-challenge-reward/index.ts:37-43`, `grant-season-reward/index.ts:50-56,332-338`

Users can UPDATE their own progress rows. `claim-challenge-reward` credits whenever `completed_at` is set and `reward_claimed` is false — both client-controlled — and there's **no idempotency guard** on the ledger for `challenge_reward`. `grant-season-reward` trusts client-written `level` and `premium_purchased_at`. `leaderboards` lets users write their own `rating`/`wins`.

**Exploit (infinite reclaim):** set `completed_at=now()`, claim, reset `reward_claimed=false`, repeat forever. Or set `season_progress.level=999` + `premium_purchased_at=now()` to claim every premium reward free. Or set `rating=99999` to top leaderboards and skew matchmaking.

**Fix:** Make these progress columns service-role-write-only (advanced by the server on validated game events). Add unique-index idempotency guards on the currency ledger for each reward reason.

---

### H4 — Daily-bonus amount is driven by a client-writable streak
**Where:** `supabase/functions/claim-daily-bonus/index.ts:59-84`

Once-per-day is enforced via the ledger, but the reward *tier* (day 30 pays 100 coins **+ 50 gems**) is chosen from `profiles.current_activity.daily_streak`, which is client-writable (C1).

**Exploit:** set `daily_streak=29`, claim the day-30 reward (incl. 50 gems) every single day.

**Fix:** Derive the streak server-side from `currency_transactions` daily-bonus history; never read it from a client-writable field.

---

### H5 — Client-side bots let a malicious host cheat
**Where:** `apps/flutter_app/lib/features/game/providers/bot_move_controller.dart:40-209`; auth check `validate-move/index.ts:49-57`

Only the host's client runs bots, and it holds the full game state (including all hands) plus the ability to submit moves on behalf of bots. The server validates only that the bot id is in `room_config.bots` and it's the bot's turn — not that the move is reasonable.

**Exploit:** the host reads a bot's dealt hand, tampers with the bot's bid/play before dispatch, or uses perfect-information bot moves to signal/collude against the human opponent. For passthrough games (C6) the server can't even check legality.

**Fix:** Move bot logic server-side (compute bot moves privately), **or** disable bots in online multiplayer (bots only in local/offline), **or** run bots deterministically on all clients with result voting.

---

### H6 — No rate limiting on critical edge functions
**Where:** `validate-move`, `create-room`, `matchmaking`, `join-room`, `start-game` (none have per-request limits); friend requests have none either

Only business-logic caps exist (tournament count). No per-user request throttling anywhere.

**Exploit:** 1000 `validate-move`/sec → DB write amplification, other players' moves queue behind the spam, service degrades. Loop friend requests / room joins / matchmaking. Design doc calls for "friend requests 20/day" — not implemented.

**Fix:** Per-user, per-function rate limits (e.g. moves ≤2/sec, create-room ≤10/min, matchmaking ≤5/min, friend requests ≤20/day). Enforce in edge functions or via an RLS count sub-query.

---

### H7 — Self-hosted CI runner is the developer's personal Mac, running PR-branch code beside local secrets
**Where:** `.github/workflows/ui-tests-mac.yml:30,82-102`

The UI-test job runs repo scripts + `pod install --repo-update` from the PR head on a personal machine that holds the local Supabase stack (service-role key), pub cache, and Apple signing material. It is correctly fork-gated (good), but any same-repo branch or a compromised maintainer token yields arbitrary code execution on the dev's laptop plus local backend access.

**Fix:** Move UI tests to an ephemeral/dedicated CI host. Never run a backend with real/service keys on the same host as untrusted-branch CI. Treat the local service key as compromised-if-exposed.

---

### H8 — Session/refresh token stored in plaintext + Android backup enabled
**Where:** `apps/flutter_app/lib/main.dart:44-47` (no `authOptions`); `AndroidManifest.xml` (no `allowBackup=false`)

supabase_flutter 2.x defaults to `SharedPreferencesLocalStorage` (plaintext XML on Android, plist on iOS); `flutter_secure_storage` isn't a dependency. `android:allowBackup` defaults to true, so the long-lived refresh token is eligible for Auto Backup / device transfer.

**Exploit:** malware on a rooted device, an ADB-extractable backup, or a restored backup onto an attacker device → refresh token → full account takeover.

**Fix:** Configure `FlutterAuthClientOptions(localStorage: ...)` backed by `flutter_secure_storage` (Keychain / EncryptedSharedPreferences); set `android:allowBackup="false"` with data-extraction rules excluding prefs.

---

### H9 — Social RLS: chat / reactions / mute-votes not gated to room membership; friends/DMs not gated to registered
**Where:** `initial_schema.sql:700-714` (chat, reactions, mute votes), `:727-729` (friendships), `20260613000000_direct_messages.sql:69-85` (DMs)

Chat/reaction/mute-vote INSERT policies only check `auth.uid() = user_id`, **not** room membership (SELECT correctly does). Friendships and DMs don't enforce `account_type='registered'` as the design requires.

**Exploit:** enumerate room ids (all readable) and INSERT chat spam / hostile reactions into rooms you never joined. Cast mute votes against players in rooms you're not in — if 2+ real players also vote, the auto-mute trigger fires and silences them, with your ghost id written as `moderator_id`. Guests bypass the registered-only social gate.

**Fix:** Add `exists (select 1 from room_players rp where rp.room_id = ... and rp.user_id = auth.uid())` to each social INSERT policy. Add an `account_type='registered'` check to friendship/DM INSERT.

---

## 4. Medium findings

- **M1 — `game_rooms` UPDATE/DELETE lack `WITH CHECK`.** `initial_schema.sql:671-672`. Host can change `created_by`, `status`, `config` (incl. `bots`), `max_players`, `social_mode`, `password_hash`. Add `WITH CHECK` and restrict host-updatable columns.
- **M2 — `friendships` UPDATE lacks `WITH CHECK`.** `initial_schema.sql:729`. A party can reassign `user_id`/`friend_id` or forge `status` transitions (which fire push triggers). Add `WITH CHECK` and an allowed-transition guard.
- **M3 — `password_hash` is world-readable and unsalted SHA-256.** `game_rooms_select_all ... using (true)` (`:669`) returns every column incl. `password_hash`; hashing is single unsalted SHA-256 (`create-room/index.ts:687-694`). Anyone can read all private-room hashes and brute-force offline. Use a salted KDF (bcrypt/scrypt/argon2), verify inside the edge function, and never expose the hash column.
- **M4 — `record_game_completion` is a SECURITY DEFINER RPC callable by anyone with unvalidated input.** `20260308000000_add_favorites_and_recent.sql:59-100`. Reads `user_id` straight from client-supplied `p_results` → forge match history / stats for any user (and inject `opponent_names` strings = stored-XSS surface if rendered raw). `REVOKE EXECUTE ... FROM public, anon, authenticated;` and pin `search_path`.
- **M5 — admin console gates on "has a session", not "is an admin".** `apps/admin_web/lib/router.dart:16-22` checks only `session != null`; `isAdminProvider` is never consulted, and `_signIn`'s non-admin sign-out is skipped if `amIAdmin()` throws. Any game-account holder can land in `/tournaments`/`/economy` and read whatever RLS allows (e.g. `economy_config` rake tuning). Writes are still blocked server-side. Make the router require `isAdminProvider==true`; sign out on any `amIAdmin` failure; verify `economy_config` is admin-read-only; consider putting hosting behind IAP.
- **M6 — Router never re-evaluates auth on state change.** `app_router.dart:45-63` uses `ref.read(isLoggedInProvider)` with no `refreshListenable`; `isLoggedIn` is a manually-set `StateProvider`. After sign-out/expiry the user stays on protected screens. Derive from `onAuthStateChange` and wire as `refreshListenable` (admin_web already does this correctly).
- **M7 — Release builds default to the development environment.** `main.dart:33-37` defaults `ENV=development` → `http://192.168.1.17:54321` over cleartext. A release built without `--dart-define=ENV=staging` ships pointing at a LAN IP over HTTP (already bitten operationally). Fail closed: throw in `kReleaseMode` if `ENV` resolves to `development`, or default to `staging`.
- **M8 — iOS ATS cleartext exception ships in release.** `ios/Runner/Info.plist:33-47` — `NSAllowsLocalNetworking` + insecure-HTTP carve-out for `192.168.1.17` in the one shared plist. Combined with M7, a misbuilt release talks cleartext. Move the exception to a Debug-only xcconfig/plist variant.
- **M9 — OAuth redirect scheme unregistered (and spoofable when added).** `auth_service.dart:82-94` uses `io.supabase.gameplatform://` but neither `Info.plist` nor `AndroidManifest.xml` registers it — Google/Apple sign-in can't round-trip today; when added, prefer verified App Links / Associated Domains over a claimable custom scheme (keep PKCE).
- **M10 — Rewarded ads have no server-side verification (SSV).** `packages/monetization/lib/src/services/ad_service.dart:74-95`; cooldown/limits are client-side. Implement AdMob SSV: Google calls a signed endpoint that verifies the signature and is the only path that credits coins.
- **M11 — Guest / multi-account farming.** `config.toml:39` + welcome gems (`account-upgrade/index.ts:44-61`) + referral rewards. Unlimited free accounts each eligible for one-time grants; tournament entry→prize is a real inter-account currency-transfer (laundering) channel. `record-referral` guards are otherwise strong. Add device attestation / creation rate-limits; monitor referral clusters; block entry-fee tournaments between same-device accounts.
- **M12 — `check_mute_threshold` trigger is SECURITY INVOKER but inserts into RLS-locked `moderation_log`.** `initial_schema.sql:292-318`. Under normal RLS this errors the whole mute-vote insert (functional break); if made DEFINER carelessly, `moderator_id` comes from client-controlled `voter_id`. Decide the model explicitly and make the trigger a privileged DEFINER with spoof-proof fields.
- **M13 — voice-token doesn't check mute state.** `supabase/functions/voice-token/index.ts:25-52` checks membership + social mode but not `moderation_log`, so a vote-muted player still gets a `canPublish` LiveKit token. Add a mute check and drop publish rights when muted.
- **M14 — Floating dependency versions.** `pubspec.yaml` caret ranges (`purchases_flutter: ^8.0.0`, `google_mobile_ads: ^5.0.0`, `shorebird_code_push: ^1.1.0`, …); edge functions import `@supabase/supabase-js@2` (floating). Ensure `pubspec.lock` is committed and CI uses `--frozen`; pin edge-function imports to exact versions + a Deno lockfile.

---

## 5. Low / informational

- **L1 — Friend-code discovery not implemented.** Design (`prompts/26-social-features-design.md:82-89`) requires `profiles.friend_code`; no migration creates it. Blocks the M1 discovery flow. Add the column + Crockford-base32 backfill.
- **L2 — No friend-request rate limit** (design says 20/day). Covered under H6.
- **L3 — DM length limit inconsistency** — DMs allow 1000 chars vs 500 for room chat (`20260613000000_direct_messages.sql:31`). Standardize.
- **L4 — `global_lobby` presence broadcasts user ids + room ids to all users.** `apps/flutter_app/lib/features/social/data/supabase_presence_repository.dart:12-17`. Design implies friend-scoped presence; low risk (room codes are 2.1B-space random) but clarify scope with product.
- **L5 — `record-referral` self-referral/cap guards live only in the edge function.** Direct `referrals` INSERT bypasses caps but can't credit currency (service-role only). Revoke client INSERT to force the function path.
- **L6 — `is_official` / `min_subscription_tier` self-settable on player tournaments.** `add_tournaments.sql:203-205`. Force `is_official=false` for non-admin inserts.
- **L7 — CORS `Access-Control-Allow-Origin: *`** (`_shared/cors.ts:2`). Acceptable for bearer-token APIs; tighten webhook/admin functions.
- **L8 — Shorebird OTA ungoverned.** `shorebird.yaml` has placeholder app ids; code-push is a remote-code channel. Document/enforce account MFA, least-privilege collaborators, and CI-gated `shorebird patch`.
- **L9 — Storage buckets have no in-repo policies.** `config.toml:27-29` enables storage; avatar uploads imply a bucket exists. Verify RLS on any dashboard-created buckets.
- **L10 — Logging / debug hygiene.** Raw exceptions shown to users (`login_screen.dart:83-93`, `app_router.dart:363`); `print()` in release (`room_screen.dart:393`, `game_provider.dart:48`); `debugLogDiagnostics: true` unconditionally logs route/room/DM ids. Map to generic messages, use `debugPrint`/`kDebugMode`.
- **L11 — FCM `route` payload navigated without an allow-list.** `notification_service.dart:219-227` → `router.go`. Low today (only your dispatcher sends), but whitelist route prefixes before navigating.
- **L12 — `.firebase/` and `apps/admin_web/build/` not gitignored.** No secrets today, but deploy caches/build output shouldn't be committed. Add to `.gitignore`.
- **L13 — Client passes `senderId` when inserting chat.** `supabase_service.dart:438-448` — drop the parameter and use `auth.currentUser.id`; ensure RLS enforces `user_id = auth.uid()` (see H9).
- **L14 — Staging `google-services.json` used for all envs; placeholder Sentry DSN passes the non-empty check.** `env_config.dart`. Use per-env config; set placeholders to `''`.
- **L15 — Admin session persists in browser localStorage** (Flutter Web default). Any XSS on the hosted origin exfiltrates the admin JWT. Short admin session lifetimes + origin-restricted CORS on admin functions.

---

## 6. What is done well (existing protections to preserve)

- **RLS is enabled on every table** — no table left unprotected.
- **Game-end rewards are server-authoritative and idempotent** — `_shared/rewards.ts` computes outcomes server-side, grants exactly once per room (`game_reward_grants` PK + `uq_currency_game_reward`), enforces a daily coin cap, never grants gems at game end.
- **`validate-move` is properly authoritative for the validated games** — mover checked against `auth.uid()` (or a registered bot), turn order enforced, optimistic-locking (`updated_at` CAS) prevents races, and clients have **no** INSERT/UPDATE policy on `game_states`.
- **Tournament *money* core is careful** — server-side entry debit with compensating rollback, authoritative `tournament_entry_ledger`, prize pool clamped to net (post-rake) pool, per-place payout dedupe, idempotent flip-then-credit refunds. (The gap is client-writable *standings* — C2/C4 — not the money math.)
- **Admin edge functions are correctly gated** via `requireAdmin` against an allow-list table with service-role-only writes.
- **DM RLS is well designed** — friend-gated, block-aware in both directions, recipient-only read-state, sender-only delete.
- **Welcome gems + referral rewards have real anti-abuse** — unique indexes + self/dup/monthly-cap/guest guards.
- **No service-role key in any client**; all privileged writes route through edge functions; minimal on-device footprint (no local DB, no WebViews, minimal Android permissions, `taskAffinity=""`).
- **Push token lifecycle is correct** — owner-scoped table, registered only when signed in, deleted before sign-out, dead-token pruning, quiet-hours/preference filtering.
- **Room codes use `crypto.getRandomValues`** (36⁶ ≈ 2.1B space, non-enumerable); chat/DM rendered as plain `Text()` (no XSS surface).
- **CI credential hygiene is mostly strong** — Android uses Workload Identity Federation (no long-lived JSON key), no `pull_request_target`, fork-gated self-hosted job, pinned Deno `std`/`jose`.

---

## 7. Security features this app still needs

Beyond fixing the findings above, these capabilities are missing and should be planned:

1. **Server-authoritative economy** — a `wallets` table + ledger as the *only* balance path; no client writes to currency/tier/progress anywhere. (Closes C1, C2, C3, C4, H3, H4.)
2. **Server-authoritative game engines for all games** — TS validators + state re-computation for chess/hearts/spades/sequence/rummy, and server-side (or eliminated) bots. (Closes C6, H5.)
3. **Per-user rate limiting** across edge functions, room creation, matchmaking, messaging, friend requests. (Closes H6.)
4. **Fail-closed webhook verification** with signature checks + event-id idempotency for RevenueCat and notify-dispatch. (Closes H1, H2.)
5. **Secure client session storage** (Keychain / EncryptedSharedPreferences) + `allowBackup=false`. (Closes H8.)
6. **Fail-closed environment selection** + Debug-only ATS/cleartext exceptions. (Closes M7, M8.)
7. **Real admin authorization** on the admin console (admin-status routing gate) and origin-restricted admin CORS. (Closes M5.)
8. **Anti-fraud / anti-multi-accounting** — device attestation, account-creation limits, referral-cluster monitoring, restrictions on same-device tournament play. (Closes M11.)
9. **Abuse & moderation tooling** — working democratic mute (fix the trigger + voice-token mute check), block/report/mute end-to-end, and rate-limited social actions. (Closes H9, M12, M13.)
10. **Column-level RLS discipline as a standing rule** — every future `for update` policy needs `WITH CHECK` and explicit column grants; economy/rank/progress tables are service-role-write-only by default.

---

*Generated by a four-agent parallel code audit on 2026-07-07. All findings cite verified source locations; re-verify line numbers against the working tree before implementing fixes, as the social-features branch is under active development.*
