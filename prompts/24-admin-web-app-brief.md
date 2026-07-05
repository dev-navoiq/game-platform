# 24 — Admin Web App (handoff brief)

> Kickoff brief for building a **separate admin web app** for the game platform.
> Branched off the long build chat that shipped the tournaments + economy +
> identity backend and the player-facing UI. Start the new chat by pointing it
> at this file.

---

## 0. Context — what already exists (do not rebuild)

The backend + player UI for tournaments, the virtual economy, and identity are
**built, verified, and deployed to staging** (`toqtbqmhxmemixaumljz`). See:
- [22-tournament-economy-design.md](22-tournament-economy-design.md) — economy design (coins/gems/XP, tournaments, rake, Gem Cups).
- [23-identity-and-profiles.md](23-identity-and-profiles.md) — guest/registered/subscriber identity.
- Migrations: `20260702000000_add_economy_config`, `_00100_add_account_type`, `_00200_tournament_server_logic`, plus `20260310000000_add_tournaments`, and `20260226000000_initial_schema` (seasons, challenges, ad_impressions).
- Edge functions (deployed): `tournament-register/-unregister/-start/-complete`, `account-upgrade`, `grant-season-reward`, `claim-challenge-reward`, `record-game`-path in `validate-move`.

Key tables the admin app touches: `tournaments`, `tournament_matches`, `tournament_participants`, `tournament_entry_ledger`, `tournament_payouts`, `economy_config` (single row `id=1`), `seasons`, `user_season_progress`, `challenges`, `user_challenges`, `ad_impressions`, `feature_flags`, `profiles`.

Tournaments are currently created via RLS "organizer insert" (used in tests). There is **no admin creation flow yet** and **no admin role** — those are part of this work.

---

## 1. Goal & scope (locked decisions)

Build a **separate admin web app** (not in the consumer mobile binary). Capabilities, in priority order:
1. **Create/manage tournaments** — create *official* tournaments (`is_official=true`), cancel, force-start. This is also the **testing enabler** for the player app.
2. **Live-edit `economy_config`** — tune game-end coins, tier multipliers, rake, first-win bonus, welcome gems, Gem-Cup budgets, daily cap — no deploy.
3. **Adverts / promotions** — manage banners / promo placements / rewarded-ad config (needs new schema, see §4).
4. **Seasons & challenges** — create/schedule seasons (with `metadata.rewards`) and daily/weekly challenges.

---

## 2. Architecture recommendation

- **App**: a new Flutter Web app in the monorepo — `apps/admin_web/` (Melos package), reusing the `monetization` package + shared models. Keeps one stack; deploy as static web (Supabase hosting / Netlify / Cloudflare Pages).
- **Security boundary is server-side, not the web app.** All privileged writes go through **admin-gated edge functions** using the service-role client; the web app only calls them. Never ship service-role keys to the browser.
- **Auth**: admins log in with Supabase email/password. Gate on an admin role.

---

## 3. Security model (build first)

- Add `profiles.role text not null default 'player'` (or a dedicated `admin_users` table). Set trusted accounts to `'admin'` manually / via a seed.
- Each admin edge function: `requireAuth` → load `profiles.role` → reject if `!= 'admin'` (return 403). Mirror the existing `_shared/validation.ts` + `_shared/identity.ts` patterns.
- Optionally, RLS policies allowing `role='admin'` to select admin-only tables; but prefer routing writes through edge functions (service role bypasses RLS cleanly and centralizes authorization).

---

## 4. What to build — phased

### Phase A — Admin foundation + tournaments + economy config (highest value)
- **Schema**: `profiles.role`; migration + seed one admin.
- **Edge functions** (all admin-gated):
  - `admin-create-tournament` — insert a tournament with full control (`is_official`, `game_type`, `format`, entry fees, `prize_pool`, `settings.gem_cup`, `min_subscription_tier`, capacity, timing). Reuse the validated shapes from `20260310000000_add_tournaments.sql`.
  - `admin-cancel-tournament` — set `status='cancelled'` + call `refundAllEntries` (already in `_shared/tournament_report.ts`).
  - `admin-force-start-tournament` — thin wrapper calling the existing `tournament-start` logic (bypassing the organizer check).
  - `admin-update-economy-config` — update the single `economy_config` row (validate ranges).
- **Web UI**: admin login → dashboard → "New tournament" form; "Economy config" editor (all `economy_config` columns, with the `tier_earn_multiplier` JSON and Gem-Cup fields); tournament list with cancel/force-start.

### Phase B — Seasons & challenges
- **Edge functions**: `admin-create-season` (name, dates, `pass_price_gems`, `max_level`, `metadata.rewards[]` with free/premium tracks), `admin-set-active-season`; `admin-create-challenge` (daily/weekly, target, rewards, `expires_at`), `admin-list/deactivate-challenge`.
- **Web UI**: season builder (level-reward editor), challenge scheduler.

### Phase C — Adverts / promotions
- **Schema (new)**: a `promotions` table (id, type banner|interstitial|promo, title, image_url/asset_key, placement, active, starts_at/ends_at, target JSONB), and optionally ad-config knobs in `economy_config` or a `ad_config` row.
- **Edge functions**: `admin-upsert-promotion`, `admin-list-promotions`.
- **Player app**: a `promotionsProvider` reading active promotions (separate follow-up).

---

## 5. Relevant existing assets (reference)

| Need | Reuse |
|---|---|
| Currency credit/debit + XP | `supabase/functions/_shared/currency.ts` |
| Tournament refund / complete / start helpers | `supabase/functions/_shared/tournament_report.ts` |
| Bracket generation | `supabase/functions/_shared/bracket.ts` |
| Auth + response helpers | `supabase/functions/_shared/validation.ts` |
| Guest/registered check pattern | `supabase/functions/_shared/identity.ts` |
| Economy knobs (the thing to edit) | `economy_config` table (migration `20260702000000`) |
| Tournament table shapes | migration `20260310000000_add_tournaments.sql` |
| Season reward JSON shape | `seasons.metadata.rewards[] = {level, free:{coins,gems,skin_id}, premium:{...}}` |

Deploy workflow (same as the main app): `supabase db push` + `supabase functions deploy` to staging `toqtbqmhxmemixaumljz` (prod `obtgysfcyenbfouvfixs`, untouched). Local Supabase quirk: if `supabase start`/`db reset` hangs, it's a stalled image pull — retag a local image (see the `supabase-local-start-image-pull-hang` memory).

---

## 6. Testing approach

- **Backend**: reuse the curl + `docker exec psql` assertion-harness pattern from the main build (create admin → call each admin edge fn → assert DB rows + authorization rejection for non-admins).
- **Admin-created tournaments** immediately unblock **player-app** UI testing (register → play → payout).
- **Web UI**: `flutter test` widget tests + manual run (`flutter run -d chrome`).

---

## 7. First steps for the new chat
1. Confirm: role model (`profiles.role` vs `admin_users`), and where the admin web app deploys.
2. Migration: add `profiles.role` + seed an admin.
3. `admin-create-tournament` + `admin-update-economy-config` edge functions (+ role gate).
4. Scaffold `apps/admin_web/` (Flutter Web) with admin login + those two forms.
5. Verify with the assertion harness + a manual admin login.

Everything above is already-decided context — the new chat should start by planning Phase A.
