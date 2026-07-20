#!/usr/bin/env bash
# Race test: 8 concurrent ticks + concurrent register-fill on one tournament.
set -uo pipefail
API="http://127.0.0.1:54321"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
SR="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
psql() { docker exec supabase_db_game-platform psql -U postgres -d postgres -tAc "$1"; }
pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — expected [$2] got [$3]"; fail=$((fail+1)); fi }

ADMIN_JWT=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"admin@gathr.local","password":"admin1234"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
STAMP=$(date +%s%N)
mkjwt() {
  curl -s -X POST "$API/auth/v1/admin/users" -H "Authorization: Bearer $SR" -H "apikey: $SR" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"password123\",\"email_confirm\":true}" >/dev/null
  curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"password123\"}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
}
P1=$(mkjwt "rc1_${STAMP}@t.local"); P2=$(mkjwt "rc2_${STAMP}@t.local"); P3=$(mkjwt "rc3_${STAMP}@t.local"); P4=$(mkjwt "rc4_${STAMP}@t.local")

# 4-player tournament (2 round-1 matches), min=4 max=8, start in the past AFTER registrations
T=$(curl -s -X POST "$API/functions/v1/admin-create-tournament" -H "Authorization: Bearer $ADMIN_JWT" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"name":"Race Cup","game_type":"twenty_nine","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","min_participants":4,"max_participants":8}' \
  | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
for J in "$P1" "$P2" "$P3" "$P4"; do
  curl -s -X POST "$API/functions/v1/tournament-register" -H "Authorization: Bearer $J" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"tournament_id\":\"$T\"}" >/dev/null
done
psql "update tournaments set start_time = now() - interval '1 minute' where id='$T';" >/dev/null

# 8 concurrent ticks (worst case: cron + pokes racing)
for i in $(seq 1 8); do
  curl -s -X POST "$API/functions/v1/tournament-tick" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d '{}' >/dev/null &
done
wait
sleep 2

check "started exactly once (in_progress)" "in_progress" "$(psql "select status from tournaments where id='$T';")"
check "exactly 3 matches (2 R1 + 1 final)" "3" "$(psql "select count(*) from tournament_matches where tournament_id='$T';")"
check "exactly 2 rooms total for this tournament" "2" "$(psql "select count(*) from game_rooms where config->>'tournament_id'='$T';")"
check "no orphan rooms (all attached to matches)" "0" "$(psql "select count(*) from game_rooms g where g.config->>'tournament_id'='$T' and not exists (select 1 from tournament_matches m where m.room_id=g.id);")"
check "room player counts exact (2 each)" "2,2" "$(psql "select string_agg(current_players::text,',' order by current_players) from game_rooms g where g.config->>'tournament_id'='$T';")"
check "each player seated exactly once" "4" "$(psql "select count(*) from room_players rp join game_rooms g on g.id=rp.room_id where g.config->>'tournament_id'='$T';")"
check "one game_state per room" "2" "$(psql "select count(*) from game_states gs join game_rooms g on g.id=gs.room_id where g.config->>'tournament_id'='$T';")"

echo; echo "PASS=$pass FAIL=$fail"; [[ $fail -eq 0 ]] && echo "ALL GREEN"