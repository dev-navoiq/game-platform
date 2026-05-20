# Session 7 — Flutter App Structure

## Load these files first

```
prompts/_context.md
prompts/08-flutter-app-structure.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented
**Session 4 ✅** — All 6 card-game packages implemented + stubs
**Session 5 ✅** — All 3 board-game packages implemented + tested (56 tests)
**Session 6 ✅** — `packages/bot_strategies/` with 33 tests, all green

### Current state of `apps/flutter_app/lib/`

Only **5 Dart files** exist — all stubs/placeholders:

```
lib/
├── main.dart                           # Full entry point (Sentry, Hive, Supabase init)
├── app/
│   └── app.dart                        # Placeholder — just a Scaffold with "Game Platform" text
└── core/
    ├── config/
    │   └── env_config.dart             # EnvConfig (dev/staging/prod URLs)
    ├── game_registry_init.dart         # Empty initializeGameRegistry() with TODOs
    └── services/
        └── update_service.dart         # Stub UpdateService (session 15)
```

**Nothing exists yet**: no `features/`, no `shared/`, no `core/routing/`, no `core/theme/`, no `core/di/`, no `core/utils/`.

---

## Critical fix #1: existing `app.dart` is under `app/` not at root

The prompt (08) shows `app.dart` at `lib/app.dart`, but the actual file lives at `lib/app/app.dart`. Either:
- Move it to `lib/app.dart` to match the prompt's import `import 'app.dart';` in `main.dart`
- Or update `main.dart` import to `import 'app/app.dart';`

Current `main.dart` uses: `import 'app/app.dart';` — so either approach works. **Pick one and be consistent.**

---

## Critical fix #2: existing `EnvConfig` vs prompt's `AppConfig`

The prompt defines `AppConfig` (at `lib/core/config/app_config.dart`) with `const String.fromEnvironment` compile-time config.

The existing code has `EnvConfig` (at `lib/core/config/env_config.dart`) with runtime `late` fields and a `switch` statement.

**Decision**: Keep the existing `EnvConfig` pattern — it's already wired into `main.dart`. Do NOT create a second `AppConfig` class. Instead:
- Create `lib/core/config/constants.dart` (from prompt) alongside the existing `env_config.dart`
- Add any missing feature flags to `EnvConfig` (e.g., `enableVoiceChat`, `enableAds`)
- Reference `EnvConfig` instead of `AppConfig` in all new code

---

## Critical fix #3: existing `main.dart` initialization order

The current `main.dart` already does:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `SystemChrome.setPreferredOrientations`
3. `EnvConfig.initialize(Environment.production)`
4. `Hive.initFlutter()`
5. `Supabase.initialize(...)`
6. `initializeGameRegistry()`
7. `UpdateService.instance.initialize()`
8. `SentryFlutter.init(...)` wrapping `runApp(ProviderScope(child: GamePlatformApp()))`

Do NOT duplicate or rewrite this. Add new initialization (AudioService, etc.) into the existing sequence.

---

## Critical fix #4: font family mismatch

The design system specifies **DM Serif Display** (headings) + **DM Sans** (body).
The prompt (08) uses **Poppins** (headings) + **Inter** (body) via `google_fonts`.
The current `pubspec.yaml` declares **Poppins** as a bundled font.

**Decision for this session**: Use the prompt's `google_fonts` approach (Poppins + Inter) since:
- `google_fonts` is already a dependency in `pubspec.yaml`
- The design system font swap (to DM Serif Display + DM Sans) is a session 8 concern when glass UI is built
- The typography structure from the prompt is correct — only font family names will change later

---

## Critical fix #5: `pubspec.yaml` dependencies already exist

The current `pubspec.yaml` already has all needed dependencies including:
- `flutter_riverpod`, `go_router`, `supabase_flutter`
- `google_fonts`, `flutter_svg`, `cached_network_image`, `shimmer`
- `flutter_animate`, `rive`, `lottie`
- `audioplayers`, `just_audio`, `livekit_client`
- `hive`, `hive_flutter`, `shared_preferences`
- `sentry_flutter`, `posthog_flutter`
- All local game packages + `bot_strategies`, `social_core`, `monetization`
- `mocktail`, `golden_toolkit` in dev_dependencies

Do NOT replace or rewrite `pubspec.yaml`. Only add missing packages if needed (e.g., `shorebird_code_push` if not present).

---

## Critical fix #6: `google_fonts` not in pubspec

Check if `google_fonts` is in `pubspec.yaml`. The prompt's typography code imports it:
```dart
import 'package:google_fonts/google_fonts.dart';
```
If missing, add it to dependencies.

---

## Critical fix #7: providers reference `supabaseProvider` from `core/di/providers.dart`

The prompt defines `supabaseProvider` in `core/di/providers.dart`:
```dart
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

