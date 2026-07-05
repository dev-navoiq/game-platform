# Gathr Admin (`admin_web`)

Separate Flutter **Web** operator console for the game platform. Not shipped in
the consumer mobile binary. Standalone package (no `game_core` / `monetization`
deps) so it stays web-safe and light.

Kickoff brief: [`prompts/24-admin-web-app-brief.md`](../../prompts/24-admin-web-app-brief.md).

## What it does (Phase A)

- **Tournaments** — create *official* tournaments (`is_official=true`), force-start,
  cancel (with automatic entry refund).
- **Economy config** — live-edit the single `economy_config` row (coins/XP payouts,
  first-win bonus, daily cap, tier multipliers, default rake, welcome gems,
  active-tournament cap). Takes effect immediately, no deploy.

Phase B (seasons & challenges) and Phase C (promotions) are not built yet.

## Security model

The web app is **not** the security boundary. Every privileged write goes through
an **admin-gated edge function** (`admin-create-tournament`,
`admin-cancel-tournament`, `admin-force-start-tournament`,
`admin-update-economy-config`). Each one runs `requireAuth` → `requireAdmin`
(membership in the `admin_users` table) via the service-role client. The browser
only ever holds the public anon key; reads go through RLS. Admins are added by
inserting into `admin_users` (migration seed or a service-role insert).

## Run locally (against local Supabase)

Defaults target `http://127.0.0.1:54321`, so with `supabase start` running:

```bash
cd apps/admin_web
fvm flutter run -d chrome
```

Seed a local admin (once):

```sql
-- via: docker exec supabase_db_game-platform psql -U postgres -d postgres
insert into admin_users(user_id)
select id from auth.users where email = '<your email>' on conflict do nothing;
```

A ready-made dev login is seeded during setup: **admin@gathr.local / admin1234**.

## Run against staging

```bash
fvm flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://toqtbqmhxmemixaumljz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging anon key>
```

(Requires the migration + `admin-*` edge functions deployed to staging, and your
account present in `admin_users` there.)

## Structure

```
lib/
  config.dart          env wiring (dart-define overrides)
  theme.dart           Refined Crystal theme (felt green + gold)
  providers.dart       Riverpod: auth, isAdmin, tournaments, economy config
  router.dart          GoRouter + auth-guard redirect
  services/admin_api.dart   edge-function wrapper + RLS reads
  screens/
    login_screen.dart
    shell.dart                nav rail + header
    tournaments_screen.dart   list + cancel/force-start
    create_tournament_screen.dart
    economy_config_screen.dart
```
