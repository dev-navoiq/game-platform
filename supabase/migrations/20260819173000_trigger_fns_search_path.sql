-- #270 account deletion, part 2: with the FK rules fixed, GoTrue's deleteUser
-- still 500'd. Root cause: the auth.users → profiles → room_players cascade
-- fires sync_room_player_count() as supabase_auth_admin, whose search_path
-- omits public — the function's unqualified `update game_rooms` can't resolve
-- and the whole cascade aborts ("Database error deleting user").
--
-- Pin search_path on every trigger function with unqualified table refs, and
-- give the two counter-sync functions definer privileges so cascades fired by
-- restricted roles (GoTrue) can run them. All idempotent.
alter function public.sync_room_player_count()
  security definer set search_path = public;
alter function public.update_tournament_participant_count()
  set search_path = public;              -- already security definer
alter function public.check_mute_threshold()
  set search_path = public;
alter function public.assign_friend_code()
  set search_path = public;              -- already security definer
alter function public.generate_friend_code()
  set search_path = public;
