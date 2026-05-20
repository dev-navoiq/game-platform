# Session 9 — Animation System

## Load these files first

```
prompts/_context.md
prompts/10-animation-system.md
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

### Current state of `lib/shared/`

```
lib/shared/
├── models/
│   └── user_model.dart
├── theme/
│   └── glass_tokens.dart         # NEW in Session 8 — blur, opacity, radius, animation tokens
└── widgets/
    ├── animated_button.dart       # Scale animation on tap
    ├── daily_challenge_card.dart  # Challenge progress + rewards
    ├── error_display.dart         # Error icon + message + retry
    ├── floating_chat_bubble.dart  # 4-sec auto-dismiss chat bubble (3 types)
    ├── friend_activity_card.dart  # Friend status card for home strip
    ├── glass_app_bar.dart         # Glass-morphism app bar
    ├── glass_bottom_sheet.dart    # Glass modal bottom sheet
    ├── glass_button.dart          # Glass button (filled/outlined/ghost, S/M/L)
    ├── glass_card.dart            # Glass card with hover + glow
    ├── glass_container.dart       # Base glass container with blur
    ├── glass_nav_bar.dart         # Glass bottom navigation bar
    ├── glass_text_field.dart      # Glass input field
    ├── loading_overlay.dart       # Stack-based loading overlay
    ├── playing_card_widget.dart   # Card widget (suit, rank, faceDown, etc.)
    ├── season_pass_progress_bar.dart  # XP progression bar
    └── social_mode_indicator.dart # Room mode icon + label
```

No `lib/shared/animations/` directory exists yet — this is what Session 9 creates.

---

## Critical fix #1: Flutter version compatibility

Flutter 3.24.0 is in use. This means:

- **`Color.withValues()` is NOT available** — use `withOpacity()` instead
- **`AnimatedBuilder`** — exists and works fine in 3.24
- `SweepGradient` on `BoxDecoration.gradient` — `SweepGradient` is valid on `Gradient?` so it works fine

Any code from prompt 10 that uses `withValues` must be replaced with `withOpacity`.

---

## Critical fix #2: colour alignment with project palette

The prompt (10) uses generic colours like `Colors.blue[900]`, `Colors.amber`, etc. The project uses:

- **Gold accent**: `AppColors.accent` (`#C47B2B`) — for turn indicators, active states, highlights
- **Gold glow**: `AppColors.accentGlow` (`rgba(196,123,43,0.22)`) — for glows and shadows
- **Success**: `AppColors.success` (`#27ae60`) — for winning states
- **Danger**: `AppColors.danger` (`#e74c3c`) — for hearts/diamonds suit colour reference
- **Card colours**: `AppColors.cardRed` (`#c0392b`), `AppColors.cardBlack` (`#1a1a2a`)
- **Felt**: `AppColors.feltDark` (`#122e1d`), `AppColors.feltMid` (`#1d4a2e`)
- **Glass tokens**: `GlassTokens` class in `lib/shared/theme/glass_tokens.dart`

Replace generic colours in prompt 10 with project palette colours where appropriate.

---

## Critical fix #3: animation durations alignment with _context.md

The `_context.md` design system defines these animation conventions (Section A):

| Animation | Duration | Curve |
|-----------|----------|-------|
| Card played → trick zone | 300ms | ease-out |
| Card selected in hand | 220ms | cubic-bezier(0.34,1.56,0.64,1) |
| Card entry in trick | 350ms staggered 60ms | — |
| Active player pulse dot | 1200ms | ease-in-out |
| Modal entry | 350ms | cubic-bezier(0.34,1.56,0.64,1) |
| Emoji float | 1400ms | ease |
| Toast entry | 400ms | cubic-bezier(0.34,1.56,0.64,1) |
| Floating chat bubble enter | 250ms | ease-out |
| Floating chat bubble exit | 300ms | — |

**Decision**: Where the prompt (10) and `_context.md` specify different values for the same animation, use `_context.md` values as the source of truth. The prompt 10 `AnimationDurations` class should be adjusted to match.

Specifically:
- `cardPlay` should be 300ms (not 250ms) — matches "Card played → trick zone"
- `trumpReveal` at 800ms is fine (no conflict)
- `turnIndicator` pulse should be 1200ms (not 600ms) — matches "Active player pulse dot"
- `modalSlide` should be 350ms (matches "Modal entry")
- Add custom curve constants for the design system's `cubic-bezier(0.34,1.56,0.64,1)` — this is an overshoot bounce curve

---

## Critical fix #4: `SweepGradient` on BoxDecoration

