# Card Stack & Animation Polish — Implementation Plan (v1)

Source of truth for the card-stack + game-flow animation work that started 2026-06-09. All five user asks decomposed into items below. Each item ships independently; sequencing at the bottom.

## The 5 user asks (verbatim)
1. When choosing a card to move it should float up or get bigger, then on slide motion or double click it will fly towards dealing area
2. When others move, their cards should fly from their seats
3. After each hand, all cards should fly towards the player that has won and an animation should show who won
4. After the complete round is over, the individual/team that won should show animation like jumping; losing teams/individual should show sad emotions. Scoreboard should be tappable but not a blocking splash
5. Next round timer (30s) on the main screen, or each human gets a "Ready" button; all ready → next round

User guardrail: bot-only rooms must NOT auto-advance rounds. Next round won't start if no humans are connected.

---

## Item 1 — Card pickup polish
**Files**: [card_fan_animation.dart](apps/flutter_app/lib/shared/animations/cards/card_fan_animation.dart), [card_hand.dart](apps/flutter_app/lib/features/game/presentation/widgets/card_hand.dart)

- `_selectAnimation`: lift 20px → **28px** + scale 1.0 → **1.10**
- Two alternate commit gestures on the selected card alongside the existing second-tap:
  - **Vertical swipe up >40px** → commit
  - **Double-tap** → commit
- Selection: light haptic (existing). Commit: medium haptic.
- Bundles a 10-min sanity pass on prior tweaks:
  - Verify each game screen passes `flightTargetKey` and `onIllegalTap` to CardHand
  - Verify the bidding-phase gold pulse exists for Bridge + 29

## Item 2 — Opponent cards fly from seats
**Files**: [seat_layout.dart](apps/flutter_app/lib/features/game/presentation/widgets/seat_layout.dart), [player_node.dart](apps/flutter_app/lib/features/game/presentation/widgets/player_node.dart), [trick_zone.dart](apps/flutter_app/lib/features/game/presentation/widgets/trick_zone.dart), each `*_game_screen.dart`

- Thread `Map<String playerId, GlobalKey> seatKeys` screen → PlayerNode → TrickZone
- TrickZone watches `currentTrick.length`. New non-local entry → OverlayEntry flight from seat rect → trick slot (~320ms easeOutCubic). Then drops into existing AnimatedPositioned slot.
- Local-player flight unchanged.

## Item 3 — Trick collection to winner
**Files**: [trick_zone.dart](apps/flutter_app/lib/features/game/presentation/widgets/trick_zone.dart), [player_node.dart](apps/flutter_app/lib/features/game/presentation/widgets/player_node.dart), [trick_collect_animation.dart](apps/flutter_app/lib/shared/animations/cards/trick_collect_animation.dart) (orphaned, wire it)

- Driver: `lastTrickWinnerId` change in TrickZone
- Replace 5s hold + text banner with: 600ms gold-ring pulse on winner's PlayerNode + 700ms gather → fly → fade (~1.3s total)
- Per-game tunable hold: Bridge ~2s, 29/Oh Hell ~1.3s

## Item 4 — Non-blocking round-end celebration
**Files**:
- New: `lib/shared/animations/celebrations/winner_jump_animation.dart`, `loser_sad_animation.dart`
- New: `lib/features/game/presentation/widgets/round_end_ribbon.dart`, `round_end_celebration_layer.dart`
- Refactor: [round_end_overlay.dart](apps/flutter_app/lib/features/game/presentation/widgets/round_end_overlay.dart), [oh_hell_round_end_overlay.dart](apps/flutter_app/lib/features/game/presentation/widgets/oh_hell_round_end_overlay.dart), [bridge_round_end_overlay.dart](apps/flutter_app/lib/features/game/presentation/widgets/bridge_round_end_overlay.dart) — extract score tables into reusable bodies
- Each `*_game_screen.dart` swaps modal for celebration layer + ribbon

**Spec**:
- Celebration layer (over the table, NOT modal):
  - Winner seat(s): jump animation (3 bounces, easeOutBack, ~900ms)
  - Loser seat(s): light shake ±5° + downward droop; optional 💧 emote
  - Confetti above winners (re-use existing). Trophy above winners (re-use orphaned widget)
- Glass ribbon at top: `"Round won by Team A — +50 pts • Tap for scoreboard"`. Tap → GlassBottomSheet with refactored score table
- **Bots get the same animations on all outcomes** (winning, losing, or as disconnect-substitutes)

## Item 5a — Ready ribbon UI
**Coordination**: Option A — Supabase broadcast on `room:<id>:ready`

Same ribbon as Item 4. Adds:
- 30s countdown derived from `round_ended_at` timestamp in game state
- Per-human chip row (gold ring → green fill on ready)
- Local "I'M READY" button (only shown to local human)

Bots auto-ready instantly on entering between-rounds. Advance trigger: `humanSeats ⊆ readySet` OR countdown expired → any client fires `newRound` (idempotent on engine).

