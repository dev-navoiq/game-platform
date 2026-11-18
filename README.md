# Gathr — multiplayer card and board games for family game night

Flutter + Supabase multiplayer game platform, built solo as an evenings project. Nine games, bots at
four difficulty levels for offline play, real-time multiplayer rooms, tournaments, a coin and gem
economy, subscriptions and an operator console. **Status: pre-launch (TestFlight); not yet in the
App Store or Play Store.**

## What's here

A [Melos](https://melos.invertase.dev) monorepo:

| Area | Packages |
|---|---|
| Games | `game_bridge`, `game_chess`, `game_hearts`, `game_ludo`, `game_oh_hell`, `game_rummy`, `game_sequence`, `game_spades`, `game_twenty_nine` |
| Framework | `game_core` — abstract game interfaces, state machines, type-safe generics shared by every game |
| Bots | `bot_strategies` — easy / medium / hard / expert AI players, fully client-side so offline play works |
| Platform | `monetization` (IAP, Free/Pro/Max tiers, coins, ads, season pass), `social_core` (chat, voice, moderation, friends) |
| Apps | `apps/flutter_app` — the player app (iOS, Android, web); `apps/admin_web` — operator console for tournaments, economy, seasons and promotions |
| Backend | `supabase/` — Postgres schema and RLS migrations, 30 edge functions (matchmaking, rooms, tournaments, economy, Stripe and RevenueCat webhooks), tests |

## Design principle

The client is an untrusted display layer. Everything that affects money, rank, identity, entitlement
or hidden game information is written and validated server-side (edge functions and `SECURITY
DEFINER` RPCs), never by a client-role write. See [`SECURITY-GUIDELINES.md`](SECURITY-GUIDELINES.md).

[`SECURITY-AUDIT.md`](SECURITY-AUDIT.md) is a full threat model and code audit of the platform
(July 2026) with every finding tied to a file and line. It is published deliberately: the audit found
that early RLS policies gated row ownership but not column mutability, which is the kind of mistake
worth showing rather than hiding. Remediation is tracked in the issues; the
`20260708_security_hardening` migration closes the first set.

## Run it

```bash
dart pub global activate melos
melos bootstrap
supabase start                      # local Postgres + edge functions
cd apps/flutter_app && flutter run --dart-define=ENV=development
```

Deployment to staging and production: [`DEPLOYMENT.md`](DEPLOYMENT.md).

## Author

Ambar Anant — [github.com/ambartyagi](https://github.com/ambartyagi) · [LinkedIn](https://www.linkedin.com/in/ambar-anant-12b27a14)
