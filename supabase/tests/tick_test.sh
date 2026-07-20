#!/usr/bin/env bash
# tournament-tick harness: due starts, auto-cancel, stall sweep, idempotency,
# and pg_cron→pg_net→edge plumbing.
set -uo pipefail
API="http://127.0.0.1:54321"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
SR="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
psql() { docker exec supabase_db_game-platform psql -U postgres -d postgres -tAc "$1"; }
pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — expected [$2] got [$3]"; fail=$((fail+1)); fi }
tick() { curl -s -X POST "$API/functions/v1/tournament-tick" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d '{}'; }

ADMIN_JWT=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"admin@gathr.local","password":"admin1234"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
[[ -z "$ADMIN_JWT" ]] && { echo "FATAL: admin login failed"; exit 1; }

mkjwt() {
  curl -s -X POST "$API/auth/v1/admin/users" -H "Authorization: Bearer $SR" -H "apikey: $SR" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"password123\",\"email_confirm\":true}" >/dev/null
  curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"password123\"}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
}
mktourn() { # name extra_json -> id  (future start so registrations settle first)
  curl -s -X POST "$API/functions/v1/admin-create-tournament" -H "Authorization: Bearer $ADMIN_JWT" -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"name\":\"$1\",\"game_type\":\"twenty_nine\",\"format\":\"single_elimination\",\"start_time\":\"2027-01-01T00:00:00Z\",\"min_participants\":2,\"max_participants\":8$2}" \
    | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}
register() { curl -s -X POST "$API/functions/v1/tournament-register" -H "Authorization: Bearer $1" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"tournament_id\":\"$2\"}" >/dev/null; }

STAMP=$(date +%s%N)
P1=$(mkjwt "tk1_${STAMP}@t.local"); P2=$(mkjwt "tk2_${STAMP}@t.local")
P1_ID=$(psql "select id from auth.users where email='tk1_${STAMP}@t.local';")
P2_ID=$(psql "select id from auth.users where email='tk2_${STAMP}@t.local';")

echo "── A. Due start (min met, not full: the tester scenario) ──"
TA=$(mktourn "TickStart Cup" "")
register "$P1" "$TA"; register "$P2" "$TA"
check "pre-tick: registration (2/8)" "registration" "$(psql "select status from tournaments where id='$TA';")"
psql "update tournaments set start_time = now() - interval '1 minute' where id='$TA';" >/dev/null
R=$(tick)
check "tick reports started" "1" "$(echo "$R" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['started']))")"
check "A: in_progress" "in_progress" "$(psql "select status from tournaments where id='$TA';")"
check "A: room opened" "1" "$(psql "select count(*) from tournament_matches where tournament_id='$TA' and room_id is not null;")"

echo "── B. Due start under min → auto-cancel ──"
TB=$(mktourn "TickCancel Cup" "")
psql "update tournaments set start_time = now() - interval '1 minute' where id='$TB';" >/dev/null
R=$(tick)
check "tick reports cancelled" "1" "$(echo "$R" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['cancelled']))")"
check "B: cancelled" "cancelled" "$(psql "select status from tournaments where id='$TB';")"

echo "── C. Stall sweep: forfeit the on-turn player ──"
MID=$(psql "select id from tournament_matches where tournament_id='$TA';")
ROOM=$(psql "select room_id from tournament_matches where id='$MID';")
TURN=$(psql "select state_data->>'currentPlayerId' from game_states where room_id='$ROOM';")
EXPECT_WINNER=$([ "$TURN" == "$P1_ID" ] && echo "$P2_ID" || echo "$P1_ID")
# The updated_at trigger overwrites any manual backdate — disable it around the update.
psql "alter table game_states disable trigger game_states_updated_at;
update game_states set updated_at = now() - interval '11 minutes' where room_id='$ROOM';
alter table game_states enable trigger game_states_updated_at;" >/dev/null
R=$(tick)
check "tick reports 1 forfeit" "1" "$(echo "$R" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['forfeited']))")"
check "C: forfeited the on-turn player" "$TURN" "$(echo "$R" | python3 -c "import json,sys; print(json.load(sys.stdin)['forfeited'][0]['forfeited_user'])")"
check "C: match completed" "completed" "$(psql "select status from tournament_matches where id='$MID';")"
check "C: winner is the opponent" "$EXPECT_WINNER" "$(psql "select winner_id from tournament_matches where id='$MID';")"
check "C: tournament completed" "completed" "$(psql "select status from tournaments where id='$TA';")"
check "C: room abandoned" "abandoned" "$(psql "select status from game_rooms where id='$ROOM';")"

echo "── D. Idempotency: second tick does nothing ──"
R=$(tick)
check "no starts/cancels/forfeits" "0-0-0" "$(echo "$R" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"{len(d['started'])}-{len(d['cancelled'])}-{len(d['forfeited'])}\")")"

echo "── E. pg_cron → pg_net plumbing (seed, fire, check response, unseed) ──"
psql "insert into app_config(key,value) values ('edge_base_url','http://supabase_kong_game-platform:8000'),('edge_anon_key','$ANON') on conflict (key) do update set value=excluded.value;" >/dev/null
BEFORE_ID=$(psql "select coalesce(max(id),0) from net._http_response;")
psql "select invoke_tournament_tick();" >/dev/null
sleep 5
check "pg_net request completed with 200" "200" "$(psql "select status_code from net._http_response where id > $BEFORE_ID order by id desc limit 1;")"
psql "delete from app_config where key in ('edge_base_url','edge_anon_key');" >/dev/null  # keep local cron a no-op

echo; echo "PASS=$pass FAIL=$fail"; [[ $fail -eq 0 ]] && echo "ALL GREEN"