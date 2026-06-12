-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Room bot-substitution, turn timeout, and user preferences
-- Date: 2026-06-09
-- Plan: prompts/CARD-ANIMATION-PLAN.md — "DB migration" (Items 5a/5b/5c/5d)
--
-- Adds:
--   • enum bot_difficulty('easy','medium','hard')                  [if missing]
--   • game_rooms:
--       turn_seconds, auto_bot_on_disconnect, auto_bot_on_timeout,
--       auto_bot_difficulty, disconnect_grace_seconds
--   • room_players:
--       disconnected_at, original_user_id (FK profiles.id)
--       + partial index (room_id, disconnected_at) for the disconnect sweep
--   • profiles:
--       preferred_turn_seconds, preferred_auto_bot_on_disconnect,
--       preferred_auto_bot_on_timeout, preferred_auto_bot_difficulty
--
-- RLS: not touched — existing table-level policies cover these columns.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1 — bot_difficulty enum (idempotent)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (select 1 from pg_type where typname = 'bot_difficulty') then
    create type bot_difficulty as enum ('easy', 'medium', 'hard');
  end if;
end
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2 — game_rooms: turn timer + auto-bot policy
-- ─────────────────────────────────────────────────────────────────────────────
alter table game_rooms
  add column turn_seconds              int     not null default 30
    check (turn_seconds between 10 and 120),
  add column auto_bot_on_disconnect    boolean not null default true,
  add column auto_bot_on_timeout       boolean not null default true,
  add column auto_bot_difficulty       bot_difficulty not null default 'medium',
  add column disconnect_grace_seconds  int     not null default 15
    check (disconnect_grace_seconds between 5 and 60);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3 — room_players: disconnect tracking + original-user FK
-- ─────────────────────────────────────────────────────────────────────────────
alter table room_players
  add column disconnected_at  timestamptz null,
  add column original_user_id uuid        null references profiles(id);

create index idx_room_players_disconnected
  on room_players (room_id, disconnected_at)
  where disconnected_at is not null;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4 — profiles: user-level defaults (seeded into rooms on create)
-- ─────────────────────────────────────────────────────────────────────────────
alter table profiles
  add column preferred_turn_seconds             int     not null default 30,
  add column preferred_auto_bot_on_disconnect   boolean not null default true,
  add column preferred_auto_bot_on_timeout      boolean not null default true,
  add column preferred_auto_bot_difficulty      bot_difficulty not null default 'medium';
