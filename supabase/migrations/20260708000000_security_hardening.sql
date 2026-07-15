-- ═══════════════════════════════════════════════════════════════════════════
-- SECURITY HARDENING (2026-07-08)
--
-- Closes the RLS findings from SECURITY-AUDIT.md. The root cause across the
-- board: policies gated *row ownership* (auth.uid() = id) but not *column
-- mutability*, so a row owner could rewrite money/rank/identity/progress
-- columns of their own row. See SECURITY-GUIDELINES.md invariants I1–I8.
--
-- Trigger strategy for column locks: the trigger functions run SECURITY INVOKER
-- (the default) so `current_user` reflects the real PostgREST role — 'authenticated'
-- or 'anon' for clients, 'service_role' for edge functions, 'postgres' for
-- migrations. We enforce only against client roles; edge functions (service_role)
-- and internal/migration writes pass through untouched.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- C1 / H4 — profiles: coins / gems / tier / xp / level / identity are
-- server-managed. Clients keep updating display_name, avatar_url, bio,
-- current_activity, preferred_social_mode, tz_offset_min, username, etc.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function enforce_protected_profile_columns()
returns trigger
language plpgsql
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new; -- service_role / postgres / internal: trusted
  end if;

  if new.coins                   is distinct from old.coins
     or new.gems                 is distinct from old.gems
     or new.subscription_tier    is distinct from old.subscription_tier
     or new.subscription_expires_at is distinct from old.subscription_expires_at
     or new.xp                   is distinct from old.xp
     or new.level                is distinct from old.level
     or new.xp_to_next_level     is distinct from old.xp_to_next_level
     or new.account_type         is distinct from old.account_type
     or new.referred_by          is distinct from old.referred_by
     or new.referral_code        is distinct from old.referral_code then
    raise exception
      'profiles: coins/gems/tier/xp/level/identity are server-managed; use an edge function'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_protected_profile_columns on profiles;
create trigger trg_enforce_protected_profile_columns
  before update on profiles
  for each row execute function enforce_protected_profile_columns();

-- ─────────────────────────────────────────────────────────────────────────────
-- H1(season) / C2(season) — user_season_progress: level / xp / premium are
-- server-managed (advanced by rewards.ts addSeasonXp + claim flows). Clients
-- read only; the Flutter saveProgress() path becomes a no-op.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function enforce_protected_season_progress()
returns trigger
language plpgsql
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if coalesce(new.level, 0) <> 0
       or coalesce(new.xp, 0) <> 0
       or new.premium_purchased_at is not null then
      raise exception 'user_season_progress: level/xp/premium are server-managed'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if new.level               is distinct from old.level
     or new.xp               is distinct from old.xp
     or new.premium_purchased_at is distinct from old.premium_purchased_at then
    raise exception 'user_season_progress: level/xp/premium are server-managed'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_protected_season_progress on user_season_progress;
create trigger trg_enforce_protected_season_progress
  before insert or update on user_season_progress
  for each row execute function enforce_protected_season_progress();

-- ─────────────────────────────────────────────────────────────────────────────
-- H3(leaderboards) — leaderboards are rank data; no client writer exists at
-- runtime (matchmaking only READS rating). Remove the client write policies so
-- rating/wins can only be set by a future server-side game-end path.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "leaderboards_upsert_own" on leaderboards;
drop policy if exists "leaderboards_update_own" on leaderboards;

-- ─────────────────────────────────────────────────────────────────────────────
-- C2 / C4 — tournament_participants: registration + standings are
-- server-authoritative (tournament-register / tournament_report via service
-- role). Remove client INSERT (free entry) and UPDATE (self-rig wins/points).
-- Withdraw (delete) stays — tournament-unregister also flows server-side, and a
-- self-delete cannot rig standings.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Users can register themselves" on tournament_participants;
drop policy if exists "Users can update own participation" on tournament_participants;

-- ─────────────────────────────────────────────────────────────────────────────
-- C3 / H4(gem_cup) / L1 — tournaments: player-created tournaments must be
-- registered Pro/Max, cannot self-declare is_official, and cannot self-fund
-- gem_cup. (gem_cup payout clamp is also enforced in tournament_report.ts.)
-- Admin-created tournaments use the service role and bypass this policy.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Organizer can create tournaments" on tournaments;
create policy "Organizer can create tournaments"
  on tournaments for insert
  with check (
    organizer_id = auth.uid()
    and is_official = false
    and (settings -> 'gem_cup') is null
    and exists (
      select 1 from profiles p
       where p.id = auth.uid()
         and p.account_type = 'registered'
         and p.subscription_tier in ('pro', 'max')
    )
  );

-- Organizer update must not let them flip is_official or inject a gem_cup after
-- creation. Add a WITH CHECK (the original policy had none).
drop policy if exists "Organizer can update own tournaments" on tournaments;
create policy "Organizer can update own tournaments"
  on tournaments for update
  using (organizer_id = auth.uid())
  with check (
    organizer_id = auth.uid()
    and is_official = false
    and (settings -> 'gem_cup') is null
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- M1 — game_rooms: add WITH CHECK so a host cannot reassign created_by or
-- otherwise escape ownership on update/delete.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "game_rooms_update_own" on game_rooms;
create policy "game_rooms_update_own" on game_rooms
  for update to authenticated
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

-- ─────────────────────────────────────────────────────────────────────────────
-- M2 — friendships: add WITH CHECK, and gate creation to registered accounts
-- (I4). Guests must register before building a social graph.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "friendships_insert_own" on friendships;
create policy "friendships_insert_own" on friendships
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from profiles p
       where p.id = auth.uid() and p.account_type = 'registered'
    )
    -- H6/L2 — cap outgoing friend requests at 20/day to stop spam/enumeration.
    and (
      select count(*) from friendships f
       where f.user_id = auth.uid()
         and f.created_at > now() - interval '1 day'
    ) < 20
  );

