# Gathr — Security Guidelines & Invariants

**Status:** Living document. Read before building any feature that touches money, identity, game state, social, or auth.
**Companion:** [SECURITY-AUDIT.md](SECURITY-AUDIT.md) is the point-in-time audit; this doc is the durable ruleset that prevents those findings from recurring.

The whole point of this file: the 2026-07-07 audit found ~30 issues, and **almost all of them trace to a handful of violated invariants.** If every PR upholds the invariants below, new features can't reopen the same holes. When you add a table, an edge function, or a client write, walk the relevant checklist.

---

## 0. The one rule that would have prevented most findings

> **The client is an untrusted display layer. Every value that affects money, rank, identity, entitlement, or hidden game information is written and validated by server code (edge functions / SECURITY DEFINER RPCs running as `service_role`), never by a client-role `UPDATE`/`INSERT`.**

RLS that only checks *row ownership* (`auth.uid() = id`) is **not** sufficient — it lets the owner write *any column* of their own row, including `coins`, `gems`, `subscription_tier`, `wins`, `level`. Ownership gates *which row*; you also need to gate *which columns* and *what values*.

Corollary: **assume the attacker has the app's anon key and a valid JWT.** Anonymous sign-in is enabled, so a valid `authenticated` JWT is free and disposable. Anything reachable by "an authenticated user" is reachable by an anonymous throwaway at scale.

---

## 1. Database / RLS invariants

**I1 — Economy, rank, identity, and progression columns are server-write-only.**
`profiles.{coins,gems,xp,level,subscription_tier,subscription_expires_at,account_type,referred_by,referral_code}`, all of `leaderboards`, `user_challenges.progress/completed_at`, `user_season_progress.level/xp/premium_purchased_at`, `tournament_participants.{wins,losses,points,status}`, `currency_transactions` — no client `UPDATE`/`INSERT` policy touches these. Enforced by the `enforce_protected_profile_columns` trigger + revoked client write policies (see the hardening migration). Client mutates them **only** by calling an edge function.

**I2 — Every `for update` policy has a `WITH CHECK`, and it equals the `USING` clause (or is stricter).**
A `USING`-only update policy lets a row owner rewrite the ownership column itself (e.g. reassign `created_by`, `friend_id`) or flip status fields. No exceptions.

**I3 — Write policies verify *context*, not just identity.**
`chat_messages`/`quick_reactions`/`mute_votes` inserts must check the author is actually a member of `room_id` (`exists (select 1 from room_players …)`), not merely that `user_id = auth.uid()`. A "write as myself" check does not stop me writing into a room/thread I'm not in.

**I4 — Social-graph tables are registered-only at the DB layer.**
`friendships` and `direct_messages` inserts require `exists (select 1 from profiles where id = auth.uid() and account_type = 'registered')`. Don't rely on the client to hide the button.

**I5 — Never expose a secret column on a world-readable row.**
`game_rooms.password_hash` must not be SELECT-able by `authenticated` (column-level `REVOKE SELECT`). Secrets are verified inside edge functions. Room/party passwords use a salted KDF (pgcrypto `crypt()`/bcrypt), never bare SHA-256.

**I6 — Hidden game information lives in a per-viewer-scoped table, not a shared blob.**
Private state (card `hands`, unrevealed `trumpSuit`, hidden tiles) is stored in `player_hands` with RLS `user_id = auth.uid()`. `game_states.state_data` holds **public** state only. Realtime broadcasts of `game_states` are therefore safe; private state is fetched per-player through the reconcile edge function which redacts by caller. **Never** put another player's secret cards in a row your opponents can SELECT or subscribe to.

**I7 — SECURITY DEFINER functions are locked down.**
Every definer function: `SET search_path = public` (or explicit), derives the actor from `auth.uid()` **inside** the function (never trusts a `user_id` argument), and has `REVOKE EXECUTE … FROM public, anon, authenticated` unless it is deliberately safe to call directly. `record_game_completion` is service-role-only.

