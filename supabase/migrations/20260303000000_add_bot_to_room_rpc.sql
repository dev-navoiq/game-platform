-- RPC function to add a bot player to a room.
-- Stores bots in game_rooms.config->bots (jsonb array) to avoid FK issues
-- with room_players → profiles → auth.users chain.
-- Also increments current_players on the room.
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
  v_bot_id   uuid := gen_random_uuid();
  v_max      int;
  v_current  int;
  v_bots     jsonb;
  v_next_seat int;
begin
  -- Verify the caller is the room host
  select max_players, current_players, coalesce(config->'bots', '[]'::jsonb)
    into v_max, v_current, v_bots
    from game_rooms
   where id = p_room_id
     and created_by = auth.uid();

  if not found then
    raise exception 'Room not found or you are not the host';
  end if;

  if v_current >= v_max then
    raise exception 'Room is full';
  end if;

  -- Next seat = number of human players + existing bots
  v_next_seat := v_current;

  -- Append bot to config.bots array
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

-- RPC function to remove a bot from a room.
create or replace function remove_bot_from_room(
  p_room_id uuid,
  p_bot_id uuid
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
  -- Verify caller is host
  select coalesce(config->'bots', '[]'::jsonb)
    into v_bots
    from game_rooms
   where id = p_room_id
     and created_by = auth.uid();

  if not found then
    raise exception 'Room not found or you are not the host';
  end if;

  -- Filter out the bot
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
