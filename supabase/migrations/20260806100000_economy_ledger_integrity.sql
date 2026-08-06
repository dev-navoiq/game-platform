-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Economy ledger integrity (#234) + history fixes (#235, #236)
--
-- #234: creditCurrency updated the wallet FIRST and then inserted the ledger
--   row without checking the result — uq_currency_game_reward (one game_reward
--   per user+room, ever) silently swallowed the insert on Play Again rematches
--   (the restart deliberately re-arms rewards for the same room), leaving
--   wallet ≠ Σ ledger. Fix: per-session key on the uniqueness, and an atomic
--   RPC where the wallet only moves if the ledger row inserts.
-- #235: record_game_completion listed the player themselves in opponent_names.
-- #236 (audit gap): game_moves.player_id FK → profiles rejected every BOT move
--   (bots have no profile row) and the insert error was unchecked — so trick
--   attribution disputes were unauditable. Drop the FK; player_id stays uuid.
--
-- Idempotent: applied to staging via direct SQL before landing in the chain.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

-- ── #234a: session-scoped double-credit guard ────────────────────────────────
alter table currency_transactions add column if not exists session_key text;

drop index if exists uq_currency_game_reward;
create unique index if not exists uq_currency_game_reward
  on currency_transactions (user_id, reference_id, coalesce(session_key, ''))
  where reason = 'game_reward';

-- ── #234b: atomic credit — wallet moves iff the ledger row inserts ───────────
create or replace function credit_currency_atomic(
  p_user_id      uuid,
  p_currency     text,
  p_amount       integer,
  p_reason       text,
  p_reference_id uuid default null,
  p_session_key  text default null
)
returns table(credited boolean, balance_after integer) as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'credit amount must be positive';
  end if;
  if p_currency not in ('coins', 'gems') then
    raise exception 'unknown currency %', p_currency;
  end if;

  -- Serialize concurrent credits for this user (fixes the read-modify-write
  -- race the old TS implementation had).
  select case when p_currency = 'coins' then coins else gems end
    into v_balance
    from profiles where id = p_user_id
    for update;
  if not found then
    raise exception 'profile not found: %', p_user_id;
  end if;

  begin
    insert into currency_transactions
      (user_id, currency, amount, balance_after, reason, reference_id, session_key)
    values
      (p_user_id, p_currency, p_amount, v_balance + p_amount, p_reason,
       p_reference_id, p_session_key);
  exception when unique_violation then
    -- Duplicate credit for this (user, reference, session): wallet must NOT
    -- move. Report the unchanged balance.
    return query select false, v_balance;
    return;
  end;

  if p_currency = 'coins' then
    update profiles set coins = v_balance + p_amount where id = p_user_id;
  else
    update profiles set gems = v_balance + p_amount where id = p_user_id;
  end if;

  return query select true, v_balance + p_amount;
end;
$$ language plpgsql security definer;

-- ── #235: opponent_names must exclude the player themselves ──────────────────
create or replace function record_game_completion(
  p_room_id   uuid,
  p_game_type game_type,
  p_results   jsonb
)
returns void as $$
declare
  result_row   jsonb;
  player_names text[];
begin
  for result_row in select * from jsonb_array_elements(p_results)
  loop
    -- Opponents = everyone in the room EXCEPT this player (#235).
    select array_agg(p.username)
    into player_names
    from room_players rp
    join profiles p on rp.user_id = p.id
    where rp.room_id = p_room_id
      and rp.user_id <> (result_row->>'user_id')::uuid;

    insert into recent_games (
      user_id, game_type, room_id, result, final_position, points_earned,
      elo_change, opponent_names,
      coins_earned, xp_earned, gems_earned, first_win_bonus, daily_cap_hit
    ) values (
      (result_row->>'user_id')::uuid,
      p_game_type,
      p_room_id,
      result_row->>'result',
      (result_row->>'position')::int,
      (result_row->>'points')::int,
      (result_row->>'elo_change')::int,
      player_names,
      coalesce((result_row->>'coins_earned')::int, 0),
      coalesce((result_row->>'xp_earned')::int, 0),
      coalesce((result_row->>'gems_earned')::int, 0),
      coalesce((result_row->>'first_win_bonus')::boolean, false),
      coalesce((result_row->>'daily_cap_hit')::boolean, false)
    );
  end loop;
end;
$$ language plpgsql security definer;

-- ── #236 audit gap: let bot moves persist in game_moves ──────────────────────
alter table game_moves drop constraint if exists game_moves_player_id_fkey;
