# Multiplayer testing strategy

Manually coordinating 2–4 phones per scenario doesn't scale. We test
multiplayer at three tiers, pushing as much as possible down to the cheapest
one. Rule of thumb: **game/tournament LOGIC belongs in Tier 1; screens and
navigation in Tier 2; native-only concerns in Tier 3.**

## Tier 1 — Server harnesses (seconds, no UI) ✅ built

`supabase/tests/*.sh` — bash+curl+psql suites that simulate N players as real
API principals (fresh auth users per run) against the local stack. They cover
the entire tournament/economy lifecycle: registration + refunds, team
formation, check-in, scheduled/fill starts, **race conditions** (8 concurrent
starters), stall forfeits, payouts with rake and splits.

```bash
supabase start
bash supabase/tests/run.sh
```

CI: `.github/workflows/server-tests.yml` runs the whole set on every PR that
touches `supabase/`.

This tier is where a "4 players join, one no-shows, prize splits between the
winning pair" scenario costs ~1 second instead of 4 phones and 20 minutes.

## Tier 2 — Multi-context Playwright E2E (minutes, real UI)

The existing suite (`apps/flutter_app/e2e/playwright`) drives the Flutter
**web** build. Playwright's killer feature for multiplayer: one test opens
**N isolated browser contexts = N logged-in players** interacting through the
real backend. Pattern:

```ts
test('tournament fills → both players get Play now', async ({ browser }) => {
  // Two players, two isolated sessions
  const alice = await (await browser.newContext()).newPage();
  const bob   = await (await browser.newContext()).newPage();
  await loginAs(alice, 'tester01@gathr.test');
  await loginAs(bob,   'tester02@gathr.test');

  // Admin API creates a 2-max tournament (server harness helper style)
  const t = await adminCreateTournament({ maxParticipants: 2 });

  await registerInApp(alice, t.id);
  await registerInApp(bob, t.id);        // fills → server auto-starts

  // BOTH contexts must surface the entry point
  await expect(alice.locator('[data-testid="tournament-play-match"]')).toBeVisible({ timeout: 15_000 });
  await expect(bob.locator('[data-testid="tournament-play-match"]')).toBeVisible({ timeout: 15_000 });
});
```

A useful hybrid: only ONE real UI context, with the "other players" driven by
service-role API calls (like Tier 1 helpers). That tests *this player's UX*
of a multiplayer event without N times the flakiness.

**To activate for tournaments:** the tournament widgets need test ids exposed
to the web DOM the same way the auth screens do (widget `Key`s already exist:
`tournament-play-match`, `tournament-check-in`, `tournament-invite-friends`).
Tracked as follow-up work.

## Tier 3 — On-device recorded integration (native-only)

The self-hosted runner already records UI videos (see
`recorded-ui-pipeline-runner` memory / PR #45). Use it only for what web
can't reproduce: push-notification taps, backgrounding/stall-forfeit
behavior, TestFlight/App-Tester install flows. Same hybrid pattern: the app
under test is real; other players are API-driven.

## Seeded fixtures

Staging has 10 funded accounts, levels 1–25 (`tester01–10@gathr.test`,
password in the team notes) — enough for any bracket/seeding/pairing scenario
without account setup. Locally, harnesses mint fresh users per run.

## What "tested" means for a new multiplayer feature

1. Tier-1 harness for every server rule (happy path + the race + the refund).
2. One Tier-2 (or hybrid) test that the entry point/UX appears for all roles.
3. Tier 3 only if the feature touches push/lifecycle.
