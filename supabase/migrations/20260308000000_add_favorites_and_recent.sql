-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Add user_favorites and recent_games tables
-- Session 16: Favorites, History & Replay
-- ─────────────────────────────────────────────────────────────────────────────

-- User favorite games
create table user_favorites (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references profiles(id) on delete cascade,
  game_type    game_type not null,
  favorited_at timestamptz not null default now(),

  unique(user_id, game_type)
);

create index idx_user_favorites_user on user_favorites(user_id);

-- Recently played (automatically tracked on game completion)
create table recent_games (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references profiles(id) on delete cascade,
  game_type        game_type not null,
  room_id          uuid references game_rooms(id) on delete set null,
  played_at        timestamptz not null default now(),
  duration_seconds integer,
  result           text,           -- 'win', 'loss', 'draw', 'abandoned'
  final_position   integer,        -- 1st, 2nd, 3rd, etc.
  points_earned    integer,
  elo_change       integer,

  -- Denormalized for quick display
  opponent_names   text[],
  game_summary     jsonb
);

create index idx_recent_games_user on recent_games(user_id, played_at desc);
create index idx_recent_games_type on recent_games(user_id, game_type);

-- RLS
alter table user_favorites enable row level security;
alter table recent_games enable row level security;

create policy "Users manage own favorites"
  on user_favorites for all
  to authenticated
  using (user_id = auth.uid());

create policy "Users see own recent games"
  on recent_games for select
  to authenticated
  using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- Function: record_game_completion
-- Called by edge functions when a game finishes.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function record_game_completion(
  p_room_id   uuid,
  p_game_type game_type,
  p_results   jsonb  -- Array of {user_id, result, position, points, elo_change}
)
returns void as $$
declare
  result_row  jsonb;
  player_names text[];
begin
  -- Collect all player display names for the room
  select array_agg(p.username)
  into player_names
  from room_players rp
  join profiles p on rp.user_id = p.id
  where rp.room_id = p_room_id;

  -- Insert a recent_games record for each participant
  for result_row in select * from jsonb_array_elements(p_results)
  loop
    insert into recent_games (
      user_id,
      game_type,
      room_id,
      result,
      final_position,
      points_earned,
      elo_change,
      opponent_names
    ) values (
      (result_row->>'user_id')::uuid,
      p_game_type,
      p_room_id,
      result_row->>'result',
      (result_row->>'position')::int,
      (result_row->>'points')::int,
      (result_row->>'elo_change')::int,
      player_names
    );
  end loop;
end;
$$ language plpgsql security definer;
