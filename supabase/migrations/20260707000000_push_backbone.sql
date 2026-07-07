-- Push notification backbone (social design doc prompts/26, M0).
--
-- 1. device_push_tokens — one row per (user, FCM token); client upserts on
--    login/token-refresh, deletes on logout; the sender prunes tokens FCM
--    reports as unregistered.
-- 2. notification_preferences.chat_messages — DM pushes get their own toggle
--    (the original 9 columns predate DMs).
-- 3. profiles.tz_offset_min — device UTC offset in minutes, refreshed by the
--    client on login. Quiet hours are evaluated server-side against this.
--    An offset (not an IANA zone) is deliberate: Dart can't portably report
--    the zone name, and a stale offset is off by at most one DST hour.
-- 4. webhook_config + notify_push_event() triggers — pg_net POST to the
--    notify-dispatch edge function on DM / friend-request / friend-accepted
--    events. Same single-row-config pattern as economy_config; staging/prod
--    must update the row with their real functions URL + secret (see
--    docs in prompts/26, §7.3).

create extension if not exists pg_net with schema extensions;

-- ── 1. Device push tokens ────────────────────────────────────────────────

create table device_push_tokens (
  user_id    uuid not null references profiles(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

create index idx_device_push_tokens_user on device_push_tokens(user_id);

alter table device_push_tokens enable row level security;

create policy device_push_tokens_select_own on device_push_tokens
  for select using (auth.uid() = user_id);
create policy device_push_tokens_insert_own on device_push_tokens
  for insert with check (auth.uid() = user_id);
create policy device_push_tokens_update_own on device_push_tokens
  for update using (auth.uid() = user_id);
create policy device_push_tokens_delete_own on device_push_tokens
  for delete using (auth.uid() = user_id);

-- ── 2. DM push toggle ────────────────────────────────────────────────────

alter table notification_preferences
  add column chat_messages boolean not null default true;

-- ── 3. Device UTC offset for server-side quiet hours ─────────────────────

alter table profiles
  add column tz_offset_min integer;

-- ── 4. Webhook config + push-event triggers ──────────────────────────────

create table webhook_config (
  id                 boolean primary key default true check (id),
  functions_base_url text not null,
  webhook_secret     text not null,
  enabled            boolean not null default true,
  updated_at         timestamptz not null default now()
);

-- Service-role only: RLS on, no policies.
alter table webhook_config enable row level security;

-- Local-dev defaults. host.docker.internal reaches the host's Kong port from
-- inside the Postgres container. Staging/prod: update this row with the
-- project functions URL + a real secret (matching the function's
-- NOTIFY_WEBHOOK_SECRET) after deploy.
insert into webhook_config (functions_base_url, webhook_secret)
values ('http://host.docker.internal:54321/functions/v1', 'local-dev-webhook-secret');

create or replace function notify_push_event()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  cfg webhook_config%rowtype;
begin
  select * into cfg from webhook_config where enabled limit 1;
  if not found then
    return new;
  end if;

  -- pg_net is async: this only enqueues the request, so the insert/update
  -- that fired the trigger never blocks on the edge function.
  perform net.http_post(
    url     := cfg.functions_base_url || '/notify-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', cfg.webhook_secret
    ),
    body    := jsonb_build_object(
      'event', tg_argv[0],
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 3000
  );
  return new;
end;
$$;

create trigger push_on_dm
  after insert on direct_messages
  for each row execute function notify_push_event('dm');

create trigger push_on_friend_request
  after insert on friendships
  for each row
  when (new.status = 'pending')
  execute function notify_push_event('friend_request');

create trigger push_on_friend_accepted
  after update on friendships
  for each row
  when (old.status = 'pending' and new.status = 'accepted')
  execute function notify_push_event('friend_accepted');
