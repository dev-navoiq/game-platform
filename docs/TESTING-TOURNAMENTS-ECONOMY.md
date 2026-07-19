# Gathr — Tournaments & Economy Testing Guide

> For build **0.1.3+1** (staging). Android via Firebase App Distribution,
> iOS via TestFlight. Everything below runs against the **staging** backend —
> coins/gems here are test currency.

## Release notes — 0.1.3+1

**Tournaments now run themselves, and partner games get real teams.**

- **NEW: Team tournaments (2v2)** for Twenty-Nine and Bridge — register with a
  partner (create/join a team) or enter solo and get auto-paired at start
  (where the tournament allows it). Prizes split between partners.
- **NEW: Automatic tournament lifecycle** — tournaments start themselves at
  their scheduled time (or instantly when the last seat fills), cancel and
  refund automatically when too few players join, and idle matches
  auto-forfeit after ~10 minutes so brackets can never get stuck.
- **NEW: Game allow-list** — only games with full server support can have
  tournaments (1v1: Twenty-Nine, Oh Hell, Ludo · 2v2: Twenty-Nine, Bridge).
- **Fixed:** 2-player Twenty-Nine matches could deal to a phantom player and
  freeze on the first move (~50% of matches). Now fixed — please re-test.
- Admin console updated: 2v2 mode + solo-pairing toggle on tournament
  creation; game list matches server support.

**You need this build** — older builds can't see the team register options.

---

## Setup

| What | Where |
|---|---|
| Android build | Firebase App Distribution invite (group: beta) |
| iOS build | TestFlight (build 0.1.3+1) |
| Admin console | https://game-platform-staging.web.app |
| Admin login | Ask Ambar (account must be on the admin allow-list) |

Two devices (or one device + one simulator) are needed for most flows; 4
accounts for team tournaments. Guest accounts are created via "Play as guest";
registered accounts via email sign-up.

---

## Part A — Coins & Gems economy

Check your balances in the Shop/wallet before and after each step.

**A1. Game-end rewards.** Play any quick game (Ludo vs a friend is fastest)
to completion. Expect: winner gets the "win" coin amount + XP, loser gets the
smaller "loss" amount. The exact numbers come from the admin console →
Economy config screen (defaults: 50/10 coins, 100/40 XP) — verify against
whatever that screen currently shows.

**A2. First-win-of-day bonus.** Your first win each day (UTC) pays an extra
bonus (default +100 coins). Win twice: the second win should NOT include the
bonus.

**A3. Daily earn cap.** The config has a daily coin cap (default 1000).
Optional long test: grind games until the cap; further wins should pay 0
coins (XP still granted).

**A4. Guest vs registered.**
- As a **guest**: you earn coins normally, but entering a tournament with a
  **gem** entry fee must be blocked with "create an account" messaging.
- Upgrade the guest to a registered account (sign up from the profile):
  balances must survive, and you receive the one-time **welcome gems**
  (default 50). Upgrading again must NOT grant them twice.

**A5. Live config change (admin).** In the admin console, change
"Coins — win" (e.g. 50 → 77), then finish a game in the app. The new value
applies immediately — no app update. Change it back after.

---

## Part B — Individual tournaments (1v1)

Create tournaments in the admin console (Tournaments → New tournament).
Only Twenty-Nine / Oh Hell / Ludo appear for 1v1 — that's intentional.

**B1. Register & withdraw.** Create a free 1v1 tournament (min 2 / max 8,
start ~1h away). Register on device A — balance unchanged (free). Withdraw —
you're removed. With an entry fee (e.g. 100 coins): register (−100), withdraw
(+100 back).

**B2. Instant start when full.** Create with **max = 2**. Register both
devices. The moment the 2nd registers, the tournament goes live: bracket
appears, the match room opens, both get a push notification.

