# Server-side multiplayer harnesses

Bash + curl + psql assertion suites that simulate **N players via real API
calls** against the local Supabase stack — registration, team formation,
check-in, tournament starts (including race conditions), stall forfeits,
payouts, refunds. This is the fast tier of the multiplayer testing strategy
(see `docs/TESTING-STRATEGY.md`): no devices, no emulators, seconds per run.

| Harness | Covers |
|---|---|
| `tick_test.sh` | Scheduled starts, under-min auto-cancel, stall sweep (on-turn forfeit → completion), idempotency, pg_cron→pg_net plumbing |
| `team_test.sh` | 2v2: game allow-list, create/join team, TEAM_FULL race, solo pairing, odd-solo refund, 4p seat parity, team forfeit, split payouts, captain promotion |
| `race_test.sh` | 8 concurrent ticks → exactly one start, one room per match, exact seat counts, zero orphans |
| `checkin_test.sh` | §T6: no fill-start with check-in, window gating, announce once-flag, no-show drop+refund, bye bracket for odd rosters |

## Running

```bash
supabase start                 # migrations auto-applied
bash supabase/tests/run.sh     # all suites
bash supabase/tests/team_test.sh   # one suite
```

One-time local seed (admin account used by the harnesses):

```bash
# create admin@gathr.local / admin1234 via auth admin API, then:
docker exec supabase_db_game-platform psql -U postgres -d postgres -c \
  "insert into admin_users(user_id) select id from auth.users where email='admin@gathr.local' on conflict do nothing;"
```

## Conventions

- Keys in these files are the **public local-dev demo keys** shipped by the
  Supabase CLI — same on every machine, safe to commit, useless remotely.
- Each run creates fresh users (`*_<nanos>@t.local`) — re-runs never collide.
- Time travel via `psql update ... start_time/updated_at` (note:
  `game_states.updated_at` needs its trigger disabled around a backdate).
- Keep new harnesses self-contained (copy the helper block) so each file runs
  standalone.
