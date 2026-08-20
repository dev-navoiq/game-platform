-- #285: the app fetches feature flags once at startup, BEFORE login, so the
-- fetch runs as anon — and the existing select policy only covered
-- authenticated. Result: zero flags client-side and every gated game sealed
-- even with all flags enabled (caught in the PR #294 Phase-1 test). Active
-- flags are not secrets; let anon read them. Applied to staging 2026-08-20.
drop policy if exists "Feature flags readable by anon" on feature_flags;
create policy "Feature flags readable by anon"
  on feature_flags for select to anon
  using (is_active = true);
