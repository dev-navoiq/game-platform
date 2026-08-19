-- #274: the leaderboard screen shipped as hardcoded mock data. Real board:
--   get_leaderboard('week') — XP earned in the last 7 days (recent_games)
--   get_leaderboard('all')  — lifetime XP (profiles), lifetime games/wins
-- SECURITY DEFINER: the weekly aggregate scans every player's recent_games
-- rows, which per-user RLS would otherwise hide. Read-only, capped by p_limit.
create or replace function public.get_leaderboard(
  p_period text default 'week',
  p_limit  int  default 50
)
returns table (
  rank       bigint,
  user_id    uuid,
  username   text,
  avatar_url text,
  level      int,
  score      bigint,
  games      bigint,
  wins       bigint
)
language sql stable security definer set search_path = public
as $$
  with weekly as (
    select rg.user_id,
           coalesce(sum(rg.xp_earned), 0)::bigint as score,
           count(*)::bigint as games,
           (count(*) filter (where rg.result = 'win'))::bigint as wins
    from recent_games rg
    where rg.played_at > now() - interval '7 days'
    group by rg.user_id
  ),
  alltime as (
    select rg.user_id,
           count(*)::bigint as games,
           (count(*) filter (where rg.result = 'win'))::bigint as wins
    from recent_games rg
    group by rg.user_id
  ),
  scored as (
    select w.user_id, w.score, w.games, w.wins
    from weekly w
    where p_period = 'week'
    union all
    select p.id, p.xp::bigint, coalesce(a.games, 0), coalesce(a.wins, 0)
    from profiles p
    left join alltime a on a.user_id = p.id
    where p_period = 'all'
  )
  select ranked.* from (
    select row_number() over (order by s.score desc, s.wins desc, s.user_id)
             as rank,
           s.user_id, p.username, p.avatar_url, p.level,
           s.score, s.games, s.wins
    from scored s
    join profiles p on p.id = s.user_id
    where s.score > 0
  ) ranked
  where ranked.rank <= p_limit
$$;

grant execute on function public.get_leaderboard(text, int)
  to authenticated, anon;
