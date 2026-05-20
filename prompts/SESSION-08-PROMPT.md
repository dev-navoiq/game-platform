# Session 8 — Glass UI Components

## Load these files first

```
prompts/_context.md
prompts/09-glass-ui-components.md
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

### Current state of `apps/flutter_app/lib/shared/widgets/`

Six widgets already exist from Session 7:

```
lib/shared/widgets/
├── animated_button.dart         # Scale animation on tap
├── error_display.dart           # Error icon + message + retry button
├── glass_button.dart            # Basic glass button (label, onPressed, isLoading, icon)
├── glass_container.dart         # Basic ClipRRect + BackdropFilter container
├── loading_overlay.dart         # Stack-based loading overlay
└── playing_card_widget.dart     # Card widget (suit, rank, faceDown, selected, playable)
```

**Important**: `glass_button.dart` and `glass_container.dart` already exist with basic implementations. Session 8 should **upgrade them in place** to match the full spec from prompt 09 — do NOT create duplicate files. The existing `GlassButton` already satisfies its test contract (see "Existing test contracts" below).

### Current state of `lib/shared/`

```
lib/shared/
├── models/
│   └── user_model.dart
└── widgets/
    └── (6 files listed above)
```

No `lib/shared/theme/` directory exists yet — this is where `GlassTokens` should go.

---

## Critical fix #1: `GlassTokens` colour conflict with `AppColors`

The prompt (09) defines `GlassTokens` with its own colour palette (indigo accent, emerald/amber/red/blue secondary colours). However, the project's actual design system from `_context.md` uses:

| Token | Hex | Usage |
|-------|-----|-------|
| `feltDark` | `#122e1d` | Screen background base |
| `feltMid` | `#1d4a2e` | Primary surface |
| `feltLight` | `#2a6641` | Highlight areas |
| `accent` | `#C47B2B` | Gold — active states, CTAs |
| `accentSoft` | `#E8A84F` | Hover states, glow |
| `accentGlow` | `rgba(196,123,43,0.22)` | Box shadows |
| `glass` | `rgba(255,255,255,0.52)` | Glass panel backgrounds |
| `glassBorder` | `rgba(255,255,255,0.72)` | Glass panel borders |
| `textDark` | `#241810` | Text on glass surfaces |
| `textMuted` | `#9c7d62` | Secondary text on glass |

**Decision**: Use the `_context.md` colour tokens as the source of truth. `GlassTokens` should reference/align with these — keep the blur/opacity/radius/animation tokens from prompt 09, but replace the colour values with the project's actual palette. The existing `AppColors` class (at `lib/core/theme/colors.dart`) already defines `feltDark`, `accent`, `glass`, `glassBorder`, etc.

Specifically:
- `GlassTokens.accentPrimary` → use `AppColors.accent` (`#C47B2B`) instead of indigo
- `GlassTokens.lightSurface` / glass overlays → use `AppColors.glass` / `AppColors.glassBorder`
- `GlassTokens.lightText` → use `AppColors.textDark` (`#241810`)
- `GlassTokens.lightTextMuted` → use `AppColors.textMuted` (`#9c7d62`)
- Dark mode surface → use `AppColors.feltDark` (`#122e1d`)
- Success/Warning/Error colours from prompt 09 are fine to keep as supplementary

---

## Critical fix #2: existing `GlassButton` test contract must not break

The existing test at `test/widget/glass_button_test.dart` validates:

```dart
import 'package:flutter_app/shared/widgets/glass_button.dart';

// 6 tests:
// 1. GlassButton(label: 'Start Game', onPressed: null) → finds text 'Start Game'
// 2. GlassButton(label: 'Go', onPressed: callback) → tap fires callback
// 3. GlassButton(label: 'Disabled', onPressed: null) → tap doesn't throw
// 4. GlassButton(label: 'Wait', onPressed: null, isLoading: true)
//    → finds CircularProgressIndicator, text 'Wait' is NOT found
// 5. GlassButton(label: 'Play', onPressed: null, icon: Icon(Icons.play_arrow))
//    → finds Icons.play_arrow
// 6. GlassButton(label: 'Test', onPressed: null) → finds Container widgets
```

**Constructor contract** (must preserve):
```dart
const GlassButton({
  required String label,
  required VoidCallback? onPressed,
  bool isLoading = false,
  Widget? icon,  // Note: test uses Icon type but param should accept Widget
})
```

When upgrading `GlassButton` to support variants (`filled`, `outlined`, `ghost`) and sizes (`small`, `medium`, `large`) from prompt 09, these **must remain optional parameters with sensible defaults** so existing code doesn't break.

---

## Critical fix #3: existing `GlassContainer` upgrade path

The current `glass_container.dart` is a basic wrapper:

```dart
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  // ...uses ClipRRect + BackdropFilter + Container
}
```

Upgrade this in place to match the richer spec from prompt 09 (blur, surfaceColor, borderColor, gradient, shadows, glow, tap callbacks). All new parameters must be optional with defaults so existing callers (`RoomScreen`, etc.) don't break.

---

## Critical fix #4: glass morphism blur values

