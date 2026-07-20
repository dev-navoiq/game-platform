-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime for profiles: the home screen's "Resume Game" card streams the
-- user's own profiles.current_activity so a tournament match starting while
-- the player idles on home surfaces immediately (one-shot fetch missed it —
-- testers wandered into bot practice games instead of their live match).
-- Guarded like 20260613 direct_messages: no-op if already published.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname   = 'supabase_realtime'
       and tablename = 'profiles'
  ) then
    execute 'alter publication supabase_realtime add table profiles';
  end if;
end $$;