drop policy if exists "friendships_update_own" on friendships;
create policy "friendships_update_own" on friendships
  for update to authenticated
  using (auth.uid() = user_id or auth.uid() = friend_id)
  with check (auth.uid() = user_id or auth.uid() = friend_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- H9 — chat / reactions / mute votes: INSERT must verify the author is actually
-- a member of the room (I3). Previously only checked auth.uid() = author, so a
-- user could spam/vote into any room they were not in.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "chat_messages_insert_own" on chat_messages;
create policy "chat_messages_insert_own" on chat_messages
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from room_players rp
       where rp.room_id = chat_messages.room_id and rp.user_id = auth.uid()
    )
  );

drop policy if exists "quick_reactions_insert_own" on quick_reactions;
create policy "quick_reactions_insert_own" on quick_reactions
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from room_players rp
       where rp.room_id = quick_reactions.room_id and rp.user_id = auth.uid()
    )
  );

drop policy if exists "mute_votes_insert_own" on mute_votes;
create policy "mute_votes_insert_own" on mute_votes
  for insert to authenticated
  with check (
    auth.uid() = voter_id
    and exists (
      select 1 from room_players rp
       where rp.room_id = mute_votes.room_id and rp.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- H9(DM) — direct_messages: also require the sender be a registered account
-- (I4), on top of the existing friend-gate + block-check.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists dm_insert_to_friend on direct_messages;
create policy dm_insert_to_friend on direct_messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from profiles p
       where p.id = auth.uid() and p.account_type = 'registered'
    )
    and exists (
      select 1 from friendships f
       where f.status = 'accepted'
         and (
           (f.user_id = sender_id    and f.friend_id = recipient_id) or
           (f.user_id = recipient_id and f.friend_id = sender_id)
         )
    )
    and not exists (
      select 1 from user_blocks ub
       where (ub.blocker_id = sender_id    and ub.blocked_id = recipient_id)
          or (ub.blocker_id = recipient_id and ub.blocked_id = sender_id)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- M5 — game_rooms.password_hash must not be readable by clients. The
-- game_rooms_select_all policy returns every column; revoke SELECT on the hash
-- column so private-room passwords can only be verified inside join-room.
-- (M4: hashing should also move to a salted KDF inside the edge function — see
-- SECURITY-GUIDELINES I5; tracked as follow-up in the edge function.)
-- ─────────────────────────────────────────────────────────────────────────────
revoke select (password_hash) on game_rooms from authenticated, anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- M4(record_game_completion) / M6 — SECURITY DEFINER RPC callable by any client
-- with a client-supplied user_id. Restrict EXECUTE to the service role only.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1 from pg_proc where proname = 'record_game_completion'
  ) then
    execute 'revoke execute on function record_game_completion(uuid, game_type, jsonb) from public, anon, authenticated';
  end if;
exception when others then
  -- signature may differ; leave a notice rather than failing the migration
  raise notice 'record_game_completion revoke skipped: %', sqlerrm;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- H3(challenges) — idempotency guard: a challenge reward can be credited at
-- most once per (user, challenge), regardless of the client resetting
-- reward_claimed. claim-challenge-reward already credits with
-- reason='challenge_reward' and reference_id=challenge_id.
-- NOTE: this closes the *infinite* re-claim. Fully closing "claim once without
-- earning" requires server-side challenge progress advancement — tracked in
-- SECURITY-GUIDELINES §7.
-- ─────────────────────────────────────────────────────────────────────────────
create unique index if not exists uq_currency_challenge_reward
  on currency_transactions (user_id, reference_id)
  where reason = 'challenge_reward';

-- ─────────────────────────────────────────────────────────────────────────────
-- H1(replay) — verify-subscription tags monthly grants with the RevenueCat
-- event id; this index makes a replayed webhook a no-op (one grant per event).
-- ─────────────────────────────────────────────────────────────────────────────
create unique index if not exists uq_currency_subscription_monthly
  on currency_transactions (user_id, reference_id)
  where reason = 'subscription_monthly';

-- ─────────────────────────────────────────────────────────────────────────────
-- C5 (foundation) — private hands must NOT live in the world-readable
-- game_states row (opponents currently read each other's cards via SELECT /
-- Realtime). This table is the per-viewer store: RLS scopes each row to its
-- owner, so Realtime only ever streams a player their own hand.
--
-- SCAFFOLDING ONLY — no writers yet. The server/client cutover (game_setup
-- writes here, validate-move merges here, reconcile-state / the Flutter provider
-- read here, and game_states keeps only public state + hand COUNTS) is a
-- correctness-sensitive change across all six card games that needs a local
-- test loop; it is specified step-by-step in SECURITY-GUIDELINES §7 (C5).
-- Until that lands, game_states still carries hands and C5 remains open.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists player_hands (
  room_id    uuid not null references game_rooms(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  hand       jsonb not null default '[]',
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

alter table player_hands enable row level security;

-- Owner-only read; no client write policy (service-role edge functions only).
drop policy if exists player_hands_select_own on player_hands;
create policy player_hands_select_own on player_hands
  for select to authenticated
  using (auth.uid() = user_id);
