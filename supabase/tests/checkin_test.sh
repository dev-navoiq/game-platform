#!/usr/bin/env bash
# T6 check-in harness: window gating, no fill-start, announce push flag,
# no-show drop + refund at start.
# Requires: `supabase start` running locally. Safe to re-run (fresh users/rows).
set -uo pipefail
API="http://127.0.0.1:54321"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
SR="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
psql() { docker exec supabase_db_game-platform psql -U postgres -d postgres -tAc "$1"; }
pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — expected [$2] got [$3]"; fail=$((fail+1)); fi }
tick() { curl -s -X POST "$API/functions/v1/tournament-tick" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d '{}' >/dev/null; }
fn() { curl -s -X POST "$API/functions/v1/$1" -H "Authorization: Bearer $2" -H "apikey: $ANON" -H "Content-Type: application/json" -d "$3"; }
fncode() { curl -s -o /dev/null -w '%{http_code}' -X POST "$API/functions/v1/$1" -H "Authorization: Bearer $2" -H "apikey: $ANON" -H "Content-Type: application/json" -d "$3"; }

ADMIN_JWT=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"admin@gathr.local","password":"admin1234"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
[[ -z "$ADMIN_JWT" ]] && { echo "FATAL: admin login failed (seed admin@gathr.local/admin1234 first)"; exit 1; }

STAMP=$(date +%s%N)
for i in 1 2 3 4; do
  E="ci${i}_${STAMP}@t.local"
  curl -s -X POST "$API/auth/v1/admin/users" -H "Authorization: Bearer $SR" -H "apikey: $SR" -H "Content-Type: application/json" \
    -d "{\"email\":\"$E\",\"password\":\"password123\",\"email_confirm\":true}" >/dev/null
  JWT[$i]=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$E\",\"password\":\"password123\"}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
  ID[$i]=$(psql "select id from auth.users where email='$E';")
done
psql "update profiles set coins=1000 where id in ('${ID[1]}','${ID[2]}','${ID[3]}','${ID[4]}');" >/dev/null

echo "── 1. Create with check-in; full roster must NOT auto-start ──"
T=$(fn admin-create-tournament "$ADMIN_JWT" '{"name":"CheckIn Cup","game_type":"twenty_nine","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","min_participants":2,"max_participants":4,"entry_fee_coins":100,"check_in_minutes":10}' \
  | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[[ -z "$T" ]] && { echo "FATAL: create failed"; exit 1; }
for i in 1 2 3 4; do fn tournament-register "${JWT[$i]}" "{\"tournament_id\":\"$T\"}" >/dev/null; done
check "4/4 registered" "4" "$(psql "select current_participants from tournaments where id='$T';")"
check "full but NOT started (check-in pending)" "registration" "$(psql "select status from tournaments where id='$T';")"

echo "── 2. Window closed → check-in rejected ──"
check "check-in before window → 409" "409" "$(fncode tournament-check-in "${JWT[1]}" "{\"tournament_id\":\"$T\"}")"

echo "── 3. Window opens → announce flag + check-ins ──"
psql "update tournaments set start_time = now() + interval '5 minutes' where id='$T';" >/dev/null  # window = start-10min → open
tick
check "announce flag set once" "true" "$(psql "select settings->>'check_in_notified' from tournaments where id='$T';")"
check "still registration (start in future)" "registration" "$(psql "select status from tournaments where id='$T';")"
for i in 1 2 3; do fn tournament-check-in "${JWT[$i]}" "{\"tournament_id\":\"$T\"}" >/dev/null; done
check "3 checked in" "3" "$(psql "select count(*) from tournament_participants where tournament_id='$T' and status='checked_in';")"
check "idempotent re-check-in ok" "200" "$(fncode tournament-check-in "${JWT[1]}" "{\"tournament_id\":\"$T\"}")"

echo "── 4. Start: no-show dropped + refunded; 3 play ──"
C4_BEFORE=$(psql "select coins from profiles where id='${ID[4]}';")
psql "update tournaments set start_time = now() - interval '1 minute' where id='$T';" >/dev/null
tick
check "started" "in_progress" "$(psql "select status from tournaments where id='$T';")"
check "3 participants remain" "3" "$(psql "select count(*) from tournament_participants where tournament_id='$T';")"
check "no-show refunded (+100)" "$((C4_BEFORE + 100))" "$(psql "select coins from profiles where id='${ID[4]}';")"
check "no-show ledger flagged refunded" "t" "$(psql "select refunded from tournament_entry_ledger where tournament_id='$T' and user_id='${ID[4]}';")"
check "bracket built for 3 (3 rows incl. 1 bye)" "3-1" "$(psql "select count(*)||'-'||count(*) filter (where status='bye') from tournament_matches where tournament_id='$T';")"

echo "── 5. No-check-in tournament rejects check-in fn ──"
T2=$(fn admin-create-tournament "$ADMIN_JWT" '{"name":"NoCheckIn","game_type":"twenty_nine","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","min_participants":2,"max_participants":8}' \
  | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fn tournament-register "${JWT[1]}" "{\"tournament_id\":\"$T2\"}" >/dev/null
check "check-in on non-check-in tournament → 400" "400" "$(fncode tournament-check-in "${JWT[1]}" "{\"tournament_id\":\"$T2\"}")"

echo; echo "PASS=$pass FAIL=$fail"; [[ $fail -eq 0 ]] && echo "ALL GREEN"