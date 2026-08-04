-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Reward receipt on recent_games (#54)
--
-- grantGameEndRewards computes each player's actual coin/XP grant (base +
-- first-win bonus, tier multiplier, daily cap) but never persisted the
-- amounts, so game screens had nothing to fetch and showed hardcoded values.
-- Store the receipt on the per-player recent_games row (already RLS'd to
-- owner-only select) and teach record_game_completion to write it.
--
-- Idempotent on purpose: staging may receive this via direct SQL before the
-- migration lands in schema_migrations.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

alter table recent_games add column if not exists coins_earned    integer not null default 0;
alter table recent_games add column if not exists xp_earned       integer not null default 0;
alter table recent_games add column if not exists gems_earned     integer not null default 0;
alter table recent_games add column if not exists first_win_bonus boolean not null default false;
alter table recent_games add column if not exists daily_cap_hit   boolean not null default false;

-- Fast lookup for the game-over dialog: "my receipt for this room".
create index if not exists idx_recent_games_room on recent_games(room_id, user_id);

-- Same signature as before — extra keys are read from each p_results element
-- with coalesce defaults, so old callers (and replays of old payloads) still
-- work unchanged.
create or replace function record_game_completion(
  p_room_id   uuid,
  p_game_type game_type,
  p_results   jsonb  -- [{user_id, result, position, points, elo_change,
                     --   coins_earned?, xp_earned?, gems_earned?,
                     --   first_win_bonus?, daily_cap_hit?}]
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
      opponent_names,
      coins_earned,
      xp_earned,
      gems_earned,
      first_win_bonus,
      daily_cap_hit
    ) values (
      (result_row->>'user_id')::uuid,
      p_game_type,
      p_room_id,
      result_row->>'result',
      (result_row->>'position')::int,
      (result_row->>'points')::int,
      (result_row->>'elo_change')::int,
      player_names,
      coalesce((result_row->>'coins_earned')::int, 0),
      coalesce((result_row->>'xp_earned')::int, 0),
      coalesce((result_row->>'gems_earned')::int, 0),
      coalesce((result_row->>'first_win_bonus')::boolean, false),
      coalesce((result_row->>'daily_cap_hit')::boolean, false)
    );
  end loop;
end;
$$ language plpgsql security definer;
