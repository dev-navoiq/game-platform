-- #296 (root cause of the #293 duplicate pushes): a push token identifies a
-- PHYSICAL DEVICE, but rows were keyed (user_id, token) — every account that
-- ever logged in on a device kept its own row for the same token (one staging
-- iPhone had 18). Any push addressed to 2+ of those accounts hit the same
-- phone 2+ times, simultaneously. A device now belongs to exactly one user:
-- the one who registered it most recently (i.e. whoever is logged in).

-- 1. Keep only the newest claim per token.
delete from device_push_tokens t
using (
  select token, max(updated_at) as mx
  from device_push_tokens
  group by token
) k
where t.token = k.token
  and t.updated_at < k.mx;

-- Ties (same token, same timestamp, different users) — extremely unlikely,
-- but the unique index below must not fail: keep an arbitrary single row.
delete from device_push_tokens t
using device_push_tokens t2
where t.token = t2.token
  and t.ctid < t2.ctid;

-- 2. One row per physical device, enforced.
create unique index if not exists uq_device_push_token
  on device_push_tokens (token);

-- 3. Registration RPC: claims the device for the caller (stealing it from
-- any previous account — RLS prevents the client doing that directly) and
-- drops the caller's older same-platform tokens (reinstall mints a new one).
create or replace function public.register_push_token(
  p_token text,
  p_platform text
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_platform not in ('ios', 'android') then
    raise exception 'invalid platform';
  end if;

  delete from device_push_tokens
  where token = p_token and user_id <> auth.uid();

  delete from device_push_tokens
  where user_id = auth.uid() and platform = p_platform and token <> p_token;

  insert into device_push_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.register_push_token(text, text)
  to authenticated;
