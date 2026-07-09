-- M2 — tournament invites over DM + tournament chat realtime.
--
-- direct_messages grows two typed messages (design doc prompts/26 §4/§6):
--   party_invite      {party_id, expires_at}            (used from M3)
--   tournament_invite {tournament_id, name, game_type, start_time}
-- tournament_chat has existed since 20260310 but was never in the realtime
-- publication, so its (previously unbuilt) UI could not stream.

alter table direct_messages
  drop constraint direct_messages_message_type_check;
alter table direct_messages
  add constraint direct_messages_message_type_check
  check (message_type in ('text', 'game_invite', 'system',
                          'party_invite', 'tournament_invite'));

alter publication supabase_realtime add table tournament_chat;
