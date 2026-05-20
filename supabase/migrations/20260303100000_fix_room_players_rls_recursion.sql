-- =============================================================================
-- Fix: infinite recursion in room_players RLS policy
-- Migration: 20260303100000_fix_room_players_rls_recursion.sql
--
-- The original "room_players_select_room_members" policy queried room_players
-- itself to check membership, causing PostgreSQL error 42P17 (infinite
-- recursion). This also broke every other table whose SELECT policy used
-- EXISTS (... from room_players ...) — game_states, chat_messages,
-- quick_reactions, mute_votes, moderation_log, game_moves.
--
-- Fix: allow all authenticated users to read room_players. Room membership
-- is not sensitive — it's visible in the lobby UI.
-- =============================================================================

-- Drop the self-referencing policy
drop policy if exists "room_players_select_room_members" on room_players;

-- Replace with a non-recursive policy
create policy "room_players_select_all" on room_players
  for select to authenticated using (true);