**I8 — RLS is `enable`d on every new table** in the same migration that creates it, with explicit policies. A table with RLS on and no policies = service-role-only, which is the correct default for server-owned data.

---

## 2. Edge function invariants

**E1 — Authenticate every function.** Use `requireAuth` (validates the JWT via `auth.getUser()`); admin functions add `requireAdmin` against the `admin_users` allow-list. If a function is intentionally public (a webhook), it must be listed with `verify_jwt = false` in `config.toml` **and** carry its own auth (see E2).

**E2 — Webhooks fail *closed*.** If the shared secret env var is unset, **reject** — never fall through to "no check." Never commit a usable default secret. Verify the provider's real signature (RevenueCat, FCM) where one exists, not just a static bearer compare. Deduplicate on the provider's event id so grants can't be replayed.

**E3 — Never trust a client-supplied user id or amount.** The account to credit/debit is `auth.uid()` (or, for webhooks, the verified provider mapping), not a body field. Amounts are looked up server-side (product catalog, reward table), not taken from the request.

**E4 — Money mutations are atomic and idempotent.** Debit-then-act with a compensating rollback on failure; guard grants with a unique index on `(user_id, reference_id, reason)` so ret/replay can't double-credit. Follow the existing `game_reward_grants` / `tournament_entry_ledger` patterns.

**E5 — Platform-funded payouts are clamped to a funded budget.** Player-controllable inputs (`prize_pool`, `settings.gem_cup`) can never mint currency beyond the net entry pool (coins/gems) or an admin-authorized platform budget (gem_cup). Clamp *all* payout paths, not just the obvious one.

**E6 — Tier/eligibility gates live server-side.** "Pro/Max-only" (tournament hosting), "registered-only" (gems, social, ranked), per-tier earn multipliers — all checked in the function against the DB row, never inferred from a client claim.

**E7 — Rate-limit abusable endpoints.** Move submission, room creation, matchmaking, join, messaging, friend requests, ad-reward — per-user throttles (see the `rate_limit` helper / `check_rate_limit` RPC). Business caps (e.g. active-tournament count) are not rate limits.

---

## 3. Game-integrity invariants

**G1 — The server is authoritative for every online game.** For each game type there is a server validator (`validateXMove`) that checks legality **and** an apply step (`applyXMove`) that re-computes the new state. The stored `game_states.state_data` is the server's computation, never the client's. Games without a full server engine use `passthrough`, which is acceptable **only** for local/offline or non-competitive modes — see G2.

**G2 — `passthrough` is a temporary, guarded state, not a resting place.** While a game is on passthrough it MUST still enforce the generic invariants: the move author equals `auth.uid()`, the actor inside `move.data` is the author (no resigning/claiming as another player), and move types are gated to the current phase. A passthrough game is not "secure," only "less exploitable" — track its full-engine port. See the port checklist in §7.

**G3 — Hidden information is dealt and held server-side (I6).** Clients receive only their own private state. Dice/RNG for outcomes (Ludo) are generated server-side with `crypto.getRandomValues` and are not re-rollable/replayable.

**G4 — Turn order + optimistic locking on every move.** Enforce `currentPlayerId === move.player_id` and CAS on `updated_at` (or a version column) so concurrent/replayed moves can't clobber state.

**G5 — Bots in online play are not client-authoritative.** A client that runs a bot must not gain private information or the ability to submit unchecked moves. Prefer server-side bot moves; if bots run on the host, the server still validates every bot move exactly like a human's (G1), and the host must not be able to see other players' private state to feed the bot.

---

## 4. Client invariants

**C1 — No secrets in the client.** Only `role: anon` publishable keys ship. Never a `service_role` key, RevenueCat *secret* key, or webhook secret. CI greps for these.

**C2 — Session tokens in the OS keystore.** Configure supabase_flutter with `flutter_secure_storage` (Keychain / EncryptedSharedPreferences). Set `android:allowBackup="false"` and exclude auth storage from data-extraction rules.

