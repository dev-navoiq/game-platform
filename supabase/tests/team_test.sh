#!/usr/bin/env bash
# Team tournament (2v2) harness: allow-list, team register flows, solo pairing,
# drop+refund, 4p seating parity, team sweep-forfeit, split payouts, cleanup.
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
[[ -z "$ADMIN_JWT" ]] && { echo "FATAL: admin login failed"; exit 1; }

STAMP=$(date +%s%N)
for i in 1 2 3 4 5; do
  E="tm${i}_${STAMP}@t.local"
  curl -s -X POST "$API/auth/v1/admin/users" -H "Authorization: Bearer $SR" -H "apikey: $SR" -H "Content-Type: application/json" \
    -d "{\"email\":\"$E\",\"password\":\"password123\",\"email_confirm\":true}" >/dev/null
  JWT[$i]=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$E\",\"password\":\"password123\"}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
  ID[$i]=$(psql "select id from auth.users where email='$E';")
done
psql "update profiles set coins=1000 where id in ('${ID[1]}','${ID[2]}','${ID[3]}','${ID[4]}','${ID[5]}');" >/dev/null

echo "── 1. Allow-list (T3) ──"
R=$(fncode admin-create-tournament "$ADMIN_JWT" '{"name":"x","game_type":"bridge","format":"single_elimination","start_time":"2027-01-01T00:00:00Z"}')
check "1v1 bridge rejected" "400" "$R"
R=$(fncode admin-create-tournament "$ADMIN_JWT" '{"name":"x","game_type":"spades","format":"single_elimination","start_time":"2027-01-01T00:00:00Z"}')
check "spades rejected (no server rules)" "400" "$R"
R=$(fncode admin-create-tournament "$ADMIN_JWT" '{"name":"x","game_type":"ludo","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","team_size":2,"min_participants":4,"max_participants":8}')
check "2v2 ludo rejected" "400" "$R"
R=$(fncode admin-create-tournament "$ADMIN_JWT" '{"name":"x","game_type":"bridge","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","team_size":2,"allow_solo_pairing":true,"min_participants":4,"max_participants":8}')
check "bridge solo-pairing rejected (teams only)" "400" "$R"