The test stubs reference `SupabaseService` and `supabaseServiceProvider` — a wrapper class around `SupabaseClient`. The prompt does NOT define this, but **tests expect it**. You need to create both:
- `supabaseProvider` — raw `SupabaseClient` (for auth service, etc.)
- `SupabaseService` + `supabaseServiceProvider` — a wrapper with methods like `createRoom()`, `leaveRoom()`, `sendMove()`, etc.

See "What tests expect" section below.

---

## What tests already expect

Existing test files (from Session 2) import classes/providers that don't exist yet. These are the contracts you **must** implement:

### From `test/unit/providers/room_provider_test.dart`:
```dart
import 'package:flutter_app/features/lobby/providers/room_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';

// Expects:
// - supabaseServiceProvider (Provider<SupabaseService>)
// - roomProvider (AsyncNotifierProvider with .notifier)
// - SupabaseService.createRoom({required String gameType, required String socialMode}) → Future<String>
// - SupabaseService.leaveRoom({required String roomId}) → Future<void>
```

### From `test/unit/providers/game_provider_test.dart`:
```dart
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';

// Expects:
// - gameStateProvider (StateNotifierProvider or AsyncNotifier)
// - SupabaseService.subscribeToGameState({required String roomId, required Function onUpdate})
// - SupabaseService.sendMove({required String roomId, required dynamic move})
// - BidMoveDto class (or similar DTO)
```

### From `test/unit/services/chat_service_test.dart`:
```dart
import 'package:flutter_app/core/services/chat_service.dart';
import 'package:flutter_app/core/services/supabase_service.dart';

// Expects:
// - ChatService({required SupabaseService supabase})
// - ChatService.sendMessage({roomId, message, senderId}) — trims whitespace, rejects empty/too-long
// - ChatService.subscribeToMessages({roomId, onMessage})
// - SupabaseService.insertChatMessage({roomId, message, senderId})
// - SupabaseService.subscribeToRoomMessages({roomId, onMessage})
```

### From `test/unit/services/subscription_service_test.dart`:
```dart
import 'package:flutter_app/core/services/subscription_service.dart';
import 'package:flutter_app/core/models/subscription_tier.dart';

// Expects:
// - SubscriptionTier enum with .free, .pro, .max
// - SubscriptionTier.monthlyPrice (0.0, 3.99, 7.99)
// - SubscriptionTier.hasAds (true, false, false)
// - SubscriptionTier.voiceMinutes (2, null, null)
// - SubscriptionTier.monthlyCoins (200, ...)
// - SubscriptionService({required RevenueCatWrapper revenueCat})
// - RevenueCatWrapper class/interface
```

### From `test/widget/playing_card_widget_test.dart`:
```dart
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

// Expects:
// - PlayingCardWidget({suit, rank, isFaceDown, isSelected, isPlayable, onTap})
// - Key('card-selected-indicator') when isSelected
// - Opacity widget when not playable
// - Semantic label "Ace of Hearts" format
```

### From `test/widget/glass_button_test.dart`:
```dart
import 'package:flutter_app/shared/widgets/glass_button.dart';

// Expects:
// - GlassButton({label, onPressed, isLoading, icon})
// - Shows CircularProgressIndicator when isLoading
// - Hides label text when isLoading
```

---

## Additional modules from product strategy (BUILD-ORDER.md)

Beyond what's in prompt 08, Session 7 must also add these feature module **shells** (empty screens with placeholder text):

### `features/challenges/`
```
features/challenges/
├── data/
│   └── challenge_repository.dart       # Stub
└── presentation/
    ├── challenges_screen.dart          # "Daily Challenges" placeholder
    └── providers/
        └── challenge_providers.dart    # Stub provider
```

### `features/season_pass/`
```
features/season_pass/
├── data/
│   └── season_repository.dart          # Stub
└── presentation/
    ├── season_pass_screen.dart         # "Season Pass" placeholder
    └── providers/
        └── season_providers.dart       # Stub provider
```

