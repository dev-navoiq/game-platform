-- =============================================================================
-- Game Platform — Tournaments
-- Migration: 20260310000000_add_tournaments.sql
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────────────────────
create type tournament_format as enum (
  'single_elimination',
  'double_elimination',
  'round_robin',
  'swiss',
  'multi_stage'
);

create type tournament_status as enum (
  'draft',
  'registration',
  'starting',
  'in_progress',
  'completed',
  'cancelled'
);

create type bracket_side as enum ('winners', 'losers', 'finals');

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: tournaments
-- ─────────────────────────────────────────────────────────────────────────────
create table tournaments (
  id                    uuid primary key default uuid_generate_v4(),

  -- Basic info
  name                  text not null,
  description           text,
  game_type             game_type not null,
  format                tournament_format not null,

  -- Organizer
  organizer_id          uuid references profiles(id),
  is_official           boolean not null default false,

  -- Timing
  registration_start    timestamptz,
  registration_end      timestamptz,
  start_time            timestamptz not null,
  end_time              timestamptz,

  -- Capacity
  min_participants      integer not null default 4 check (min_participants >= 2),
  max_participants      integer not null default 32 check (max_participants >= min_participants),
  current_participants  integer not null default 0 check (current_participants >= 0),

  -- Entry fees (coin economy — product strategy Part 3.4)
  entry_fee_coins       integer not null default 0 check (entry_fee_coins >= 0),
  entry_fee_gems        integer not null default 0 check (entry_fee_gems >= 0),
  is_free               boolean generated always as (entry_fee_coins = 0 and entry_fee_gems = 0) stored,

  -- Prizes (JSONB array: [{place, coins, gems, skin_id, title}])
  prize_pool            jsonb not null default '[]',

  -- Game/tournament settings (time_control, rounds for swiss, etc.)
  settings              jsonb not null default '{}',

  -- Status
  status                tournament_status not null default 'draft',
  winner_id             uuid references profiles(id),
  final_standings       jsonb,

  -- Subscription requirement
  min_subscription_tier subscription_tier not null default 'free',

  -- Social mode: tournament rooms default to 'focus' (product strategy)
  room_social_mode      room_social_mode not null default 'focus',

  -- Timestamps
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger tournaments_updated_at
  before update on tournaments
  for each row execute function update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: tournament_participants
-- ─────────────────────────────────────────────────────────────────────────────
create table tournament_participants (
  id                uuid primary key default uuid_generate_v4(),
  tournament_id     uuid not null references tournaments(id) on delete cascade,
  user_id           uuid not null references profiles(id) on delete cascade,

  -- Status
  status            text not null default 'registered'
                    check (status in ('registered', 'checked_in', 'active', 'eliminated', 'winner')),
  seed              integer,
  current_round     integer not null default 0,

  -- Stats
  wins              integer not null default 0,
  losses            integer not null default 0,
  draws             integer not null default 0,
  points            integer not null default 0,
  game_wins         integer not null default 0,
  buchholz          decimal(10,2) not null default 0,

  -- Timestamps
  registered_at     timestamptz not null default now(),
  checked_in_at     timestamptz,
  eliminated_at     timestamptz,

  unique(tournament_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: tournament_matches
-- ─────────────────────────────────────────────────────────────────────────────
create table tournament_matches (
  id                    uuid primary key default uuid_generate_v4(),
  tournament_id         uuid not null references tournaments(id) on delete cascade,

  -- Match position in bracket
  round                 integer not null,
  match_number          integer not null,
  bracket_side          bracket_side not null default 'winners',

  -- Participants
  player1_id            uuid references profiles(id),
  player2_id            uuid references profiles(id),
  player1_seed          integer,
  player2_seed          integer,

  -- Result
  winner_id             uuid references profiles(id),
  player1_score         integer,
  player2_score         integer,
  result_details        jsonb,

  -- Game room link
  room_id               uuid references game_rooms(id),

  -- Status
  status                text not null default 'pending'
                        check (status in ('pending', 'ready', 'in_progress', 'completed', 'bye')),

  -- Scheduling
  scheduled_time        timestamptz,
  started_at            timestamptz,
  completed_at          timestamptz,

  -- Bracket progression
  next_match_id         uuid references tournament_matches(id),
  next_match_slot       integer check (next_match_slot in (1, 2)),

  -- Double elimination: loser goes to losers bracket
  loser_next_match_id   uuid references tournament_matches(id),

  unique(tournament_id, round, match_number, bracket_side)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: tournament_chat
-- ─────────────────────────────────────────────────────────────────────────────
create table tournament_chat (
  id                uuid primary key default uuid_generate_v4(),
  tournament_id     uuid not null references tournaments(id) on delete cascade,
  sender_id         uuid not null references profiles(id),
  content           text not null check (length(content) between 1 and 500),
  is_announcement   boolean not null default false,
  created_at        timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
create index idx_tournaments_status on tournaments(status);
create index idx_tournaments_game_type on tournaments(game_type);
create index idx_tournaments_start_time on tournaments(start_time);
create index idx_tournaments_organizer on tournaments(organizer_id);
create index idx_tournament_participants_tournament on tournament_participants(tournament_id);
create index idx_tournament_participants_user on tournament_participants(user_id);
create index idx_tournament_matches_tournament_round on tournament_matches(tournament_id, round);
create index idx_tournament_matches_status on tournament_matches(status);
create index idx_tournament_chat_tournament on tournament_chat(tournament_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW-LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────
alter table tournaments enable row level security;
alter table tournament_participants enable row level security;
alter table tournament_matches enable row level security;
alter table tournament_chat enable row level security;

-- Tournaments: visible if not draft, or if you're the organizer
create policy "Tournaments visible when not draft or owned"
  on tournaments for select
  using (status != 'draft' or organizer_id = auth.uid());

-- Tournaments: organizer can insert/update
create policy "Organizer can create tournaments"
  on tournaments for insert
  with check (organizer_id = auth.uid());

create policy "Organizer can update own tournaments"
  on tournaments for update
  using (organizer_id = auth.uid());

-- Participants: publicly visible
create policy "Participants visible to all"
  on tournament_participants for select
  using (true);

-- Participants: users can register themselves
create policy "Users can register themselves"
  on tournament_participants for insert
  with check (user_id = auth.uid());

-- Participants: users can update own (check-in)
create policy "Users can update own participation"
  on tournament_participants for update
  using (user_id = auth.uid());

-- Participants: users can withdraw (delete own)
create policy "Users can withdraw themselves"
  on tournament_participants for delete
  using (user_id = auth.uid());

-- Matches: publicly visible
create policy "Matches visible to all"
  on tournament_matches for select
  using (true);

-- Chat: visible to tournament participants
create policy "Chat visible to participants"
  on tournament_chat for select
  using (
    tournament_id in (
      select tournament_id from tournament_participants where user_id = auth.uid()
    )
  );

-- Chat: participants can send messages
create policy "Participants can send chat"
  on tournament_chat for insert
  with check (
    sender_id = auth.uid()
    and tournament_id in (
      select tournament_id from tournament_participants where user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: increment/decrement participant count
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function update_tournament_participant_count()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update tournaments
      set current_participants = current_participants + 1
      where id = new.tournament_id;
    return new;
  elsif tg_op = 'DELETE' then
    update tournaments
      set current_participants = current_participants - 1
      where id = old.tournament_id;
    return old;
  end if;
  return null;
end;
$$;

create trigger tournament_participant_count_trigger
  after insert or delete on tournament_participants
  for each row execute function update_tournament_participant_count();
