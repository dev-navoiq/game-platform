-- #270 account deletion: auth.admin.deleteUser cascades auth.users → profiles,
-- but 14 historical references to profiles were NO ACTION and blocked the
-- delete ("Database error deleting user"). Shared rows (rooms, matches, chat,
-- teams, tournaments) must survive a player's deletion with the player
-- anonymized — so these become ON DELETE SET NULL, relaxing NOT NULL where
-- needed. Active-game/tournament rows never reach this point: the
-- delete-account edge fn refuses while the user is seated or registered.
-- Idempotent: a re-run finds no remaining NO ACTION constraints to rewrite.
do $$
declare r record;
begin
  for r in
    select distinct tc.table_name, kcu.column_name, tc.constraint_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on kcu.constraint_name = tc.constraint_name
     and kcu.table_schema = tc.table_schema
    join information_schema.referential_constraints rc
      on rc.constraint_name = tc.constraint_name
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name = tc.constraint_name
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema = 'public'
      and ccu.table_schema = 'public' and ccu.table_name = 'profiles'
      and rc.delete_rule = 'NO ACTION'
      and (tc.table_name, kcu.column_name) in (
        ('admin_users','granted_by'),
        ('feature_flags','created_by'),
        ('game_rooms','created_by'),
        ('game_rooms','current_host_id'),
        ('moderation_log','moderator_id'),
        ('profiles','referred_by'),
        ('room_players','original_user_id'),
        ('tournament_chat','sender_id'),
        ('tournament_matches','player1_id'),
        ('tournament_matches','player2_id'),
        ('tournament_matches','winner_id'),
        ('tournament_teams','captain_id'),
        ('tournaments','winner_id'),
        ('tournaments','organizer_id')
      )
  loop
    execute format('alter table public.%I alter column %I drop not null',
                   r.table_name, r.column_name);
    execute format('alter table public.%I drop constraint %I',
                   r.table_name, r.constraint_name);
    execute format(
      'alter table public.%I add constraint %I foreign key (%I) references public.profiles(id) on delete set null',
      r.table_name, r.constraint_name, r.column_name);
  end loop;
end $$;
