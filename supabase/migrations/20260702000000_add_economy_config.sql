-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Economy foundation (Milestone 1)
-- Config-driven game-end rewards. Adds:
--   • economy_config       — single-row, server-tunable economy knobs
--   • game_reward_grants   — exactly-once guard for per-room game-end rewards
--   • profiles.daily_earn_state — per-day coin-earn accounting (first-win, cap)
--   • unique index on currency_transactions — double-credit guard for game rewards
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

-- ── economy_config: one row (id = 1) holding all tunable economy knobs ───────
create table economy_config (
  id                     integer primary key default 1 check (id = 1),
  game_end_coins_win     integer not null default 50   check (game_end_coins_win >= 0),
  game_end_coins_loss    integer not null default 10   check (game_end_coins_loss >= 0),
  game_end_xp_win        integer not null default 100  check (game_end_xp_win >= 0),
  game_end_xp_loss       integer not null default 40   check (game_end_xp_loss >= 0),
  first_win_of_day_bonus integer not null default 100  check (first_win_of_day_bonus >= 0),
  daily_coin_earn_cap    integer not null default 1000 check (daily_coin_earn_cap >= 0),
  tier_earn_multiplier   jsonb   not null default '{"free": 1.0, "pro": 1.5, "max": 2.0}'::jsonb,
  welcome_gem_grant      integer not null default 50   check (welcome_gem_grant >= 0),
  rake_percent_default   numeric(5,2) not null default 10.00 check (rake_percent_default between 0 and 100),
  active_tournament_cap  integer not null default 5    check (active_tournament_cap >= 1),
  updated_at             timestamptz not null default now()
);

create trigger economy_config_updated_at
  before update on economy_config
  for each row execute function update_updated_at_column();

alter table economy_config enable row level security;

-- Readable by any authenticated user; writes only via service-role (bypasses RLS).
create policy "economy_config readable by authenticated"
  on economy_config for select
  to authenticated
  using (true);

-- Seed the single config row with defaults.
insert into economy_config (id) values (1);

-- ── game_reward_grants: one row per room => game-end rewards granted once ─────
create table game_reward_grants (
  room_id    uuid primary key references game_rooms(id) on delete cascade,
  granted_at timestamptz not null default now(),
  payload    jsonb
);

alter table game_reward_grants enable row level security;
-- No client policies — service-role only.

-- ── profiles.daily_earn_state: economy accounting, decoupled from presence ───
-- Shape: { "date": "YYYY-MM-DD", "coins_earned_today": int, "first_win_claimed": bool }
-- Kept separate from current_activity (which game-end nulls out for presence).
alter table profiles add column daily_earn_state jsonb;

-- ── Double-credit guard: at most one 'game_reward' txn per (user, room) ───────
create unique index uq_currency_game_reward
  on currency_transactions (user_id, reference_id)
  where reason = 'game_reward';
