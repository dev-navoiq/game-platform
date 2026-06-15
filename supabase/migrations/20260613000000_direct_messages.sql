-- =============================================================================
-- Migration: Direct messaging between friends + game invites over DM
-- Date: 2026-06-13
--
-- Adds the first out-of-room chat surface. A user sees a thread per friend,
-- can send free-form text, and can send a typed `game_invite` message that
-- carries the room_id / game_type / room_code in `payload`. The recipient
-- taps Accept and joins the room.
--
-- Scope guard: this migration only enables messaging between users with an
-- accepted friendship (no global DMs to strangers). Blocked users on either
-- side prevent inserts. RLS owns this — there is no application-level check.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1 — direct_messages table
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists direct_messages (
  id            uuid primary key default gen_random_uuid(),
  sender_id     uuid not null references profiles(id) on delete cascade,
  recipient_id  uuid not null references profiles(id) on delete cascade,
  content       text not null,
  message_type  text not null default 'text'
                  check (message_type in ('text', 'game_invite', 'system')),
  payload       jsonb,
  created_at    timestamptz not null default now(),
  read_at       timestamptz,

  constraint dm_no_self_message check (sender_id <> recipient_id),
  constraint dm_content_length  check (char_length(content) between 1 and 1000)
);

-- Thread lookup: messages between two users, newest-first.
create index if not exists idx_dm_thread
  on direct_messages (
    least(sender_id, recipient_id),
    greatest(sender_id, recipient_id),
    created_at desc
  );

-- Inbox sort: every message I'm party to, newest-first.
create index if not exists idx_dm_recipient_unread
  on direct_messages (recipient_id, created_at desc)
  where read_at is null;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2 — RLS
-- ─────────────────────────────────────────────────────────────────────────────

alter table direct_messages enable row level security;

-- Read: I can see messages I sent or received, except where the other party
-- has blocked me (block hides both directions).
drop policy if exists dm_select_own on direct_messages;
create policy dm_select_own on direct_messages
  for select using (
    (auth.uid() = sender_id or auth.uid() = recipient_id)
    and not exists (
      select 1 from user_blocks ub
       where (ub.blocker_id = sender_id    and ub.blocked_id = recipient_id)
          or (ub.blocker_id = recipient_id and ub.blocked_id = sender_id)
    )
  );

-- Insert: only as myself, only to an accepted friend, and not if either
-- party has blocked the other.
drop policy if exists dm_insert_to_friend on direct_messages;
create policy dm_insert_to_friend on direct_messages
  for insert with check (
    auth.uid() = sender_id
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

-- Update: only the recipient can mark a message read (no content edits).
drop policy if exists dm_update_read_state on direct_messages;
create policy dm_update_read_state on direct_messages
  for update using (auth.uid() = recipient_id)
              with check (auth.uid() = recipient_id);

-- Delete: only the sender can retract their own message.
drop policy if exists dm_delete_own on direct_messages;
create policy dm_delete_own on direct_messages
  for delete using (auth.uid() = sender_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3 — mark_thread_read RPC
-- ─────────────────────────────────────────────────────────────────────────────
-- Tapping into a thread should mark every unread incoming message from that
-- friend as read in one round-trip. Doing this from the client requires
-- multiple round-trips and is racy against new incoming messages.

create or replace function mark_thread_read(p_other_user_id uuid)
returns int
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_updated int;
begin
  update direct_messages
     set read_at = now()
   where recipient_id = auth.uid()
     and sender_id    = p_other_user_id
     and read_at is null;

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4 — Realtime publication
-- ─────────────────────────────────────────────────────────────────────────────
-- The Flutter client uses .stream() on direct_messages to watch each thread.
-- Without this, stream() falls back to a one-shot fetch and never updates.
-- ALTER PUBLICATION is idempotent here because of the IF NOT EXISTS dance
-- elsewhere; if the table is already in the publication this errors, so we
-- guard.

do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'public'
       and tablename  = 'direct_messages'
  ) then
    execute 'alter publication supabase_realtime add table direct_messages';
  end if;
end$$;
