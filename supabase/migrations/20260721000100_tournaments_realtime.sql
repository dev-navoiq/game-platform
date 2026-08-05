-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime for the tournaments table itself: the tournaments-screen lists
-- (upcoming / live) were one-shot fetches, so tournaments created or
-- transitioning status (registration → in_progress) while the screen was
-- open never appeared. Companion to 20260721000000 (roster tables).
--
-- No REPLICA IDENTITY FULL here on purpose: clients subscribe unfiltered
-- (deletes don't need old-row columns to match), and current_participants
-- is updated on every registration — FULL would log the whole old row to
-- WAL each time for nothing.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname   = 'supabase_realtime'
       and tablename = 'tournaments'
  ) then
    execute 'alter publication supabase_realtime add table tournaments';
  end if;
end $$;
