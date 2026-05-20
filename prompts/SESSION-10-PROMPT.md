# Session 10 — Game Screens + In-Game Screen

## Load these files first

```
prompts/_context.md
prompts/11-game-screens.md
prompts/19-in-game-screen.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented
**Session 4 ✅** — All 6 card-game packages implemented + stubs
**Session 5 ✅** — All 3 board-game packages implemented + tested (56 tests)
**Session 6 ✅** — `packages/bot_strategies/` with 33 tests, all green
**Session 7 ✅** — Flutter app structure: core infra, routing, services, feature shells, shared widgets. 58/60 tests pass.
**Session 8 ✅** — Glass UI component library: GlassTokens, upgraded GlassContainer/GlassButton, GlassCard, GlassTextField, GlassBottomSheet, GlassNavBar, GlassAppBar, FloatingChatBubble, SocialModeIndicator, FriendActivityCard, DailyChallengeCard, SeasonPassProgressBar. 58/60 tests pass (same 2 pre-existing failures).
**Session 9 ✅** — Animation system: 20 files in `lib/shared/animations/` (core/cards/gameplay/celebrations/social/transitions). 58/60 tests pass (same 2 pre-existing).

### Current state of `lib/features/game/`

```
lib/features/game/
├── presentation/        # (empty)
├── providers/
│   └── game_provider.dart   # GameNotifier + gameStateProvider (placeholder)
└── screens/
    └── game_screen.dart     # Placeholder: score/table/hand areas, 15s timeout
```

`game_screen.dart` currently has a skeleton layout with `Key('score-display')`, `Key('game-table')`, `Key('player-hand')` and a 15-second loading timeout. It watches `gameStateProvider` which is a `StateNotifierProvider<GameNotifier, GameState?>` — the notifier is a placeholder stub.

### Current state of `lib/shared/animations/`

```
lib/shared/animations/
├── core/
│   ├── animation_constants.dart    # AnimationDurations aligned to _context.md
│   ├── animation_curves.dart       # AnimationCurves (incl. overshootBounce)
│   └── animation_controller_mixin.dart  # GameAnimationMixin
├── cards/
│   ├── card_deal_animation.dart
│   ├── card_play_animation.dart
│   ├── card_flip_animation.dart
│   ├── card_fan_animation.dart
│   ├── trick_collect_animation.dart
│   └── shuffle_animation.dart
├── gameplay/
│   ├── turn_indicator_animation.dart   # 1200ms pulse, rotating ring
│   ├── timer_ring_animation.dart       # 38×38 CustomPainter
│   ├── bid_counter_animation.dart      # Scale bounce on change
│   ├── trump_reveal_animation.dart     # Particle burst + glow
│   └── score_update_animation.dart     # Old/new slide + delta float
├── celebrations/
│   ├── confetti_animation.dart
│   ├── fireworks_animation.dart
│   ├── trophy_animation.dart
│   └── particle_system.dart
├── social/
│   ├── emoji_bubble_animation.dart     # 1400ms float from avatar
│   ├── chat_message_animation.dart     # 250ms slide + 60ms stagger
│   └── avatar_reaction_animation.dart  # 0.8→1.2→1.0 scale bounce
└── transitions/
    ├── page_transitions.dart           # GlassFade, SlideUp, SharedAxis
    ├── modal_transitions.dart          # ModalEntryTransition
    └── list_item_animations.dart       # ListItemAnimation
```

### Current state of `lib/shared/widgets/` (relevant for games)

```
playing_card_widget.dart     # PlayingCardWidget (suit, rank, faceDown, selected, playable)
glass_container.dart         # GlassContainer (blur, border, glow, onTap)
glass_button.dart            # GlassButton (filled/outlined/ghost)
glass_app_bar.dart           # GlassAppBar
glass_bottom_sheet.dart      # GlassBottomSheet.show<T>()
floating_chat_bubble.dart    # FloatingChatBubble (text/emote/quick-phrase)
social_mode_indicator.dart   # SocialModeIndicator (imports RoomSocialMode)
```

### Key providers already defined

```dart
// core/di/providers.dart
supabaseProvider          // SupabaseClient
authStateProvider         // StreamProvider<User?>
currentUserProvider       // Provider<User?>
isLoggedInProvider        // StateProvider<bool>
soundEnabledProvider      // StateProvider<bool>

