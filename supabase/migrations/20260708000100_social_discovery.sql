-- ═══════════════════════════════════════════════════════════════════════════
-- M1 — SOCIAL DISCOVERY (prompts/26 §3, refinements locked 2026-07-08)
--
-- Usernames as searchable identity are REGISTERED-ONLY: guests keep their
-- auto-generated names, never appear in search, and have no friend code.
-- Claiming happens via a one-time client sheet (tracked by username_claimed_at);
-- renames are cooldown-limited. friend_code is the stable, server-managed
-- identifier. `discoverable` opts out of username search (friend code still
-- resolves — sharing it is consent).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Profile columns ───────────────────────────────────────────────────

alter table profiles
  add column username_claimed_at timestamptz,
  add column username_changed_at timestamptz,
  add column discoverable        boolean not null default true,
  add column friend_code         text;

-- Case-insensitive uniqueness (profiles_username_key is case-sensitive only).
-- Auto-generated names carry a uuid prefix so case-collisions are vanishingly
-- rare, but suffix any stragglers before the index lands.
update profiles p
set username = p.username || '_' || substr(p.id::text, 1, 4)
where exists (
  select 1 from profiles q
  where lower(q.username) = lower(p.username) and q.id < p.id
);

create unique index profiles_username_lower_unique on profiles (lower(username));
create unique index profiles_friend_code_unique on profiles (friend_code);

-- ── 2. Friend codes (server-managed, Crockford base32, registered only) ──

create or replace function generate_friend_code()
returns text
language plpgsql
as $$
declare
  -- Crockford base32: no I/L/O/U, so codes survive handwriting and speech.
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  code text;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * 32)::int, 1);
    end loop;
    exit when not exists (select 1 from profiles where friend_code = code);
  end loop;
  return code;
end;
$$;

-- Assign on registration (insert of a registered profile, or the
-- account-upgrade edge fn flipping account_type). Column-targeted so plain
-- client profile edits never enter here.
create or replace function assign_friend_code()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.account_type = 'registered' and new.friend_code is null then
    new.friend_code := generate_friend_code();
  end if;
  return new;
end;
$$;

create trigger trg_assign_friend_code
  before insert or update of account_type on profiles
  for each row execute function assign_friend_code();

-- Backfill existing registered users.
update profiles set friend_code = generate_friend_code()
where account_type = 'registered' and friend_code is null;

-- ── 3. Username claim/rename rules (client writes, trigger-enforced) ─────

create or replace function enforce_username_rules()
returns trigger
language plpgsql
as $$
begin
  -- security invoker: current_user is the PostgREST role for client writes.
  if current_user not in ('authenticated', 'anon') then
    return new; -- service_role / migrations: trusted
  end if;

  if new.friend_code is distinct from old.friend_code then
    raise exception 'friend_code is server-managed' using errcode = '42501';
  end if;

  if new.username is distinct from old.username then
    if old.account_type <> 'registered' then
      raise exception 'Create an account to choose a username'
        using errcode = '42501';
    end if;
    if new.username !~ '^[a-z0-9][a-z0-9_]{2,19}$' then
      raise exception 'Username must be 3-20 chars: a-z, 0-9, _ (no leading _)'
        using errcode = '23514';
    end if;
    if lower(new.username) in ('admin','gathr','system','support','moderator',
                               'mod','official','staff','help','root') then
      raise exception 'That username is reserved' using errcode = '23514';
    end if;
    if old.username_claimed_at is not null
       and old.username_changed_at > now() - interval '30 days' then
      raise exception 'Username can be changed once every 30 days'
        using errcode = '42501';
    end if;
    new.username_claimed_at := coalesce(old.username_claimed_at, now());
    new.username_changed_at := now();
  else
    -- bookkeeping columns are not directly client-writable
    new.username_claimed_at := old.username_claimed_at;
    new.username_changed_at := old.username_changed_at;
  end if;

  return new;
end;
$$;

create trigger trg_enforce_username_rules
  before update on profiles
  for each row execute function enforce_username_rules();

-- ── 4. friendships: one row per PAIR, either direction ───────────────────

-- Dedupe reverse pairs before the index: keep accepted over pending,
-- then the older row.
delete from friendships f
using friendships g
where f.user_id = g.friend_id
  and f.friend_id = g.user_id
  and (
    (case when f.status = 'accepted' then 1 else 0 end)
      < (case when g.status = 'accepted' then 1 else 0 end)
    or (
      (case when f.status = 'accepted' then 1 else 0 end)
        = (case when g.status = 'accepted' then 1 else 0 end)
      and (f.created_at, f.id) > (g.created_at, g.id)
    )
  );

