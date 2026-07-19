-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Team tournaments (2v2) — prompts/25 §T4
-- Partner games (twenty_nine, bridge) get real team brackets:
--   • tournaments.team_size            — 1 (individual, default) or 2 (pairs)
--   • tournaments.allow_solo_pairing   — solos accepted and paired at start
--   • tournament_teams                 — a registered pair (captain + partner)
--   • tournament_participants.team_id  — membership link
--   • tournament_matches.team1/2_id    — bracket sides for team matches
--                                        (player1/2_id keep holding captains,
--                                        so seeds/forfeit paths stay uniform)
-- Economy: fees are PER PLAYER (each member pays own entry); prizes split
-- equally between members (remainder to captain).
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

alter table tournaments
  add column team_size integer not null default 1 check (team_size in (1, 2)),
  add column allow_solo_pairing boolean not null default false;

create table tournament_teams (
  id            uuid primary key default uuid_generate_v4(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  captain_id    uuid not null references profiles(id),
  name          text,
  created_at    timestamptz not null default now(),
  unique (tournament_id, captain_id)
);

alter table tournament_participants
  add column team_id uuid references tournament_teams(id) on delete set null;

alter table tournament_matches
  add column team1_id uuid references tournament_teams(id),
  add column team2_id uuid references tournament_teams(id);

create index idx_tournament_teams_tournament on tournament_teams(tournament_id);
create index idx_tournament_participants_team on tournament_participants(team_id);

-- ── RLS: teams are public-readable (roster display); writes are server-side
--    only (tournament-register / start seeding run via service role). ─────────
alter table tournament_teams enable row level security;

create policy "Teams visible to all"
  on tournament_teams for select
  using (true);
