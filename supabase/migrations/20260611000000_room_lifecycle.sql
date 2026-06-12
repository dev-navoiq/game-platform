-- =============================================================================
-- Migration: Room lifecycle — host transfer + slot persistence completion
-- Date: 2026-06-11
--
-- Background
-- ----------
-- The 2026-06-09 migration introduced room_players.disconnected_at and
-- original_user_id, giving us the primitive for slot-persistence
-- (human forfeits → row stays, disconnected_at set, bot inherits user_id).
-- This migration completes the lifecycle story by:
--
--   1. Adding current_host_id to game_rooms so host can transfer when the
--      original host forfeits but humans remain.
--   2. Tightening add_bot_to_room to refuse appending bots while a game is
--      in progress (root cause of the "forfeit → re-add bots → stuck" loop).
--
-- Both changes are idempotent so re-running on a partially-applied DB is safe.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1 — current_host_id on game_rooms
-- ─────────────────────────────────────────────────────────────────────────────
-- created_by stays as the immutable audit record of who first opened the room.
-- current_host_id holds the live host, which may change if the original host
-- forfeits mid-game. Falls back to created_by until any RPC sets it.

alter table game_rooms
  add column if not exists current_host_id uuid references profiles(id);

update game_rooms
   set current_host_id = created_by
 where current_host_id is null;

create index if not exists idx_game_rooms_current_host
  on game_rooms(current_host_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2 — add_bot_to_room status guard
-- ─────────────────────────────────────────────────────────────────────────────
-- Before this migration, the RPC blindly appended a bot to config.bots and
-- incremented current_players regardless of room.status. Combined with the
-- client-only "Forfeit" navigation (which leaves room.status='playing'
-- forever), every "add bot then start game" cycle after a forfeit doubled
-- the bot list and bumped current_players, eventually hitting
-- max_players=full or pulling stale bots into the next game.
--
-- The fix is small: only allow adding bots while the room is 'waiting'.
-- Also switches the host check from created_by → current_host_id so it
-- continues to work after a host transfer.

create or replace function add_bot_to_room(
  p_room_id uuid,
  p_difficulty text default 'medium'
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_bot_id    uuid := gen_random_uuid();
  v_max       int;
  v_current   int;
  v_status    room_status;
  v_bots      jsonb;
  v_next_seat int;
begin
  select max_players,
         current_players,
         status,
         coalesce(config->'bots', '[]'::jsonb)
    into v_max, v_current, v_status, v_bots
    from game_rooms
   where id = p_room_id
     and coalesce(current_host_id, created_by) = auth.uid();

  if not found then
    raise exception 'Room not found or you are not the host';
  end if;

  if v_status <> 'waiting' then
    raise exception 'Cannot add bots to a started game (status=%)', v_status;
  end if;

  if v_current >= v_max then
    raise exception 'Room is full';
  end if;

  v_next_seat := v_current;

  v_bots := v_bots || jsonb_build_object(
    'id', v_bot_id,
    'difficulty', p_difficulty,
    'seat_index', v_next_seat
  );

  update game_rooms
     set config = jsonb_set(coalesce(config, '{}'::jsonb), '{bots}', v_bots),
         current_players = current_players + 1
   where id = p_room_id;

  return v_bot_id;
end;
$$;

-- Update the companion remove_bot_from_room to use current_host_id too,
-- otherwise a host who took over via transfer can't manage bots.
create or replace function remove_bot_from_room(
  p_room_id uuid,
  p_bot_id  uuid
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_bots     jsonb;
  v_new_bots jsonb := '[]'::jsonb;
  v_bot      jsonb;
  v_found    boolean := false;
begin
  select coalesce(config->'bots', '[]'::jsonb)
    into v_bots
    from game_rooms
   where id = p_room_id
     and coalesce(current_host_id, created_by) = auth.uid();

  if not found then
    raise exception 'Room not found or you are not the host';
  end if;

  for v_bot in select * from jsonb_array_elements(v_bots)
  loop
    if (v_bot->>'id')::uuid = p_bot_id then
      v_found := true;
    else
      v_new_bots := v_new_bots || v_bot;
    end if;
  end loop;

  if not v_found then
    raise exception 'Bot not found in room';
  end if;

  update game_rooms
     set config = jsonb_set(coalesce(config, '{}'::jsonb), '{bots}', v_new_bots),
         current_players = greatest(current_players - 1, 0)
   where id = p_room_id;
end;
$$;