In `TurnIndicatorAnimation`, the prompt uses `SweepGradient` in a `BoxDecoration.gradient`. This is valid Flutter code since `BoxDecoration.gradient` accepts `Gradient?` and `SweepGradient extends Gradient`. However, note that it's placed on a `BoxDecoration` that also has a `Border` — these are compatible.

The issue is the `TurnIndicatorAnimation` in the prompt applies a `SweepGradient` directly on the `BoxDecoration` alongside `border: Border.all(...)`. The `border` with `Colors.transparent` is pointless — clean it up.

---

## Critical fix #5: FloatingChatBubble already exists

The `FloatingChatBubble` widget was already built in Session 8 with its full animation (scale + fade + slide). The prompt 10 asks for "floating chat bubble animations" in the `social/` directory.

**Decision**: Do NOT create a duplicate. The animations for chat bubbles are already embedded in `lib/shared/widgets/floating_chat_bubble.dart`. The animation system's `social/` directory should contain:
- `emoji_bubble_animation.dart` — for emoji reactions floating up from avatars
- `chat_message_animation.dart` — for list-based chat message entry animations
- `avatar_reaction_animation.dart` — for avatar-specific reaction effects

But NOT a separate floating chat bubble animation — reference the existing widget in comments if needed.

---

## What to build

### Directory structure (from prompt 10):

```
lib/shared/animations/
├── core/
│   ├── animation_controller_mixin.dart
│   ├── animation_constants.dart
│   └── animation_curves.dart
├── cards/
│   ├── card_deal_animation.dart
│   ├── card_play_animation.dart
│   ├── card_flip_animation.dart
│   ├── card_fan_animation.dart
│   ├── trick_collect_animation.dart
│   └── shuffle_animation.dart
├── gameplay/
│   ├── turn_indicator_animation.dart
│   ├── timer_ring_animation.dart
│   ├── bid_counter_animation.dart
│   ├── trump_reveal_animation.dart
│   └── score_update_animation.dart
├── celebrations/
│   ├── confetti_animation.dart
│   ├── fireworks_animation.dart
│   ├── trophy_animation.dart
│   └── particle_system.dart
├── social/
│   ├── emoji_bubble_animation.dart
│   ├── chat_message_animation.dart
│   └── avatar_reaction_animation.dart
└── transitions/
    ├── page_transitions.dart
    ├── modal_transitions.dart
    └── list_item_animations.dart
```

### Priority order:

1. **core/** — `animation_constants.dart` (durations aligned to _context.md), `animation_curves.dart` (including custom overshoot curve), `animation_controller_mixin.dart`
2. **cards/** — Deal, play, flip, fan, trick collect, shuffle — these are the most gameplay-critical
3. **gameplay/** — Turn indicator, timer ring, bid counter, trump reveal, score update
4. **celebrations/** — Confetti, fireworks, trophy, particle system
5. **social/** — Emoji bubble, chat message entry, avatar reaction
6. **transitions/** — Page transitions, modal transitions, list item animations

---

## Widget specs for animations NOT in prompt 10

### card_flip_animation.dart

Card flip animation (face-down to face-up):
- Duration: 400ms (from `AnimationDurations.cardFlip`)
- Uses a 3D perspective transform: first half rotates Y 0→90°, second half 90°→180° while switching face/back
- Scale bumps to 1.05 at midpoint

Props:
- `Widget front` — face-up card widget
- `Widget back` — face-down card widget
- `bool isFaceUp` — current state
- `VoidCallback? onComplete`

### card_fan_animation.dart

Animates cards fanning out in the player's hand:
- Based on `_context.md` CardFan spec: spread = min(36, 210/(n-1))px, rotation = (index - (n-1)/2) * 4.5°
- Duration: 300ms per card, staggered 60ms
- Selected card: translateY(-20px), 220ms with cubic-bezier(0.34,1.56,0.64,1)

Props:
- `int cardCount`
- `int? selectedIndex`
- `Widget Function(int index) cardBuilder`
- `ValueChanged<int>? onCardTap`

### shuffle_animation.dart

Visual shuffle effect (deck riffle):
- Duration: 800ms
- Two halves of deck interleave with slight offset + rotation
- Ends with deck stack centered

Props:
- `VoidCallback? onComplete`
- `double cardWidth` / `double cardHeight`

### timer_ring_animation.dart

Circular progress ring for turn timer (from _context.md TurnTimer spec):
- Size: 38×38px
- Track: rgba(255,255,255,0.10), strokeWidth 3
- Fill: accent colour, strokeWidth 3, strokeLinecap round
- Number: DM Serif Display 12px white centre (use Poppins since that's our heading font)
- Uses `CustomPainter` + `AnimationController`

Props:
- `int seconds` — total turn time
- `VoidCallback? onExpired`

### bid_counter_animation.dart

Animated bid number counter:
- Duration: 200ms per increment
- Scale bounce on change
- Colour transitions: neutral → success (making) → danger (busted)

Props:
- `int current` — tricks won so far
- `int bid` — bid amount
- `bool isActive`

### score_update_animation.dart

Score number change animation:
- Old score slides up + fades out
- New score slides up from below + fades in
- Duration: 400ms
- "+N" delta floats up and fades

Props:
- `int score`
- `int? delta` — optional delta to show
- `Color? color`

### fireworks_animation.dart

Burst particle effect for major wins:
- Multiple burst points
- Particles expand radially then fall with gravity
- Gold + white colour palette using `AppColors.accent` and `AppColors.accentSoft`

Props:
- `bool isPlaying`
- `int burstCount` (default: 3)
- `VoidCallback? onComplete`

### trophy_animation.dart

Trophy reveal for tournament/game wins:
- Scale from 0 → 1.2 → 1.0 (bounce)
- Gold glow pulse
- Sparkle particles around trophy
- Duration: 1200ms

Props:
- `bool isPlaying`
- `VoidCallback? onComplete`

### particle_system.dart

Reusable particle system (CustomPainter-based):
- Supports: point, confetti, spark, glow particle types
- Configurable: count, speed, gravity, lifetime, colours, emission area
- Used as foundation for confetti, fireworks, and sparkle effects

### chat_message_animation.dart

Animation for chat messages entering a list:
- Slide from bottom + fade in
- Duration: 250ms ease-out
- Stagger: 60ms between sequential messages

Props:
- `Widget child`
- `int index` — for stagger delay calculation

### avatar_reaction_animation.dart

Quick reaction animation on player avatar:
- Scale bounce (0.8 → 1.2 → 1.0)
- Optional ring pulse in reaction colour
- Duration: 600ms

Props:
- `Widget child` — the avatar widget
- `Color? reactionColor`
- `bool isReacting`

### page_transitions.dart

Custom `PageRouteBuilder` transitions:
- `GlassFadeTransition` — fade + slight scale (0.95→1), 300ms
- `SlideUpTransition` — slide from bottom, 350ms with overshoot curve
- `SharedAxisTransition` — horizontal shared axis for tab switches

### modal_transitions.dart

Custom modal entry animation:
- Scale(0.88→1) + translateY(16→0), 350ms with cubic-bezier(0.34,1.56,0.64,1)
- Matches `_context.md` modal entry spec exactly

### list_item_animations.dart

Staggered list item entry:
- Each item: fade + translateY(-12→0), 250ms
- Stagger: 60ms between items
- Used for lobby room lists, leaderboard, etc.

Props:
- `Widget child`
- `int index`
- `Duration delay` (default: 60ms per index)

---

## Existing `AnimatedButton` reference

The `animated_button.dart` in `lib/shared/widgets/` already has a basic scale animation pattern. The animation system should NOT conflict with it — they serve different purposes. `AnimatedButton` is a widget; the animation system provides composable animation components.

---

## Existing `GlassTokens` animation durations

`GlassTokens` already defines:
- `durationFast = 150ms`
- `durationMedium = 300ms`
- `durationSlow = 500ms`

The animation system's `AnimationDurations` class should be the authoritative source for gameplay-specific durations. `GlassTokens` durations are for UI widget transitions (hover, focus, etc.). No conflict — they're complementary.

---

## Do NOT do these things

- Do NOT use `Color.withValues()` — use `withOpacity()` (Flutter 3.24)
- Do NOT create a duplicate FloatingChatBubble animation — it already exists in `lib/shared/widgets/`
- Do NOT modify any existing widgets from Session 8 — just build the animation library
- Do NOT write tests unless they're trivial smoke tests for the constants files
- Do NOT wire animations into game screens yet — that happens in Session 10
- Do NOT use `DM Serif Display` font — the project uses Poppins + Inter (see Session 7 decisions)
- Do NOT import `rive` or create Rive files — Rive integration is referenced in the design system but we use pure Flutter animations for now

---

## Verification

```bash
# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# Existing tests must still pass (58/60)
cd apps/flutter_app && fvm flutter test --timeout 60s
```

---

## File count estimate

~20 files across 6 subdirectories:
- 3 core files (constants, curves, mixin)
- 6 card animation files
- 5 gameplay animation files
- 4 celebration files
- 3 social animation files
- 3 transition files