**B3. Scheduled start.** Create with min 2 / max 8, start time ~3 minutes
out. Register 2 players, then just wait. Within ~1 minute after start time
the tournament starts by itself. (This was the "tournament never starts" bug
— it's gone.)

**B4. Auto-cancel + refund.** Create with an entry fee, min 2, start ~3
minutes out. Register only ONE player. After start time passes: tournament
flips to cancelled and the entry fee is refunded automatically.

**B5. Idle forfeit (bracket can't stick).** Start a 2-player tournament,
open the match, then simply stop playing (background the app on one device).
After ~10 minutes of no moves, the idle player forfeits: the opponent wins,
the tournament completes, prizes pay out. Nobody stays stuck.

**B6. Full bracket + prizes + rake.** 4 players, entry fee 100 coins, prize
pool 1st: 300 / 2nd: 100, single elimination. Play it out (or idle-forfeit
the slow matches). Verify: bracket advances round to round; at completion the
payouts respect the pool minus rake (payouts scale down if the prize pool
exceeds entries minus rake — exact rake % is on the Economy config screen).
Winner sees a "Champion" push.

**B7. Gem tournament (registered only).** Create with a gem entry fee.
A guest must be blocked from registering; a registered account with enough
gems can enter. Gem prizes/Gem-Cup bonuses only pay out on official
(admin-created) tournaments.

---

## Part C — Team tournaments (2v2) — NEW

Create in the admin console with **Mode: 2v2 teams**. Games: Twenty-Nine or
Bridge. Needs 4 accounts for a full run.

**C1. Create + join a team.** Player 1 registers → chooses **Create a team**.
Player 2 registers → **Join a team** → picks P1's team. Both are on one team.
A 3rd player trying to join the same team is rejected (team full).

**C2. Solo pairing.** Create a 29 tournament with **Allow solo entries** ON.
Two players register choosing **Enter solo**. At start time they're paired
into a team automatically. (Pairing balances by level: strongest solo pairs
with weakest.)

**C3. Odd solo out.** With solo pairing on, register an odd number of solos
(e.g. 1 team + 3 solos, entry fee set). At start: two solos become a team,
the leftover solo is dropped **and refunded** automatically.

**C4. Bridge is teams-only.** Creating a Bridge 2v2 in the admin console
offers no solo toggle; in the app, Bridge tournaments show no "Enter solo"
option. Registering without a team is rejected.

**C5. The match itself.** When a team match starts, the room has **4 seats
with partners sitting opposite each other** (correct for 29/Bridge). Play a
few tricks to confirm turn order alternates between teams.

**C6. Team forfeit.** During a team match, one player leaves the room (or
idles 10+ min). Their **whole team** forfeits; the opposing team advances.

**C7. Split prizes.** Complete a team tournament with a coin prize. Both
members of the winning team receive half each (odd remainder goes to the
captain). Both show "winner" status.

**C8. Withdraw mechanics.** Before start: a captain withdraws → refund + the
partner becomes captain of the (now open) team. Last member withdrawing
deletes the team.

---

## Part D — Admin console

URL: https://game-platform-staging.web.app

1. **Login gate**: a non-admin game account must NOT get past login.
2. **Economy editor**: change values, Save, refresh — values persist; app
   behavior changes immediately (see A5). Invalid input (rake 150, negative
   coins) is rejected inline.
3. **Tournament list**: force-start a tournament in registration (with ≥ min
   players); cancel one with entries — status flips + refunds land.
4. **Create form**: 2v2 mode restricts games to 29/Bridge; solo toggle
   hides for Bridge.

---

## Known limitations (don't file these)

- Spades / Hearts / Chess / Rummy / Sequence tournaments: not available yet
  (no full server rules) — they're hidden from creation on purpose.
- Free-for-all multiplayer tournaments (4-player Ludo/Hearts groups): not
  built yet — all tournament matches are 2-sided (1v1 or 2v2).
- Tournament detail screen still carries the "under construction" banner.
- Registration stays open until start even past a "registration end" time.

## Filing issues

Include: tournament ID (long ID from the URL/admin list), account emails,
device+build, what you expected vs saw, and a screenshot. Timestamps help a
lot — the server logs everything per minute.