**C3 — Environment selection fails closed.** A release build must never default to `development`/LAN-IP/cleartext. Throw in `kReleaseMode` if `ENV` resolves to `development`. ATS/cleartext exceptions live in Debug-only config, never in the shipped plist.

**C4 — Auth guards derive from the live session and re-evaluate.** Route guards read `onAuthStateChange` via `refreshListenable`, not a hand-set boolean. Admin surfaces gate on **admin status** (`isAdminProvider == true`), not merely "has a session," and sign out on any admin-check failure. Server-side authorization is still the real line of defense — client guards are UX only.

**C5 — Treat all inbound payloads as untrusted.** Deep links / FCM `route` values are validated against a route allow-list before navigation. Never render user-supplied text (chat, display names, `opponent_names`) as HTML/markdown — plain `Text()` only.

**C6 — Don't log or leak.** No `print`/`debugPrint` of tokens, user data, or raw exceptions in release; map errors to generic user messages; gate `debugLogDiagnostics` on `kDebugMode`.

---

## 5. Infra / supply-chain invariants

**N1 — Untrusted-branch CI never runs beside real secrets.** No `pull_request_target` with checkout+run of PR code. Self-hosted runners are ephemeral/dedicated hosts, not a personal machine holding service keys or signing material. Keep the local Supabase service key off any CI-reachable host.

**N2 — Pin what executes.** Commit `pubspec.lock` and build `--frozen` in CI. Pin edge-function imports to exact versions (`@supabase/supabase-js@2.x.y`) + a Deno lockfile.

**N3 — Remote-code channels are governed like signing keys.** Shorebird OTA and any code-push: MFA on the account, least-privilege collaborators, CI-gated + reviewed patches.

**N4 — Anti-fraud is a first-class feature, not an afterthought.** Free anonymous accounts + one-time grants + inter-account currency transfer (tournaments) = a farming engine. Gate value grants behind verified identity where feasible, rate-limit account creation, and monitor referral/tournament graphs for same-device clusters.

---

## 6. PR security checklist (paste into the PR description for any risky change)

```
Security review (delete rows that don't apply):

DB / RLS
- [ ] New tables have RLS enabled + explicit policies in the same migration
- [ ] Every `for update` policy has a WITH CHECK matching/stricter than USING
- [ ] No client write policy touches money/rank/identity/progress columns (I1)
- [ ] Social/graph writes verify account_type='registered' (I4) and room/thread membership (I3)
- [ ] No secret column is SELECT-able on a world-readable row (I5)
- [ ] Private game state is in player_hands / per-viewer scope, not a shared blob (I6)
- [ ] New SECURITY DEFINER fns: search_path pinned, actor from auth.uid(), EXECUTE revoked (I7)

Edge functions
- [ ] requireAuth (+ requireAdmin where applicable); public fns are verify_jwt=false + self-authed
- [ ] Webhooks fail closed, verify provider signature, dedupe on event id (E2)
- [ ] Credited account = auth.uid()/verified mapping; amounts looked up server-side (E3)
- [ ] Money paths atomic + idempotent (unique index guard) (E4)
- [ ] Platform-funded payouts clamped to a funded budget (E5)
- [ ] Tier/eligibility gates enforced server-side (E6)
- [ ] Abusable endpoint is rate-limited (E7)

Game integrity (if touching game state)
- [ ] Move validated AND state re-computed server-side, or explicitly passthrough-guarded (G1/G2)
- [ ] Hidden info dealt/held server-side, per-viewer scoped (G3)
- [ ] Turn order + optimistic lock enforced (G4)

Client
- [ ] No service_role / secret keys added to client
- [ ] New sensitive writes go through an edge function, not a direct table write
- [ ] Inbound payloads (deep links, FCM, user text) validated / rendered as plain text (C5)
```

---

## 7. Open structural work (tracked debt from the audit)

These are known gaps that the guidelines above assume will be closed. Until each is done, treat the affected feature as **not** meeting the invariant it violates.

