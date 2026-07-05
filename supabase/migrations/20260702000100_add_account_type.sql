-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Identity model (Milestone 2)
-- Two-axis identity: account_type (guest | registered) × subscription_tier.
-- Guests are coin-economy only; gems / social / IAP require registration.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

create type account_type as enum ('guest', 'registered');

alter table profiles
  add column account_type account_type not null default 'registered';

-- Backfill existing anonymous users as guests (empty email or is_anonymous).
update profiles p
set account_type = 'guest'
from auth.users u
where u.id = p.id
  and (coalesce(u.is_anonymous, false) or nullif(u.email, '') is null);

-- ── Extend handle_new_user to stamp account_type at profile creation ─────────
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public, extensions
as $$
declare
  v_username text;
  v_referral_code text;
  v_account_type account_type;
begin
  -- Generate unique username from email (or 'guest' for anonymous users)
  v_username := coalesce(split_part(nullif(new.email, ''), '@', 1), 'guest') || '_' || substr(new.id::text, 1, 6);

  -- Anonymous users (no email) start as guests; everyone else is registered.
  v_account_type := case
    when coalesce(new.is_anonymous, false) or nullif(new.email, '') is null then 'guest'
    else 'registered'
  end;

  -- Generate unique 6-character referral code (alphanumeric uppercase)
  loop
    v_referral_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (select 1 from public.profiles where referral_code = v_referral_code);
  end loop;

  insert into public.profiles (id, username, display_name, referral_code, account_type)
  values (new.id, v_username, coalesce(new.raw_user_meta_data->>'full_name', v_username), v_referral_code, v_account_type);

  insert into public.notification_preferences (user_id)
  values (new.id);

  return new;
end;
$$;

-- Welcome gem grant is once-per-user: enforce at the ledger level so concurrent
-- account-upgrade calls can never double-grant.
create unique index uq_currency_welcome_gem
  on currency_transactions (user_id)
  where reason = 'welcome_gem_grant';
