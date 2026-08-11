-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Tournament recurrence templates (#251, Epic #250 Phase 1)
--
-- Define a tournament once ("Daily 9PM Oh Hell Freeroll") and tournament-tick
-- materializes upcoming instances forever. Instances are perfectly normal
-- tournaments (registration → auto-cancel-if-underfilled → play → payout all
-- reuse existing paths); template_id records provenance.
--
-- Timezone note: templates store a fixed UTC offset in minutes
-- (tz_offset_min, default 330 = IST) rather than an IANA zone — deterministic
-- in SQL/TS, no DST edge cases, and the launch audience doesn't observe DST.
--
-- schedule_kind 'sitgo' is reserved for #252 (self-replenishing sit & go —
-- respawn-on-start rather than clock-driven); the tick's clock materializer
-- ignores it.
--
-- Idempotent: staging receives this via direct SQL before the chain lands.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

create table if not exists tournament_templates (
  id                        uuid primary key default uuid_generate_v4(),
  name                      text not null,
  description               text,
  game_type                 game_type not null,
  format                    text not null default 'single_elimination',

  -- Instance shape (mirrors tournaments' creation fields)
  min_participants          integer not null default 2,
  max_participants          integer not null default 8,
  entry_fee_coins           integer not null default 0,
  entry_fee_gems            integer not null default 0,
  prize_pool                jsonb   not null default '[]',
  settings                  jsonb   not null default '{}',
  team_size                 integer,
  allow_solo_pairing        boolean,
  rake_percent              numeric,
  room_social_mode          room_social_mode,
  min_subscription_tier     text,
  check_in_minutes          integer not null default 0,

  -- Recurrence
  schedule_kind             text not null check (schedule_kind in ('daily', 'weekly', 'sitgo')),
  start_hhmm                text check (start_hhmm ~ '^[0-2][0-9]:[0-5][0-9]$'),
  weekday                   integer check (weekday between 0 and 6), -- 0=Sunday, weekly only
  tz_offset_min             integer not null default 330,
  registration_lead_minutes integer not null default 180,

  active                    boolean not null default true,
  last_error                text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  constraint clock_kinds_need_time
    check (schedule_kind = 'sitgo' or start_hhmm is not null),
  constraint weekly_needs_weekday
    check (schedule_kind <> 'weekly' or weekday is not null)
);

alter table tournament_templates enable row level security;
-- Read-only for clients (admin console reads via admin edge fns anyway);
-- all writes go through service-role edge functions.
drop policy if exists "Templates readable" on tournament_templates;
create policy "Templates readable"
  on tournament_templates for select
  to authenticated
  using (true);

-- Instance provenance + the tick's idempotency anchor.
alter table tournaments add column if not exists template_id uuid references tournament_templates(id) on delete set null;

create unique index if not exists uq_tournament_template_instance
  on tournaments (template_id, start_time)
  where template_id is not null;

create index if not exists idx_tournaments_template on tournaments(template_id)
  where template_id is not null;