// features/game/providers/game_provider.dart
gameStateProvider         // StateNotifierProvider<GameNotifier, GameState?>
// GameNotifier.subscribeToGame(), .sendMove(), .updateState()
```

### Game state shapes (all games)

**Trick-based card games** (OhHell, TwentyNine, Hearts, Spades):
- `playerOrder: List<String>`, `dealerIndex: int`
- `hands: Map<String, Hand>`, `currentTrick: List<TrickCard>`
- `bids: Map<String, int>`, `tricksWon: Map<String, int>`
- `scores: Map<String, int>` (cumulative)

**Board games** (Chess, Ludo, Sequence):
- `playerIds: List<String>`, `currentPlayerIndex: int`
- Game-specific boards: `ChessBoard`, `SequenceBoard`, token lists
- `winnerId: String?`

**Common fields** (via abstract `GameState`):
- `phase: GamePhase`, `currentPlayerId: String?`
- `turnNumber: int`, `roundNumber: int`, `isGameOver: bool`
- `socialMode: RoomSocialMode`

### Routing (from `core/routing/app_router.dart`)

```dart
// Game route — full screen overlay (outside ShellRoute)
GoRoute(
  path: '/game/:gameId',
  builder: (context, state) => GameScreen(
    roomId: state.pathParameters['gameId'] ?? '',
  ),
),
```

### Game registry (from `core/game_registry_init.dart`)

All 9 games registered: `twenty_nine`, `oh_hell`, `hearts`, `spades`, `bridge`, `rummy`, `chess`, `ludo`, `sequence`.

---

## Critical fix #1: Do NOT duplicate existing widgets

Prompt 11 and 19 define their own versions of widgets/classes that already exist. Do NOT create duplicates:

| Prompt defines | Already exists at | Action |
|----------------|-------------------|--------|
| `AppColors` | `lib/core/theme/colors.dart` | Use existing `AppColors` |
| `GlassContainer` | `lib/shared/widgets/glass_container.dart` | Use existing (upgraded in Session 8) |
| `PlayingCardWidget` | `lib/shared/widgets/playing_card_widget.dart` | Extend/adapt, do NOT duplicate |
| `FloatingChatBubble` | `lib/shared/widgets/floating_chat_bubble.dart` | Use existing |
| `SocialModeIndicator` | `lib/shared/widgets/social_mode_indicator.dart` | Use existing |
| `TurnIndicatorAnimation` | `lib/shared/animations/gameplay/turn_indicator_animation.dart` | Wire in, do NOT rewrite |
| `TimerRingAnimation` | `lib/shared/animations/gameplay/timer_ring_animation.dart` | Wire in, do NOT rewrite |
| `BidCounterAnimation` | `lib/shared/animations/gameplay/bid_counter_animation.dart` | Wire in, do NOT rewrite |
| `ScoreUpdateAnimation` | `lib/shared/animations/gameplay/score_update_animation.dart` | Wire in, do NOT rewrite |
| `CardFanAnimation` | `lib/shared/animations/cards/card_fan_animation.dart` | Wire in, do NOT rewrite |
| `CardPlayAnimation` | `lib/shared/animations/cards/card_play_animation.dart` | Wire in, do NOT rewrite |
| `CardFlipAnimation` | `lib/shared/animations/cards/card_flip_animation.dart` | Wire in, do NOT rewrite |
| `TrickCollectAnimation` | `lib/shared/animations/cards/trick_collect_animation.dart` | Wire in, do NOT rewrite |
| `CardDealAnimation` | `lib/shared/animations/cards/card_deal_animation.dart` | Wire in, do NOT rewrite |
| `ConfettiAnimation` | `lib/shared/animations/celebrations/confetti_animation.dart` | Wire in, do NOT rewrite |
| `EmojiBubbleAnimation` | `lib/shared/animations/social/emoji_bubble_animation.dart` | Wire in, do NOT rewrite |
| `ModalEntryTransition` | `lib/shared/animations/transitions/modal_transitions.dart` | Wire in, do NOT rewrite |

If a prompt file defines a widget/class that conflicts with an existing one, **always use the existing implementation** and adapt it if needed (add missing props/methods).

---

## Critical fix #2: Flutter version compatibility

Flutter 3.24.0 is in use:

- **`Color.withValues()` is NOT available** — use `withOpacity()` instead
- **`AnimatedBuilder`** exists and works fine
- Do NOT use `DM Serif Display` font — project uses **Poppins** (headings) + **Inter** (body) via `google_fonts`

---

## Critical fix #3: Colour alignment

Replace all generic colours in prompts 11/19 with project palette:

| Prompt uses | Replace with |
|-------------|-------------|
| `Colors.blue[900]`, `Color(0xFF0D47A1)` | `AppColors.feltDark` or `AppColors.primary` |
| `Colors.amber`, generic gold | `AppColors.accent` (#C47B2B) |
| `Colors.green` | `AppColors.success` (#27ae60) |
| `Colors.red` | `AppColors.danger` (#e74c3c) |
| Card red | `AppColors.cardRed` (#c0392b) |
| Card black | `AppColors.cardBlack` (#1a1a2a) |
| Glow colours | `AppColors.accentGlow` |
| Any glass bg/border | Via `GlassTokens` (Session 8) |

---

## Critical fix #4: Provider architecture — extend, don't replace

The existing `gameStateProvider` is a `StateNotifierProvider<GameNotifier, GameState?>`. Prompt 11 proposes `gameStateStreamProvider` as a `StreamProvider.family`. **Use the existing provider pattern** — upgrade `GameNotifier` to properly parse game state from JSON, but keep the `StateNotifierProvider` shape since tests depend on it.

Specifically:

1. **Upgrade `GameNotifier`** — add JSON deserialization dispatch by game type
2. **Add `gameTypeProvider`** — `StateProvider<String?>` to track which game type is active
3. **Add `validMovesProvider`** — compute valid moves from rules + current state
4. **Add `isMyTurnProvider`** — derived from state + current user
5. **Add `selectedCardProvider`** and `selectedPositionProvider`** — for user interaction state
6. **Keep `gameStateProvider`** — existing signature, tests already use it

---

## Critical fix #5: `GameScreen` routing and game type dispatch

The current `GameScreen` takes `roomId` and shows a placeholder. It needs to become a **dispatch shell** that:

1. Loads game metadata (type, players, state) from Supabase or provider
2. Routes to the correct game-specific screen widget based on game type
3. Falls back to an "unsupported game" placeholder for Bridge and Rummy (stubs only)

```
GameScreen(roomId)
  └─ switch(gameType):
       'oh_hell'      → OhHellGameScreen(state)
       'twenty_nine'  → TwentyNineGameScreen(state)
       'hearts'       → HeartsGameScreen(state)
       'spades'       → SpadesGameScreen(state)
       'chess'        → ChessGameScreen(state)
       'ludo'         → LudoGameScreen(state)
       'sequence'     → SequenceGameScreen(state)
       else           → UnsupportedGameScreen