The prompt (09) defines:
- `blurLight = 10`, `blurMedium = 20`, `blurHeavy = 40`

The `_context.md` design system specifies:
- Glass blur: `sigmaX: 18, sigmaY: 18`

**Decision**: Use 18 as the default blur for `GlassContainer`. Keep `GlassTokens.blurLight/Medium/Heavy` for components that need different intensities, but the standard glass container should default to sigma 18 to match the design system.

---

## Critical fix #5: font family in GlassTokens

The prompt (09) doesn't specify fonts. The project uses:
- Headings: Poppins (weight 600) via `google_fonts`
- Body: Inter via `google_fonts`

The `_context.md` design system originally specifies DM Sans for labels/buttons, but Session 7 chose Poppins + Inter. Stay consistent with Session 7's decision. Glass component text should use the existing `AppTypography` from `lib/core/theme/typography.dart`.

---

## What to build

### From prompt 09 (base glass UI library):

| Widget | File | Status |
|--------|------|--------|
| `GlassTokens` | `lib/shared/theme/glass_tokens.dart` | **New** |
| `GlassContainer` | `lib/shared/widgets/glass_container.dart` | **Upgrade** existing |
| `GlassButton` | `lib/shared/widgets/glass_button.dart` | **Upgrade** existing |
| `GlassCard` | `lib/shared/widgets/glass_card.dart` | **New** |
| `GlassTextField` | `lib/shared/widgets/glass_text_field.dart` | **New** |
| `GlassBottomSheet` | `lib/shared/widgets/glass_bottom_sheet.dart` | **New** |
| `GlassNavBar` | `lib/shared/widgets/glass_nav_bar.dart` | **New** |
| `GlassAppBar` | `lib/shared/widgets/glass_app_bar.dart` | **New** |

### From BUILD-ORDER.md (5 additional product-strategy widgets):

| Widget | File | Spec Source |
|--------|------|-------------|
| `FloatingChatBubble` | `lib/shared/widgets/floating_chat_bubble.dart` | `_context.md` Part 15, lines 971–1087 |
| `SocialModeIndicator` | `lib/shared/widgets/social_mode_indicator.dart` | `_context.md` Part 14, lines 954–968 |
| `FriendActivityCard` | `lib/shared/widgets/friend_activity_card.dart` | `_context.md` Part 4, lines 673–717 |
| `DailyChallengeCard` | `lib/shared/widgets/daily_challenge_card.dart` | `_context.md` Part 7, lines 769–774 |
| `SeasonPassProgressBar` | `lib/shared/widgets/season_pass_progress_bar.dart` | `_context.md` Part 6, lines 752–765 |

---

## Widget specs for the 5 additional components

### FloatingChatBubble

Full implementation provided in `_context.md`. Key specs:
- **Max width**: 140px, truncates with "..."
- **Duration**: Auto-dismiss after 4 seconds
- **Animation in**: Scale(0.7→1) + fadeIn, 250ms ease-out
- **Animation out**: FadeOut + translateY(-8px), 300ms
- **Stacking**: Max 2 per player; oldest dismissed when 3rd arrives
- **Three types**: text (white bg), emote-only (48px emoji, no bg), quick-phrase (`accentSoft` tint)
- **Social mode integration**: Full/Chat Only = all, Silent = emote only, Focus = none
- **Tap action**: Invokes `onTap` callback (opens chat panel)
- Container padding: horizontal 10px, vertical 6px; border radius 12px
- BoxShadow: black 0.15 opacity, blurRadius 8, offset (0,3)

### SocialModeIndicator

Displays the social mode of a room with icon + label:
- 🔊 Full — `Icons.volume_up` or speaker icon
- 💬 Chat Only — `Icons.chat_bubble_outline`
- 🔇 Silent — `Icons.volume_off`
- 🎯 Focus — `Icons.center_focus_strong`

Props:
- `RoomSocialMode mode` (from `package:game_core/game_core.dart`)
- `bool showLabel` (default: true) — whether to show text label next to icon
- `double iconSize` (default: 16)

Should use `AppColors.accent` for active/selected state. Wrap in `GlassContainer` for glass effect.

### FriendActivityCard

Displays a friend's current activity:
- **States**: 🟢 In Game (Watch), 🟡 In Lobby (Join), 🔵 Online (Invite), ⚫ Offline (dimmed)
- **Layout**: Avatar/initial + name + game/status + action button
- **Card size**: ~100px wide, fits in a horizontal `ListView`

Props:
- `String displayName`
- `String? avatarUrl`
- `FriendActivityStatus status` (enum: inGame, inLobby, online, offline)
- `String? gameType` — which game they're playing (e.g., "Oh Hell", "Chess")
- `String? statusDetail` — e.g., "Round 3", "Move 12", "Waiting"
- `VoidCallback? onAction` — tap handler for Watch/Join/Invite button
- `String? roomId` — for join/watch actions

Uses `GlassCard` as base. Dimmed opacity (0.5) for offline state.

### DailyChallengeCard

