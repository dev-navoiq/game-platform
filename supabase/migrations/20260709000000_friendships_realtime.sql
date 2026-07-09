-- friendships was missing from the realtime publication, so the Friends
-- screen's watchFriendships() stream got its initial fetch and then went
-- deaf — accepting a request updated the row but the UI never re-emitted
-- (found on-device during the M1 pass, 2026-07-09).
alter publication supabase_realtime add table friendships;
