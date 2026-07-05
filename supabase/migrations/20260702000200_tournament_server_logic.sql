-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Tournament server logic (Milestone 3)
-- Moves the tournament money + bracket path server-side. Adds:
--   • tournament_entry_ledger — authoritative per-user entry record (pool source
--     of truth + refund idempotency)
--   • tournament_payouts       — per-place payout dedupe guard
--   • tournaments.check_in_deadline, tournaments.rake_percent (snapshot at start)
-- Relies on economy_config + profiles.account_type from earlier migrations.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

-- ── Authoritative money record: who actually paid, and whether refunded ─────
create table tournament_entry_ledger (
  id            uuid primary key default uuid_generate_v4(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  user_id       uuid not null references profiles(id) on delete cascade,
  coins_paid    integer not null default 0 check (coins_paid >= 0),
  gems_paid     integer not null default 0 check (gems_paid >= 0),
  refunded      boolean not null default false,
  paid_out      boolean not null default false,
  created_at    timestamptz not null default now(),

  unique (tournament_id, user_id)
);

create index idx_tournament_entry_ledger_tournament on tournament_entry_ledger(tournament_id);

-- ── Per-place payout dedupe guard (idempotent completion) ────────────────────
create table tournament_payouts (
  id            uuid primary key default uuid_generate_v4(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  user_id       uuid not null references profiles(id) on delete cascade,
  place         integer not null,
  coins         integer not null default 0,
  gems          integer not null default 0,
  gem_cup_bonus integer not null default 0,
  created_at    timestamptz not null default now(),

  unique (tournament_id, place)
);

create index idx_tournament_payouts_tournament on tournament_payouts(tournament_id);

-- ── Tournament columns: check-in window + frozen rake snapshot ───────────────
alter table tournaments
  add column check_in_deadline timestamptz,
  add column rake_percent numeric(5,2) not null default 0 check (rake_percent between 0 and 100);

-- ── RLS: public read (transparency), writes only via service-role ───────────
alter table tournament_entry_ledger enable row level security;
alter table tournament_payouts enable row level security;

create policy "entry ledger publicly readable"
  on tournament_entry_ledger for select using (true);

create policy "payouts publicly readable"
  on tournament_payouts for select using (true);