### `features/referral/`
```
features/referral/
└── presentation/
    ├── referral_screen.dart            # "Invite Friends" placeholder
    └── providers/
        └── referral_providers.dart     # Stub provider
```

### `features/friends/`
```
features/friends/
├── data/
│   └── friends_repository.dart         # Stub
└── presentation/
    ├── friends_screen.dart             # "Friends & Activity" placeholder
    └── providers/
        └── friends_providers.dart      # Stub provider
```

### `core/services/notification_service.dart`

Notification service with 9 categories from product strategy:
```dart
enum NotificationCategory {
  gameInvite,
  turnReminder,
  friendRequest,
  challengeReady,
  seasonReward,
  dailyBonus,
  chatMessage,
  tournamentStart,
  systemAlert,
}
```

Stub implementation — full push notification wiring comes in later sessions.

---

## Routing additions

The prompt's `AppRoutes` must also include:

```dart
// Additional routes from product strategy
static const onboarding = '/onboarding';
static const challenges = '/challenges';
static const seasonPass = '/season-pass';
static const referral = '/referral';
static const friends = '/friends';
```

Add onboarding redirect logic: if user's profile has no `username` set (first-time), redirect to `/onboarding` instead of `/home`.

---

## Settings additions

`SettingsScreen` should include a `preferred_social_mode` selector (Full/Chat Only/Silent/Focus) — use `RoomSocialMode` from `game_core`.

---

## Priority order

1. **Core infrastructure** — `core/config/constants.dart`, `core/theme/` (colors, typography, app_theme), `core/utils/` (extensions, validators, formatters)
2. **DI & providers** — `core/di/providers.dart` (supabaseProvider, authStateProvider, themeModeProvider, etc.)
3. **Core services** — `core/services/auth_service.dart`, `core/services/audio_service.dart`, `core/services/supabase_service.dart`, `core/services/chat_service.dart`, `core/services/subscription_service.dart`, `core/services/notification_service.dart`
4. **Core models** — `core/models/subscription_tier.dart`, `shared/models/user_model.dart`
5. **Routing** — `core/routing/routes.dart`, `core/routing/app_router.dart` (with onboarding redirect)
6. **App widget** — Update `app/app.dart` to use GoRouter + AppTheme
7. **Feature module shells** — auth, home, lobby, game, profile, shop, leaderboard (from prompt 08) + challenges, season_pass, referral, friends (from product strategy)
8. **Shared widgets** — `shared/widgets/glass_container.dart`, `glass_button.dart`, `playing_card_widget.dart`, `loading_overlay.dart`, `error_display.dart`, `animated_button.dart`
9. **Wire up `game_registry_init.dart`** — Register all game descriptors with `GameRegistry`
10. **Tests** — Ensure existing test stubs compile (imports resolve). Run `fvm flutter analyze`.

---

## Constraints

- Use `fvm flutter` (not bare `flutter`)
- Do NOT touch `main.dart` initialization beyond adding AudioService or similar service inits
- Keep `EnvConfig` — do not rename or replace with `AppConfig`
- Feature screens are **shells only** — placeholder `Scaffold` with `AppBar` and centered text. Full UI comes in Sessions 8–10
- Shared widgets need enough implementation to satisfy the test contracts (PlayingCardWidget, GlassButton)
- Do NOT add `shorebird_code_push` import to `main.dart` if it causes compile errors (it may not be available locally). `UpdateService` already handles this.
- Provider declarations should match what tests expect (provider names, method signatures)
- Use `StateNotifierProvider` or `AsyncNotifierProvider` patterns from Riverpod 2.x
- Keep the `withOpacity` calls in theme — do NOT replace with `Color.withValues` unless the Flutter version supports it (check before changing)

---

## Verification

```bash
# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# Tests should at minimum compile (they may not all pass until services are fully wired)
cd apps/flutter_app && fvm flutter test --timeout 60s

# Game packages should still pass
cd packages/bot_strategies && fvm flutter test --timeout 60s
cd packages/game_core && fvm flutter test --timeout 60s
```

---

## File count estimate

~35–45 new files:
- ~6 core config/theme/utils files
- ~2 DI files
- ~6 service files
- ~2 model files
- ~2 routing files
- ~14 feature module shells (7 from prompt + 4 from product strategy, each with screen + provider)
- ~6 shared widget files
- 1 updated app.dart