**Files**: new `between_rounds_ribbon.dart`, `ready_chip.dart`, `ready_broadcast_controller.dart`. Wires into each `*_game_screen.dart`.

## Item 5b — Disconnect → bot substitution
- **Detection**: Supabase presence on `room:<id>`. 15s default grace.
- **Substitution**: edge function `substitute-bot` flips `room_players.is_bot=true` + sets `bot_difficulty`. Seat, hand, name preserved (`"Sam (bot)"`).
- **Reconnect policy (locked)**: **Restore-on-reconnect within the same round**. Bot stops at next turn boundary; human resumes. After round boundary, reconnect rejoins normally.
- **Bot move execution**: existing [bot_move_controller.dart](apps/flutter_app/lib/features/game/providers/bot_move_controller.dart) picks up substituted seats automatically.

**Files**: new `lib/features/lobby/services/presence_service.dart`, new edge function `supabase/functions/substitute-bot/`, room schema additions.

## Item 5c — Turn timeout → auto bot move
- **Default**: 30s per turn (configurable; see migration). UI warning ramp in last 5s.
- **Enforcement (easier route, locked)**: client-side. First client to notice expiry posts `force_timeout_move`; engine validates `now > deadline + 2s grace`. Bot strategy picks the move using existing Dart [bot_strategies](packages/bot_strategies/) package (medium default). No cron safety net for v1.

**Files**: turn_timer.dart UI polish, bot_move_controller.dart timeout-handler, engine support for `force_timeout_move`.

## Item 5d — Bot-only room pause
- At round end, before firing `newRound`: if `humanSeats.where(connected).isEmpty` → **pause**. Don't fire newRound, don't start countdown. Ribbon: *"Waiting for a player… room paused"*.
- On human join/reconnect → resume with fresh 30s countdown.
- Mid-round: engine keeps running (no mid-trick pause — too invasive); pause kicks in at the next between-rounds boundary.
- Same guard prevents `force_timeout_move` on bot-only turns (bots use their own timer in bot_move_controller.dart).

---

## DB migration (single migration for 5a/5b/5c/5d)

**File**: `supabase/migrations/20260609000000_room_bot_substitution.sql`

`game_rooms` adds:
- `turn_seconds INT NOT NULL DEFAULT 30 CHECK (turn_seconds BETWEEN 10 AND 120)`
- `auto_bot_on_disconnect BOOLEAN NOT NULL DEFAULT true`
- `auto_bot_on_timeout BOOLEAN NOT NULL DEFAULT true`
- `auto_bot_difficulty bot_difficulty NOT NULL DEFAULT 'medium'`
- `disconnect_grace_seconds INT NOT NULL DEFAULT 15 CHECK (disconnect_grace_seconds BETWEEN 5 AND 60)`

`room_players` adds:
- `disconnected_at TIMESTAMPTZ NULL`
- `original_user_id UUID NULL REFERENCES profiles(id)`
- Index on `(room_id, disconnected_at)` for the disconnect sweep

`profiles` adds (user-level preferences seeded into rooms on create):
- `preferred_turn_seconds INT NOT NULL DEFAULT 30`
- `preferred_auto_bot_on_disconnect BOOLEAN NOT NULL DEFAULT true`
- `preferred_auto_bot_on_timeout BOOLEAN NOT NULL DEFAULT true`
- `preferred_auto_bot_difficulty bot_difficulty NOT NULL DEFAULT 'medium'`

---

## Create-room form coupling
Per [multiplayer-room-flow-debt.md](multiplayer-room-flow-debt.md), the create-room form is unbuilt. Item 5b's new room settings push that rebuild from "soon" to "now." A **Room Rules** section on the form will own:
- `social_mode`, `max_players`, `privacy` (existing debt)
- `turn_seconds` (new)
- `auto_bot_on_disconnect` + `auto_bot_difficulty` (new)
- `disconnect_grace_seconds` (new, advanced/collapsible)

---

## Sequencing
1. **Item 1** — pickup feel (+ prior-tweak sanity pass)
2. **Items 2 + 3** — seat keys, opponent flight, trick collection
3. **Item 4** — celebration layer + ribbon infra
4. **Migration** — single migration for all new columns
5. **Item 5a** — ready chips on the Item 4 ribbon
6. **Item 5d** — bot-only pause guard (small; piggybacks on 5a)
7. **Item 5c** — turn timeout (client-side enforcement)
8. **Create-room form rebuild** — owns 5b's settings UI + clears existing debt
9. **Item 5b** — presence + substitute-bot edge function + reconnect-restore

Rough sizing: 1≈1h · 2+3≈3h · 4≈3h · migration≈1h · 5a≈2h · 5d≈0.5h · 5c≈2.5h · create-room form≈3h · 5b≈4h. Total ~20h focused work. Break into 3–4 sessions.

---

## Parallelization notes
Items 1, 4-prep (new celebration widgets), and the migration touch non-overlapping files and can run in parallel. Items 2+3 share seat-key plumbing across game screens; should run sequentially with Item 4's eventual screen wiring to avoid merge conflicts on the same `*_game_screen.dart` files.
