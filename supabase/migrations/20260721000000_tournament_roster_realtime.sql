-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime for tournament rosters: registrations and withdrawals happen via
-- edge functions (tournament-register / tournament-unregister), so other
-- viewers of the tournament screen only learn about them through postgres
-- changes — but none of these tables were in the publication. The acting
-- user's screen self-invalidates, which masked the gap.
-- tournament_matches is included because watchBracket() already streams it
-- and silently never received an event.
-- Guarded like 20260613 direct_messages: no-op if already published.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  t text;
begin
  foreach t in array array[
    'tournament_participants',
    'tournament_teams',
    'tournament_matches'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname   = 'supabase_realtime'
         and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;

-- DELETE events only carry the replica-identity columns of the old row.
-- Clients filter on tournament_id, so withdrawals (row deletes) are never
-- delivered unless the old row includes it — hence FULL.
alter table tournament_participants replica identity full;
alter table tournament_teams        replica identity full;
alter table tournament_matches      replica identity full;
