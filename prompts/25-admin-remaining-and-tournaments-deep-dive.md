# 25 — Admin console: remaining work + tournaments deep-dive

> Handoff doc for a later session. Phase A of the admin console shipped
> 2026-07-05/06 (see [24-admin-web-app-brief.md](24-admin-web-app-brief.md));
> this captures what's left, plus a deeper analysis of the tournament system's
> gaps found while building it. Facts below were verified against the code on
> 2026-07-06, commit range `85f5455..801518f`.

---

## Part 1 — Admin console: what's left

### Current state (done, don't rebuild)
- **Live**: https://game-platform-staging.web.app (Firebase Hosting, project
  `game-platform-staging`; config in `apps/admin_web/firebase.json`).
  Login `admin@gathr.app` (password held by Ambar; rotate via Supabase dashboard).
- **Backend**: `admin_users` allow-list + `requireAdmin` gate
  (`_shared/admin.ts`), 4 edge fns: `admin-create-tournament`,
  `admin-update-economy-config`, `admin-cancel-tournament`,
  `admin-force-start-tournament`. All deployed to staging.
- **UI**: login → tournaments list (cancel / force-start) → create-tournament
  form → economy-config editor.

### Phase B — Seasons & challenges (next build target)
Per the original brief §4:
- **Edge fns**: `admin-create-season` (name, dates, `pass_price_gems`,
  `max_level`, `metadata.rewards[]` free/premium tracks),
  `admin-set-active-season` (deactivate others — only one `is_active`),
  `admin-create-challenge` (daily/weekly, target, rewards, `expires_at`),
  `admin-list/deactivate-challenge`.
- **UI**: season builder with a per-level reward editor (the
  `metadata.rewards[] = {level, free:{coins,gems,skin_id}, premium:{...}}`
  shape from `grant-season-reward`), challenge scheduler.
- Reuse: `addSeasonXp` in `_shared/currency.ts` already reads
  `seasons.is_active`; `claim-challenge-reward` defines the challenge shapes.

### Phase C — Promotions / adverts
- New `promotions` table (type banner|interstitial|promo, placement, active,
  starts/ends_at, target JSONB) + `admin-upsert/list-promotion` fns +
  a `promotionsProvider` in the player app. Unchanged from brief §4.

### Hardening / ops backlog (small items, any order)
| Item | Note |
|---|---|
| Admin management UI | list/add/remove `admin_users` (service-role fn `admin-grant-admin`); today it's SQL-editor only |
| Tournament detail view in admin | participants, matches/bracket, entry ledger, payouts — needed for support/debugging; today the console only has the list |
| Manual match override | admin fn to force a match result / re-open (dispute resolution). `forfeitTournamentMatch` is the building block |
| CI deploy for admin_web | build+`firebase deploy` on push to main (needs `GOOGLE_APPLICATION_CREDENTIALS` secret); today deploys are manual |
| Dedicated hosting site | e.g. `gathr-admin.web.app` via `firebase hosting:sites:create` — cosmetic |
| admin_web tests | none exist; at minimum widget tests for the two forms + AdminApi error mapping |
| `anonKey` deprecation | supabase_flutter wants `publishableKey`; info-level for now |
| `FIREBASE_TOKEN` deprecation | Android CI workflow warns; migrate secret to a service-account JSON |
| Audit trail | `economy_config` edits are untracked beyond `updated_at`; consider an `admin_audit_log` (who/what/when) written by every admin fn |

---

## Part 2 — Tournaments: deep-dive

### What exists and is solid (verified in code)
`tournament-register` is defensively complete: status + capacity gates, tier
gate, guest-vs-gem gate, `active_tournament_cap`, debit-with-rollback, entry
ledger, duplicate guard (23505), and a post-insert capacity re-check that
refunds on a lost race. Payouts clamp to the raked ledger pool; per-place
upsert guard makes completion idempotent; refunds flip `refunded` first to win
update races. This layer needs no rework.

### Gaps, ranked by how much they block a real tournament product

> **Update 2026-07-19:** T1 + T2 are SHIPPED (`tournament-tick` edge fn +
> pg_cron migration `20260719000000`, live on staging; local 14/14 + staging
> cron E2E green). Also shipped: auto-start-when-full in `tournament-register`
> (opt-out `settings.auto_start_when_full=false`), and a `game_setup` fix —
> `% 4` first-player indexing made half of all 2-player 29/hearts/spades
> states start on an undefined player. New environments must seed
> `app_config` (`edge_base_url`, `edge_anon_key`) or the cron is a no-op.
> T3 onward below remain open.

**T1 — ~~No scheduler. Everything is manual.~~ SHIPPED 2026-07-19** *(was the big one)*
`registration_start/end` and `start_time` are stored but nothing acts on
them; no pg_cron, no scheduled functions (verified: zero cron config in
migrations or config.toml). Today a tournament starts only when an organizer
or admin presses force-start. Design sketch:
- A single `tournament-tick` edge fn (service role) that: opens registration
  when `registration_start` passes, closes at `registration_end`, calls the
  shared `startTournament()` at `start_time` (which already handles the
  under-min → cancel+refund path), and runs the T2 sweeper below.
- Trigger via Supabase scheduled functions (cron in `config.toml` /
  dashboard) every minute. Keep the tick idempotent — it already would be,
  since `startTournament` rejects non-`registration/starting` states.