1. **Server-side engines for passthrough games (G1/G2).** `chess`, `hearts`, `spades`, `sequence`, `rummy` currently run on `passthrough` (generic guards only — see the hardened `passthrough.ts`). Per-game port plan:
   - Port the Dart rules (`packages/game_<name>/lib/src/<name>_rules.dart`) to `supabase/functions/_shared/game_rules/<name>.ts`, mirroring the existing `twenty_nine.ts` / `bridge.ts` pattern: a `validate<Name>Move` (legality) + `apply<Name>Move` (state re-compute).
   - Add the case to `game_rules/index.ts` dispatch.
   - Add `fromJson` for that state in the Flutter client's `deserializeGameState` so clients adopt server-authoritative state.
   - Verify against the Dart engine's test vectors so server and client agree (divergence = desync).
   - Priority order: chess (most requested) → spades/hearts (trick-taking, reuse follow-suit helpers) → sequence → rummy (currently a stub; gate it off until real).
2. **Private hands cutover (C5, I6) — `player_hands` table exists; wire it.** The RLS-scoped table is created (empty, no writers). Cutover steps, in order, with a local `supabase db reset` + a smoke test of every card game (twenty_nine, oh_hell, hearts, spades, bridge, rummy) between each:
   - **Server write:** in `game_setup.ts`, after building initial state, split `state.hands` out — write one `player_hands` row per player (service role) and replace `state_data.hands` with `handCounts: {playerId: n}` (public). `start-game` and the tournament match orchestrator both call `buildInitialState`, so do the split in one shared helper they both use.
   - **Server validate/apply:** in `validate-move`, before `validateMove`/`applyMove`, reconstitute the full `stateData.hands` by reading all `player_hands` rows for the room; after `applyMove`, write each changed hand back to `player_hands` and store only public state + `handCounts` in `game_states`.
   - **Server read:** `reconcile-state` already redacts — change it to source the caller's hand from `player_hands` (their row only) rather than from `state_data`.
   - **Client read:** the Flutter provider currently reads all hands from the `game_states` Realtime `state_data` (`game_provider.dart`). Change it to (a) subscribe to `game_states` for public state + `handCounts`, and (b) subscribe to / fetch the caller's own `player_hands` row (RLS returns only theirs), then merge its `hand` into the deserialized state before rendering. Opponents render from `handCounts` (card-backs), never real cards.
   - **Verify:** a modified client subscribing to `game_states` or `player_hands` must see only its own cards. Confirm across all six card games and for spectators.
3. **Server-side challenge progress (H3, closes "claim once free").** Challenge `progress`/`completed_at` are still client-written (`supabase_challenge_repository.updateProgress`). The idempotency index blocks infinite re-claim, but progress should advance in the server game-end flow (`rewards.ts`) like season XP already does; then lock `user_challenges` completion columns like `user_season_progress`.
4. **Server-issued season-pass entitlement.** `premium_purchased_at` is now server-managed (locked); add a `buy-season-pass` edge function that debits gems (via the spend path) and sets it, and repoint `deductGems`.
5. **Rewarded-ad server-side verification (SSV).** No AdMob SSV endpoint yet; ad rewards must not credit until one exists (see M10 in the audit).
6. **Client session storage in the OS keystore + secure OAuth redirect.** Add `flutter_secure_storage`, pass it to `Supabase.initialize(authOptions:)`, and register a verified App Link / Associated Domain for `login-callback` (the custom scheme is currently unregistered — sign-in can't round-trip). Not done here to avoid a merge conflict on the actively-edited `pubspec.yaml`. (`allowBackup=false` + data-extraction rules are already applied.)
7. **Full server-side engines for passthrough games (G1/G2)** — see item 1 above; `passthrough.ts` now enforces turn + actor + phase-move generic guards, but legality still needs the per-game port.
8. **Anti-multi-account tooling** (device attestation, creation limits, referral-cluster monitoring).
9. **Move UI tests off the personal self-hosted runner.**

---

*Owner: whoever touches these systems next. When you close an item in §7, delete it here and confirm the corresponding invariant now holds unconditionally.*