```

---

## Critical fix #6: Product strategy additions (from BUILD-ORDER.md)

These features from `20-product-strategy.md` must be integrated:

1. **Floating chat bubbles above player avatars** (Part 15) — use `FloatingChatBubble` widget on each `PlayerNode`, shown only in Full/Chat Only social modes
2. **Social mode enforcement** — hide chat/voice UI in Silent/Focus modes; show `SocialModeIndicator` in HUD
3. **Room social mode indicator in HUD** — small pill showing current mode
4. **Spectator view layout** — 30-sec delay for card games, cards face-down; use `isSpectator` flag

---

## What to build

### Priority 1: Game data layer + providers

```
lib/features/game/
├── data/
│   └── game_repository.dart           # NEW — Supabase game state fetch/subscribe/move
├── providers/
│   ├── game_provider.dart             # UPGRADE — JSON deserialize, game type dispatch
│   └── game_session_providers.dart    # NEW — selectedCard, selectedPosition, validMoves, isMyTurn, gameType
```

### Priority 2: Shared game widgets (used by all games)

```
lib/features/game/presentation/widgets/
├── game_table.dart              # Felt background with gradient + ambient glow
├── player_node.dart             # Floating avatar + name + bid pill + chat bubble slot
├── bid_pill.dart                # Coloured bid status chip (won/bid)
├── card_hand.dart               # Player hand area wrapping CardFanAnimation
├── trick_zone.dart              # Central card grid with avatar badges
├── score_display.dart           # Glass HUD score overlay
├── turn_timer.dart              # Wraps TimerRingAnimation for game use
├── game_hud.dart                # Top bar: game pill + round info + social mode + menu
├── game_chat.dart               # In-game chat panel (respects social mode)
├── game_actions.dart            # Action buttons (leave, settings, social)
├── game_over_dialog.dart        # End game modal with confetti
├── game_toast.dart              # Contextual toast messages
├── emoji_bar.dart               # Quick reaction emoji row
├── bidding_modal.dart           # Bid selection modal for trick games
└── trump_reveal_overlay.dart    # Wraps TrumpRevealAnimation for game use
```

### Priority 3: Game-specific screens

```
lib/features/game/presentation/screens/
├── oh_hell_game_screen.dart        # FULL — primary reference implementation
├── twenty_nine_game_screen.dart    # FULL — adds trump selection + team scores
├── hearts_game_screen.dart         # FULL — adds card passing phase + moon shooting
├── spades_game_screen.dart         # FULL — similar to Hearts with bags tracking
├── chess_game_screen.dart          # FULL — board + piece movement + promotion dialog
├── ludo_game_screen.dart           # FULL — board + dice + token movement
├── sequence_game_screen.dart       # FULL — board + card-driven chip placement
└── unsupported_game_screen.dart    # Placeholder for Bridge/Rummy
```

### Priority 4: Upgrade existing GameScreen

```
lib/features/game/screens/
└── game_screen.dart     # UPGRADE — becomes dispatch shell by game type
```

### Priority order within each game screen:

1. **Oh Hell** — implement FIRST as reference (prompt 19 is Oh Hell–specific)
2. **Twenty-Nine** — similar layout, add trump selection
3. **Hearts** — similar layout, add card passing phase
4. **Spades** — similar to Hearts
5. **Chess** — board-based, different layout
6. **Ludo** — board-based with dice
7. **Sequence** — board-based with card selection

---

## Widget specs for game-specific components

### game_table.dart — Felt background

```
Container(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: [AppColors.feltMid, AppColors.feltDark],
    ),
  ),
  child: Stack(
    children: [
      // Subtle noise texture overlay (container with low-opacity pattern)
      // Ambient gold glow at bottom
      Positioned(
        bottom: 0,
        left: 0, right: 0,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              colors: [AppColors.accentGlow, Colors.transparent],
            ),
          ),
        ),
      ),
      child,
    ],
  ),
)
```

### player_node.dart — Player avatar node

From prompt 19 spec. Each player has:
- Avatar circle (44px active, 36px inactive/side)
- Name label below (Inter 11px)
- Bid pill showing `won/bid` with colour status (neutral/success/danger)
- Turn indicator animation wrapping avatar when `isActive`
- Optional `FloatingChatBubble` positioned above
- Optional dealer badge (gold "D" icon)
- Greyed out if `hasPlayed` this trick

Props:
- `String name`, `String? avatarUrl`, `String emoji` (fallback)
- `int won`, `int bid`, `bool isActive`, `bool hasPlayed`, `bool isDealer`
- `bool isSmall` (side nodes), `bool isSpectator`
- `RoomSocialMode socialMode` (controls bubble visibility)

### game_hud.dart — Top HUD bar

Glass container at top of screen:
- Left: Game pill (game name + round info): "Oh Hell · Round 3/7"
- Center: `SocialModeIndicator` (only if not `full` mode)
- Right: Menu button (hamburger icon → settings bottom sheet)

### bidding_modal.dart — Bid selection

- Glass modal over darkened background
- Title: "Place Your Bid" (Poppins 18px)
- Round info: "X cards this round, trump: ♥"
- Number row buttons (0 to cardsThisRound)
- Forbidden bid highlighted with danger colour for dealer
- Uses `ModalEntryTransition` for entry animation
- Duration: 350ms with overshoot bounce curve

### trick_zone.dart — Central trick area

From prompt 19 spec:
- Grid layout centred on screen
- Each played card has a small avatar badge below (24px circle)
- Cards enter with `CardPlayAnimation` (300ms ease-out)
- After all cards played: `TrickCollectAnimation` gathers to winner
- Size: roughly 200×200 area for 4-player, scales for more

### chess_game_screen.dart layout

- Full-screen `GameTable` background
- `GlassAppBar` with game info
- Chess board centred (8×8 grid, alternating light/dark squares)
- Piece rendering using Unicode symbols or custom painters
- Tap-to-select → highlight valid moves → tap to move
- Promotion dialog as `GlassBottomSheet`
- Player info bars top/bottom with `TurnIndicatorAnimation`
- Captured pieces display

### ludo_game_screen.dart layout

- Full-screen `GameTable` background
- Ludo board centred (cross pattern)
- Dice area with tap-to-roll + animation
- Token pieces as coloured circles with player indicators
- Home areas (4 corners), safe squares highlighted
- Move animation for token sliding along path

### sequence_game_screen.dart layout

- Full-screen `GameTable` background
- 10×10 board grid
- Each cell shows card face or chip
- Card hand at bottom (like card games)
- Tap card → highlight valid positions → tap position to place chip
- One-eyed jack (remove) / two-eyed jack (wild) handling

---

## Player positioning system (from prompt 19)

For 3–8 players, the local player is always at the bottom. Opponents are distributed around the perimeter:

| Player count | Layout |
|-------------|--------|
| 3 | Bottom, TopLeft, TopRight |
| 4 | Bottom, Left, Top, Right |
| 5 | Bottom, BottomLeft, TopLeft, Top, TopRight, BottomRight |
| 6 | Bottom, Left, TopLeft, Top, TopRight, Right |
| 7-8 | Evenly distributed around perimeter |

Create a `SeatLayout` utility that takes `playerCount` and `localPlayerIndex` and returns positioned offsets for each seat.

---

## Social mode enforcement rules

| Mode | Chat | Voice | Emoji | Floating bubbles | Quick phrases |
|------|------|-------|-------|-----------------|---------------|
| Full | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chat Only | ✅ | ❌ | ✅ | ✅ | ✅ |
| Silent | ❌ | ❌ | ❌ | ❌ | ❌ |
| Focus | ❌ | ❌ | ✅ (limited) | ❌ | ✅ (limited) |

Use `socialMode` from `GameState` to conditionally render:
- `game_chat.dart`: hidden in Silent/Focus
- `emoji_bar.dart`: hidden in Silent, limited set in Focus
- `FloatingChatBubble`: hidden in Silent/Focus
- Voice indicator: hidden in Chat Only/Silent/Focus

---

## Spectator view

When user is spectating (not in `playerIds`):
- Card hands are face-down (30-sec delay for reveals in card games)
- No action buttons (no bidding, no card play)
- Chat visible but segregated (spectator chat separate from player chat)
- Small "Spectating" badge in HUD

---

## File structure summary

**~35 new/upgraded files:**

```
lib/features/game/
├── data/
│   └── game_repository.dart                    # NEW
├── providers/
│   ├── game_provider.dart                      # UPGRADE
│   └── game_session_providers.dart             # NEW
├── presentation/
│   ├── screens/
│   │   ├── oh_hell_game_screen.dart            # NEW (reference impl)
│   │   ├── twenty_nine_game_screen.dart        # NEW
│   │   ├── hearts_game_screen.dart             # NEW
│   │   ├── spades_game_screen.dart             # NEW
│   │   ├── chess_game_screen.dart              # NEW
│   │   ├── ludo_game_screen.dart               # NEW
│   │   ├── sequence_game_screen.dart           # NEW
│   │   └── unsupported_game_screen.dart        # NEW
│   └── widgets/
│       ├── game_table.dart                     # NEW
│       ├── player_node.dart                    # NEW
│       ├── bid_pill.dart                       # NEW
│       ├── card_hand.dart                      # NEW
│       ├── trick_zone.dart                     # NEW
│       ├── score_display.dart                  # NEW
│       ├── turn_timer.dart                     # NEW
│       ├── game_hud.dart                       # NEW
│       ├── game_chat.dart                      # NEW
│       ├── game_actions.dart                   # NEW
│       ├── game_over_dialog.dart               # NEW
│       ├── game_toast.dart                     # NEW
│       ├── emoji_bar.dart                      # NEW
│       ├── bidding_modal.dart                  # NEW
│       ├── trump_reveal_overlay.dart           # NEW
│       ├── seat_layout.dart                    # NEW (positioning utility)
│       ├── chess_board_widget.dart             # NEW
│       ├── chess_piece_widget.dart             # NEW
│       ├── ludo_board_widget.dart              # NEW
│       ├── ludo_dice_widget.dart               # NEW
│       └── sequence_board_widget.dart          # NEW
└── screens/
    └── game_screen.dart                        # UPGRADE (dispatch shell)