**T2 — ~~Stalled matches: forfeits only fire on explicit leave.~~ SHIPPED 2026-07-19** (tick sweep: 10-min no-write → forfeit on-turn player, abandon room)
`forfeitTournamentMatch` is called from exactly one place: `leave-room`. A
player who simply never opens the room (or disconnects silently) stalls the
match — and `checkTournamentProgress` then never completes the tournament.
Needs a deadline policy, e.g.: match `in_progress` with no move for N minutes
(or `ready`/room-created but never joined within M minutes) → auto-forfeit the
absent player; double no-show → mark match `bye`-like and advance the better
seed. Run inside the T1 tick. Without this, any abandoned match soft-locks the
whole bracket — worst realistic failure mode in a live tournament.

**T3 — ~~Game coverage asymmetry (silent).~~ SHIPPED 2026-07-19** (allow-list in admin-create-tournament: 1v1 = twenty_nine/oh_hell/ludo; 2v2 = twenty_nine/bridge)

**T3 (original text) — Game coverage asymmetry (silent).**
`buildInitialState` (room setup) supports 6 games: twenty_nine, oh_hell,
hearts, spades, bridge, ludo. But `computeOutcomes` (match resolution)
supports only 4: twenty_nine, oh_hell, bridge, ludo. A **hearts or spades
tournament will start matches that can never resolve** (outcomes come back
empty → results never recorded). Chess/rummy/sequence fail earlier (no room
state). Fix cheaply now: an allow-list (`twenty_nine, oh_hell, bridge, ludo`)
enforced in `admin-create-tournament` + the player create path, and mirrored
in the admin form's game dropdown. Extend coverage game-by-game later.

**T4 — ~~The 1v1 assumption.~~ SHIPPED 2026-07-19** (2v2 team tournaments: tournament_teams + team_size, partner-invite or solo-pairing per tournament — bridge teams-only; per-player fees, split prizes; 4p rooms seat partners opposite. FFA groups for hearts/ludo-4p remain open.)

**T4 (original text) — The 1v1 assumption.**
The whole match model is `player1_id/player2_id`; `startTournamentMatch`
creates 2-player rooms unconditionally. Twenty-nine and ludo are naturally
4-player — tournament matches currently run them as 2-player variants.
Decide explicitly: (a) embrace 1v1-only tournaments (cheap; just document +
validate), or (b) extend to N-player matches — which is a schema change
(`match_players` join table), new bracket math (groups → advance top-k), and
room seating changes. Recommendation: (a) for now, (b) only if 4-player Ludo
tournaments become a product goal.

**T5 — Formats: enum promises more than the server delivers.**
`double_elimination` and `multi_stage` exist in the enum (and
`loser_next_match_id` is already in the schema) but bracket generation
supports single-elim / round-robin / swiss only. The admin form correctly
offers just the 3 supported. Either build double-elim next (schema is ready)
or leave hidden — no correctness risk today.

**T6 — Check-in flow, designed but dead.**
`checked_in` status + `checked_in_at` exist and nothing uses them. A check-in
window (open T-15min, auto-drop no-shows with refund before seeding) is the
standard fix for no-show-heavy free tournaments and pairs naturally with the
T1 tick. Low urgency until real players flake.

**T7 — Notifications.**
No push/realtime nudge when a round starts — a registered player has to be
staring at the app. `notification_preferences` table exists. Round-start (and
match-room-created) notifications are the minimum for multi-round formats;
swiss especially, where round N+1 starts at an unpredictable time.

**T8 — Recurring / official tournament templates.**
The actual "official tournaments" product is recurring (daily coin cup,
weekly gem cup — see the Gem Cup budgets in economy design). Once T1 exists,
add a `tournament_templates` table + tick-driven instantiation. Admin UI:
template editor instead of one-off creation.

**T9 — Anti-abuse (before real prize pools matter).**
Nothing stops multi-accounting for prizes (guest accounts are free to farm
coin tournaments). Cheap levers: min level / min account age to enter,
per-device entry limit, registered-only above a prize threshold (gems already
require registered). Defer until prizes are meaningful, but decide before
marketing any big-prize event.

**T10 — Observability.**
No lifecycle log. When a tester says "my tournament is stuck," debugging is
raw table spelunking. A `tournament_events` append-only table (created,
started, match_started, match_completed, forfeited, completed, payout) written
by the existing helpers would make the admin detail view (Part 1) trivial and
support cheap.

### Smaller notes
- Draw resolution in elimination = better seed advances (deliberate, fine).
- Seeding is level-based with random tiebreak; revisit when ranked/ELO ships.
- `tournament_chat` is wired in the app repo (with announcements flag) but has
  no moderation and no admin visibility.
- `rake_percent` snapshots at start — config changes mid-registration are
  correctly not retroactive. Good; keep.

### Suggested order for the tournaments session
1. **T1 + T2 together** — `tournament-tick` (schedule lifecycle + stall
   sweeper). This makes tournaments run themselves; biggest value per line.
2. **T3** — game allow-list validation (30 min, prevents silent breakage).
3. **T10 + admin tournament detail view** — observability + the support tool.
4. **T6/T7** — check-in + notifications when real testers hit no-show pain.
5. **T8** — recurring templates once the tick is trusted.

### Open design questions to settle at session start
- Tick cadence + host: Supabase cron every minute, or coarser?
- Stall timeouts: how long before auto-forfeit (join-timeout vs move-timeout)?
- 1v1-only: accept and document, or is 4-player Ludo a tournament goal?
- Double-elim: build or hide?
- Prize-abuse posture: what's the minimum bar before the first gem-prize event?
