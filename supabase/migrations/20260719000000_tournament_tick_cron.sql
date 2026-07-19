-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: tournament-tick heartbeat (prompts/25 §T1 + §T2)
-- pg_cron invokes the tournament-tick edge function every minute via pg_net.
--
-- The function URL + anon key live in app_config (seeded per environment, NOT
-- in this migration — local/staging/prod differ). Until both keys are seeded,
-- invoke_tournament_tick() is a silent no-op, so this migration is safe to
-- apply everywhere. Seed with:
--   insert into app_config(key, value) values
--     ('edge_base_url', 'https://<ref>.supabase.co'),
--     ('edge_anon_key', '<anon key>')
--   on conflict (key) do update set value = excluded.value;
-- (Both values are public-by-design; app_config is still service-role only.)
-- ─────────────────────────────────────────────────────────────────────────────

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ── app_config: tiny env-specific key/value store (service-role only) ────────
create table if not exists app_config (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);
alter table app_config enable row level security;
-- No policies: not readable/writable from clients. Service role bypasses RLS.

-- ── invoke_tournament_tick: fire-and-forget POST to the edge function ────────
create or replace function invoke_tournament_tick()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  base_url text;
  anon_key text;
begin
  select value into base_url from app_config where key = 'edge_base_url';
  select value into anon_key from app_config where key = 'edge_anon_key';
  if base_url is null or anon_key is null then
    return; -- environment not seeded yet: no-op
  end if;

  perform net.http_post(
    url := base_url || '/functions/v1/tournament-tick',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || anon_key
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 8000
  );
end;
$$;

-- ── Schedule: every minute (idempotent re-schedule) ──────────────────────────
do $$
begin
  perform cron.unschedule('tournament-tick');
exception when others then
  null; -- not scheduled yet
end;
$$;

select cron.schedule('tournament-tick', '* * * * *', 'select public.invoke_tournament_tick()');