Displays a single daily/weekly challenge:
- **Layout**: Title + description + progress bar + reward display
- **States**: active (in progress), completed (checkmark), expired (greyed out)

Props:
- `String title` — e.g., "Win 2 games"
- `int current` — current progress count
- `int target` — target count
- `int rewardCoins` — coin reward amount
- `int? rewardGems` — optional gem reward
- `bool isCompleted`
- `VoidCallback? onReroll` — re-roll button callback (null = no re-roll available)
- `int? rerollCost` — cost in coins to re-roll

Progress bar uses `AppColors.accent` fill. Completed state shows `Icons.check_circle` in `AppColors.success` (or `#27ae60`). Uses `GlassCard` as base.

### SeasonPassProgressBar

Displays season pass level progression:
- **Layout**: Horizontal progress bar with level markers
- **Dual track**: Free track rewards (top) + Premium track rewards (bottom)

Props:
- `int currentLevel`
- `int currentXp` — XP within current level
- `int xpToNextLevel` — XP required to reach next level
- `bool isPremium` — whether user has premium pass
- `int maxLevel` (default: 50)

Progress bar uses `AppColors.accent` fill. Premium track visually distinguished with gold accent border. Current level marker is highlighted. Uses `GlassContainer` as base.

---

## Existing `AppColors` reference

The existing `lib/core/theme/colors.dart` defines:

```dart
class AppColors {
  static const feltDark = Color(0xFF122e1d);
  static const feltMid = Color(0xFF1d4a2e);
  static const feltLight = Color(0xFF2a6641);
  static const accent = Color(0xFFC47B2B);
  static const accentSoft = Color(0xFFE8A84F);
  static const accentGlow = Color(0x38C47B2B); // rgba(196,123,43,0.22)
  static const glass = Color(0x85FFFFFF);       // rgba(255,255,255,0.52)
  static const glassBorder = Color(0xB8FFFFFF); // rgba(255,255,255,0.72)
  static const textDark = Color(0xFF241810);
  static const textMuted = Color(0xFF9c7d62);
  static const textOnFelt = Color(0xE6FFFFFF);  // rgba(255,255,255,0.90)
  static const success = Color(0xFF27ae60);
  static const danger = Color(0xFFe74c3c);
  // ... card colours, player colours
}
```

Reference `AppColors` from glass widgets instead of duplicating colour definitions.

---

## Priority order

1. **GlassTokens** — `lib/shared/theme/glass_tokens.dart` (blur, opacity, radius, animation tokens — colours reference `AppColors`)
2. **Upgrade GlassContainer** — Add blur, surfaceColor, borderColor, gradient, glow, tap/longPress params
3. **Upgrade GlassButton** — Add variant (filled/outlined/ghost), size (small/medium/large), haptics, scale animation. Keep existing constructor contract.
4. **GlassCard** — Frosted card with title, leading/trailing, hover lift, glow animation
5. **GlassTextField** — Glass input field with focus glow, error state, prefix/suffix
6. **GlassBottomSheet** — Modal bottom sheet with glass styling, drag handle, static `.show<T>()` method
7. **GlassNavBar** — Bottom navigation with glass morphism (this may replace or augment the existing `NavigationBar` in `app_router.dart`)
8. **GlassAppBar** — Glass-styled app bar
9. **FloatingChatBubble** — Chat bubble with auto-dismiss, animation, 3 types
10. **SocialModeIndicator** — Mode icon + label
11. **FriendActivityCard** — Friend status card for home screen strip
12. **DailyChallengeCard** — Challenge progress card
13. **SeasonPassProgressBar** — XP progression bar

---

## Do NOT do these things

- Do NOT create a separate colour system that conflicts with `AppColors`
- Do NOT break the existing `GlassButton` test contract (6 tests must still pass)
- Do NOT replace the bottom `NavigationBar` in `app_router.dart` with `GlassNavBar` yet — just create the widget. Integration happens when screens are built out.
- Do NOT add `flutter_animate` animations unless it's already a dependency (check `pubspec.yaml` first — it is)
- Do NOT write tests for the new widgets unless tests already exist. Session 2 only created `glass_button_test.dart` — all other glass widgets have no pre-existing tests.
- Do NOT modify feature screens (home, lobby, game, etc.) to use the new glass widgets yet — just build the widget library. Screen integration happens in Sessions 9–10.

---

## Verification

```bash
# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# Existing tests must still pass (especially glass_button_test.dart)
cd apps/flutter_app && fvm flutter test --timeout 60s

# Quick check: the 6 existing glass_button tests
cd apps/flutter_app && fvm flutter test test/widget/glass_button_test.dart
```

---

## File count estimate

~10–13 files:
- 1 GlassTokens (new)
- 2 upgraded widgets (glass_container, glass_button)
- 4 new glass widgets (glass_card, glass_text_field, glass_bottom_sheet, glass_nav_bar, glass_app_bar)
- 5 new product-strategy widgets (floating_chat_bubble, social_mode_indicator, friend_activity_card, daily_challenge_card, season_pass_progress_bar)

All files go in `lib/shared/widgets/` except `GlassTokens` which goes in `lib/shared/theme/`.