```

---

## Do NOT do these things

- Do NOT use `Color.withValues()` — use `withOpacity()` (Flutter 3.24)
- Do NOT create duplicate widgets for things that already exist (see Critical fix #1)
- Do NOT replace the existing `gameStateProvider` signature — upgrade it
- Do NOT modify any Session 8/9 files (glass widgets, animation files) — use them as-is
- Do NOT implement full real-time multiplayer networking — use placeholder/mock data for state
- Do NOT write Rive files — use pure Flutter animations from Session 9
- Do NOT implement voice chat UI — that's Session 11
- Do NOT build the lobby/room screens — they already exist and are Session 11+ territory
- Do NOT use `DM Serif Display` font — Poppins + Inter only
- Do NOT add dependencies to pubspec.yaml unless absolutely necessary

---

## Testing guidance

The 2 pre-existing test failures in `game_flow_test.dart` are expected to be FIXED by this session, since the `GameScreen` will now render real game UI instead of the placeholder `SizedBox`.

After building:

```bash
# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# Tests should pass — ideally 60/60 now
cd apps/flutter_app && fvm flutter test --timeout 60s
```

If the 2 game_flow tests still fail, ensure:
- `GameScreen` renders the expected keys: `Key('game-table')`, `Key('score-display')`, `Key('player-hand')`
- `GameNotifier` can be overridden in tests (via `overrideWith`)
- Bidding UI shows `Key('bid-16')` when in bidding phase (if the test expects it — check the test)

---

## Verification

```bash
# Static analysis
cd apps/flutter_app && fvm flutter analyze

# All tests (target: 60/60 — fix the 2 pre-existing failures)
cd apps/flutter_app && fvm flutter test --timeout 60s
```
