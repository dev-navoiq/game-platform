-- #57 (owner-caught): Apple Hide-My-Email signups got gibberish usernames —
-- handle_new_user derived from the email prefix, which for a private relay
-- is random ("m8sk28w6yj_b3c19b"). Derivation order is now: provider-supplied
-- full name (Apple sends it on first auth, Google always) → email prefix
-- unless it's a relay address → 'player'. The _xxxxxx id suffix stays for
-- uniqueness across all paths.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_base text;
  v_username text;
  v_referral_code text;
  v_account_type account_type;
begin
  -- Preferred: humanize the provider-supplied name ("Tuski Gupta" → tuski_gupta)
  v_base := lower(regexp_replace(
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''),
    '[^a-zA-Z0-9]+', '_', 'g'));
  v_base := trim(both '_' from v_base);

  -- Fallback: email prefix — but never from an Apple private relay, where
  -- the prefix is meaningless noise.
  if v_base = '' then
    if nullif(new.email, '') is not null
       and new.email not like '%@privaterelay.appleid.com' then
      v_base := split_part(new.email, '@', 1);
    end if;
  end if;

  if v_base = '' or v_base is null then
    v_base := case
      when coalesce(new.is_anonymous, false) or nullif(new.email, '') is null
        then 'guest'
      else 'player'
    end;
  end if;

  v_username := substr(v_base, 1, 20) || '_' || substr(new.id::text, 1, 6);

  v_account_type := case
    when coalesce(new.is_anonymous, false) or nullif(new.email, '') is null then 'guest'
    else 'registered'
  end;

  loop
    v_referral_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (select 1 from public.profiles where referral_code = v_referral_code);
  end loop;

  insert into public.profiles (id, username, display_name, referral_code, account_type)
  values (new.id, v_username,
          coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), v_username),
          v_referral_code, v_account_type);

  insert into public.notification_preferences (user_id)
  values (new.id);

  return new;
end;
$$;
