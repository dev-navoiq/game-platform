-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Tournament check-in (prompts/25 §T6)
-- Opt-in ready gate: when check_in_minutes > 0, a check-in window opens that
-- many minutes before start_time. At start, participants who never checked in
-- are dropped + refunded before seeding (no-shows can't hollow out a bracket).
-- 0 (default) preserves existing behavior exactly. Participant plumbing
-- (status 'checked_in', checked_in_at) has existed since the original
-- tournaments migration — this finally uses it.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

alter table tournaments
  add column check_in_minutes integer not null default 0
    check (check_in_minutes >= 0 and check_in_minutes <= 1440);
