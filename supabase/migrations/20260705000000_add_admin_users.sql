-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Admin users (Admin web app — Phase A)
-- Dedicated allow-list table for privileged operators. Admin authorization for
-- edge functions is gated on membership here (see _shared/admin.ts). Writes are
-- service-role only; a user may read their own row so the admin web app can
-- decide whether to show the console.
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

create table admin_users (
  user_id    uuid primary key references profiles(id) on delete cascade,
  granted_by uuid references profiles(id),
  granted_at timestamptz not null default now(),
  note       text
);

alter table admin_users enable row level security;

-- A user may check their own admin status; nobody can list other admins from the
-- client. All privileged writes go through service-role edge functions.
create policy "admins can read own row"
  on admin_users for select
  to authenticated
  using (user_id = auth.uid());

-- ── Seed the first admin ─────────────────────────────────────────────────────
-- Bootstraps by email so this is portable across environments. No-ops if the
-- account doesn't exist yet in this database (e.g. fresh local reset). Edit the
-- email / add rows to grant more admins.
insert into admin_users (user_id, note)
select u.id, 'seed: initial admin'
from auth.users u
where u.email = 'ambartyagi@gmail.com'
on conflict (user_id) do nothing;