echo "── 2. Team 29 tournament: create/join/solo flows ──"
T=$(fn admin-create-tournament "$ADMIN_JWT" '{"name":"Team Cup","game_type":"twenty_nine","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","team_size":2,"allow_solo_pairing":true,"min_participants":4,"max_participants":8,"entry_fee_coins":100,"prize_pool":[{"place":1,"coins":501}]}' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "  tournament: $T"
R=$(fn tournament-register "${JWT[1]}" "{\"tournament_id\":\"$T\",\"create_team\":true}")
TEAM_A=$(echo "$R" | grep -o '"team_id":"[^"]*"' | cut -d'"' -f4)
check "captain creates team" "1" "$([ -n "$TEAM_A" ] && echo 1)"
R=$(fn tournament-register "${JWT[2]}" "{\"tournament_id\":\"$T\",\"join_team\":\"$TEAM_A\"}")
check "partner joins team" "$TEAM_A" "$(echo "$R" | grep -o '"team_id":"[^"]*"' | cut -d'"' -f4)"
R=$(fncode tournament-register "${JWT[3]}" "{\"tournament_id\":\"$T\",\"join_team\":\"$TEAM_A\"}")
check "3rd joiner rejected TEAM_FULL" "409" "$R"
fn tournament-register "${JWT[3]}" "{\"tournament_id\":\"$T\"}" >/dev/null   # solo
fn tournament-register "${JWT[4]}" "{\"tournament_id\":\"$T\"}" >/dev/null   # solo
fn tournament-register "${JWT[5]}" "{\"tournament_id\":\"$T\"}" >/dev/null   # solo (odd one out)
check "5 participants registered" "5" "$(psql "select current_participants from tournaments where id='$T';")"

echo "── 3. Start via tick: solo pairing + odd-solo drop/refund ──"
psql "update tournaments set start_time = now() - interval '1 minute' where id='$T';" >/dev/null
tick
check "tournament in_progress" "in_progress" "$(psql "select status from tournaments where id='$T';")"
check "2 complete teams exist" "2" "$(psql "select count(*) from tournament_teams where tournament_id='$T';")"
check "4 active participants (odd solo dropped)" "4" "$(psql "select count(*) from tournament_participants where tournament_id='$T';")"
DROPPED=$(psql "select l.user_id from tournament_entry_ledger l where l.tournament_id='$T' and l.refunded and not exists (select 1 from tournament_participants p where p.tournament_id=l.tournament_id and p.user_id=l.user_id);")
check "odd solo dropped+refunded (back to 1000)" "1000" "$(psql "select coins from profiles where id='$DROPPED';")"
check "1 match with both teams set" "1" "$(psql "select count(*) from tournament_matches where tournament_id='$T' and team1_id is not null and team2_id is not null;")"
ROOM=$(psql "select room_id from tournament_matches where tournament_id='$T';")
check "room has 4 seats" "4" "$(psql "select count(*) from room_players where room_id='$ROOM';")"
# Seat parity: seats 0 and 2 must share a team; 1 and 3 the other.
PARITY=$(psql "select count(distinct tp.team_id) from room_players rp join tournament_participants tp on tp.user_id=rp.user_id and tp.tournament_id='$T' where rp.room_id='$ROOM' and rp.seat_index in (0,2);")
check "seats 0+2 are one team" "1" "$PARITY"
check "playerOrder has 4 players" "4" "$(psql "select jsonb_array_length(state_data->'playerOrder') from game_states where room_id='$ROOM';")"
TURN=$(psql "select state_data->>'currentPlayerId' from game_states where room_id='$ROOM';")
check "currentPlayerId is a real seated player" "1" "$(psql "select count(*) from room_players where room_id='$ROOM' and user_id='$TURN';")"

echo "── 4. Team sweep-forfeit + split payout ──"
# Balances before completion for the four players
for i in 1 2 3 4 5; do CB[$i]=$(psql "select coins from profiles where id='${ID[$i]}';"); done
psql "alter table game_states disable trigger game_states_updated_at;
update game_states set updated_at = now() - interval '11 minutes' where room_id='$ROOM';
alter table game_states enable trigger game_states_updated_at;" >/dev/null
tick
check "match completed" "completed" "$(psql "select status from tournament_matches where tournament_id='$T';")"
check "tournament completed" "completed" "$(psql "select status from tournaments where id='$T';")"
check "winner is a captain" "1" "$(psql "select count(*) from tournament_teams where tournament_id='$T' and captain_id=(select winner_id from tournaments where id='$T');")"
check "2 winner-status participants (whole team)" "2" "$(psql "select count(*) from tournament_participants where tournament_id='$T' and status='winner';")"
# Split payout: prize 501 → pool = 4×100 entries, rake 12.5% → net 350 → clamp scale 350/501 → 349? compute:
# grossCoins=400, netCoins=floor(400*0.875)=350, prize=floor(501*(350/501))=350. Split: captain 175, partner 175.
WTEAM=$(psql "select team_id from tournament_participants where tournament_id='$T' and user_id=(select winner_id from tournaments where id='$T');")
WCAP=$(psql "select captain_id from tournament_teams where id='$WTEAM';")
WPART=$(psql "select user_id from tournament_participants where team_id='$WTEAM' and user_id != '$WCAP';")
CAP_IDX=""; PART_IDX=""
for i in 1 2 3 4 5; do
  [[ "${ID[$i]}" == "$WCAP" ]] && CAP_IDX=$i
  [[ "${ID[$i]}" == "$WPART" ]] && PART_IDX=$i
done
CAP_GAIN=$(( $(psql "select coins from profiles where id='$WCAP';") - CB[$CAP_IDX] ))
PART_GAIN=$(( $(psql "select coins from profiles where id='$WPART';") - CB[$PART_IDX] ))
echo "  winner captain gain=$CAP_GAIN, partner gain=$PART_GAIN"
check "prize split sums to clamped pool (350)" "350" "$((CAP_GAIN + PART_GAIN))"
check "split is equal ±remainder" "1" "$([ $((CAP_GAIN - PART_GAIN)) -le 1 ] && [ $((CAP_GAIN - PART_GAIN)) -ge 0 ] && echo 1)"
check "single payout row (captain, full amount)" "1" "$(psql "select count(*) from tournament_payouts where tournament_id='$T' and user_id='$WCAP' and coins=350;")"

echo "── 5. Teams-only + unregister cleanup ──"
T2=$(fn admin-create-tournament "$ADMIN_JWT" '{"name":"Bridge Cup","game_type":"bridge","format":"single_elimination","start_time":"2027-01-01T00:00:00Z","team_size":2,"min_participants":4,"max_participants":8}' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
R=$(fncode tournament-register "${JWT[1]}" "{\"tournament_id\":\"$T2\"}")
check "solo into teams-only rejected TEAM_REQUIRED" "400" "$R"
R=$(fn tournament-register "${JWT[1]}" "{\"tournament_id\":\"$T2\",\"create_team\":true}")
TEAM_B=$(echo "$R" | grep -o '"team_id":"[^"]*"' | cut -d'"' -f4)
fn tournament-register "${JWT[2]}" "{\"tournament_id\":\"$T2\",\"join_team\":\"$TEAM_B\"}" >/dev/null
fn tournament-unregister "${JWT[1]}" "{\"tournament_id\":\"$T2\"}" >/dev/null
check "captain left → partner promoted to captain" "${ID[2]}" "$(psql "select captain_id from tournament_teams where id='$TEAM_B';")"
fn tournament-unregister "${JWT[2]}" "{\"tournament_id\":\"$T2\"}" >/dev/null
check "last member left → team deleted" "0" "$(psql "select count(*) from tournament_teams where id='$TEAM_B';")"

echo; echo "PASS=$pass FAIL=$fail"; [[ $fail -eq 0 ]] && echo "ALL GREEN"