create unique index friendships_pair_unique
  on friendships (least(user_id, friend_id), greatest(user_id, friend_id));

-- ── 5. user_reports (pulled forward from M5 scope — decision 2026-07-08) ─

create table user_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_id   uuid not null references profiles(id) on delete cascade,
  context     text not null check (context in ('dm','room_chat','party','voice','profile','game')),
  context_id  uuid,
  reason      text not null check (reason in ('harassment','spam','cheating','inappropriate_name','other')),
  detail      text check (char_length(detail) <= 500),
  status      text not null default 'open' check (status in ('open','reviewed','actioned','dismissed')),
  created_at  timestamptz not null default now(),
  constraint report_no_self check (reporter_id <> target_id)
);

create index idx_user_reports_status on user_reports (status, created_at desc);
create index idx_user_reports_target on user_reports (target_id);

alter table user_reports enable row level security;

create policy user_reports_insert_own on user_reports
  for insert with check (auth.uid() = reporter_id);
create policy user_reports_select_own on user_reports
  for select using (auth.uid() = reporter_id);
-- Review/status changes: admin edge fns via service role only.

-- ── 6. search_profiles ────────────────────────────────────────────────────

create or replace function search_profiles(p_query text)
returns table (
  id              uuid,
  username        text,
  display_name    text,
  avatar_url      text,
  level           integer,
  is_friend       boolean,
  request_pending boolean
)
language sql
security definer
stable
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  ),
  caller as (
    select s.id from profiles s, me
    where s.id = me.uid and s.account_type = 'registered'
  ),
  norm as (
    select upper(replace(trim(p_query), '-', '')) as code,
           lower(trim(p_query)) as name_prefix
  )
  select
    p.id, p.username, p.display_name, p.avatar_url, p.level,
    exists (
      select 1 from friendships f, me
      where f.status = 'accepted'
        and ((f.user_id = me.uid and f.friend_id = p.id)
          or (f.friend_id = me.uid and f.user_id = p.id))
    ) as is_friend,
    exists (
      select 1 from friendships f, me
      where f.status = 'pending'
        and ((f.user_id = me.uid and f.friend_id = p.id)
          or (f.friend_id = me.uid and f.user_id = p.id))
    ) as request_pending
  from profiles p, me, norm
  where exists (select 1 from caller)          -- registered callers only
    and p.account_type = 'registered'
    and p.id <> me.uid
    and not exists (
      select 1 from user_blocks b
      where (b.blocker_id = me.uid and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = me.uid)
    )
    and (
      p.friend_code = norm.code                 -- exact code: consent by sharing,
                                                -- bypasses discoverable
      or (p.discoverable
          and char_length(norm.name_prefix) >= 3
          and lower(p.username) like norm.name_prefix || '%')
    )
  order by (p.friend_code = norm.code) desc, lower(p.username)
  limit 10;
$$;

revoke all on function search_profiles(text) from public;
grant execute on function search_profiles(text) to authenticated;

-- ── 7. get_recent_players ─────────────────────────────────────────────────

create or replace function get_recent_players(p_limit integer default 20)
returns table (
  id              uuid,
  username        text,
  display_name    text,
  avatar_url      text,
  level           integer,
  last_played_at  timestamptz,
  games_together  bigint,
  is_friend       boolean,
  request_pending boolean
)
language sql
security definer
stable
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  ),
  co_players as (
    select rg2.user_id, max(rg.played_at) as last_played, count(*) as games
    from recent_games rg
    join recent_games rg2
      on rg2.room_id = rg.room_id and rg2.user_id <> rg.user_id
    where rg.user_id = (select uid from me)
      and rg.room_id is not null
    group by rg2.user_id
  )
  select
    p.id, p.username, p.display_name, p.avatar_url, p.level,
    c.last_played, c.games,
    exists (
      select 1 from friendships f, me
      where f.status = 'accepted'
        and ((f.user_id = me.uid and f.friend_id = p.id)
          or (f.friend_id = me.uid and f.user_id = p.id))
    ) as is_friend,
    exists (
      select 1 from friendships f, me
      where f.status = 'pending'
        and ((f.user_id = me.uid and f.friend_id = p.id)
          or (f.friend_id = me.uid and f.user_id = p.id))
    ) as request_pending
  from co_players c
  join profiles p on p.id = c.user_id, me
  where p.account_type = 'registered'   -- guests can't be befriended: hide them
    and not exists (
      select 1 from user_blocks b
      where (b.blocker_id = me.uid and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = me.uid)
    )
  order by c.last_played desc
  limit least(greatest(p_limit, 1), 50);
$$;

revoke all on function get_recent_players(integer) from public;
grant execute on function get_recent_players(integer) to authenticated;
