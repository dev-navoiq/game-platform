# Game Platform - Master Build Prompt

> **Purpose**: This is the master orchestration prompt for building a complete multiplayer game platform supporting card games (Twenty-Nine, Oh Hell, Bridge, Hearts, Spades, Rummy) and board games (Chess, Ludo, Sequence). Feed these prompts to Claude Code in sequence.

## Project Vision

A modern, multiplayer game platform with:
- **Glass morphism UI** with blur effects, transparency, and subtle gradients
- **Real-time multiplayer** via Supabase Realtime
- **Hot-patchable rules** via Shorebird + server-side configs
- **Rich animations** for immersive gameplay
- **Social features** including text chat, voice chat, and democratic moderation
- **Monetization** through subscriptions, cosmetics, and non-intrusive ads
- **Tournaments** with single/double elimination, round robin, and Swiss formats
- **Favorites & History** for quick access to preferred games and replay functionality
- **Cross-platform** Flutter app (iOS, Android, Web, Desktop)
- **Test-driven development** with Playwright E2E testing across 10+ device profiles

---

## Prompt Execution Order

Execute these prompts in sequence. Each builds upon the previous:

| Order | File | Description | Est. Scope |
|-------|------|-------------|------------|
| 1 | `01-project-setup.md` | Monorepo, dependencies, tooling | Foundation |
| 2 | `02-database-schema.md` | Supabase tables, RLS, migrations | Backend |
| 3 | `03-testing-strategy.md` | Testing pyramid, Playwright E2E | Testing |
| 4 | `04-game-core-package.md` | Abstract game framework | Core Package |
| 5 | `05-card-game-implementations.md` | Twenty-Nine, Oh Hell, Hearts, etc. | Game Logic |
| 6 | `06-board-game-implementations.md` | Chess, Ludo, Sequence | Game Logic |
| 7 | `07-bot-strategies.md` | AI players for all games | AI |
| 8 | `08-flutter-app-structure.md` | App shell, routing, theming | UI Foundation |
| 9 | `09-glass-ui-components.md` | Glass morphism design system | UI Components |
| 10 | `10-animation-system.md` | All gameplay animations | Animations |
| 11 | `11-game-screens.md` | Game-specific UI screens | Game UI |
| 12 | `12-social-features.md` | Chat, voice, moderation | Social |
| 13 | `13-monetization-ads.md` | Subscriptions, skins, ads | Business |
| 14 | `14-assets-skins-system.md` | Card/room skins, brand customization | Assets |
| 15 | `15-edge-functions.md` | Server-side validation, matchmaking | Backend |
| 16 | `16-shorebird-updates.md` | OTA updates, feature flags | DevOps |
| 17 | `17-favorites-and-history.md` | Favorite games, game history, replays | Features |
| 18 | `18-tournaments.md` | Tournament brackets, matchmaking | Features |

---

## Architecture Principles

### 1. Separation of Concerns
```
packages/
├── game_core/          # Abstract interfaces, no game logic
├── game_twenty_nine/   # Concrete 29 implementation
├── game_oh_hell/       # Concrete Oh Hell implementation
├── game_hearts/        # ... and so on
├── game_chess/         # Board game packages
├── bot_strategies/     # AI for all games
├── social_core/        # Chat, voice, moderation
└── monetization/       # IAP, ads, subscriptions

apps/
└── flutter_app/        # The main application
    ├── lib/
    │   ├── core/       # App-wide services, DI, config
    │   ├── features/   # Feature-based modules
    │   └── shared/     # Shared widgets, utils
    └── assets/         # Images, audio, animations
```

### 2. Server-Side Rule Authority
- Game rules are defined in packages but **configurable via server**
- `game_configs` table stores tunable parameters
- Shorebird enables hot-patching of rule logic
- Edge functions validate moves server-side (anti-cheat)

### 3. Type-Safe Generics
All game systems use generics for type safety:
```dart
abstract class GameRules<TState extends GameState, TMove extends GameMove> {
  TState applyMove(TState state, TMove move);
  List<TMove> getValidMoves(TState state, String playerId);
}
```

### 4. Real-Time First
- Supabase Realtime for game state sync
- Presence for player online status
- Optimistic UI updates with server reconciliation

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.24+ |
| State Management | Riverpod 2.5+ |
| Navigation | GoRouter 14+ |
| Backend | Supabase (Postgres + Realtime + Auth + Edge Functions) |
| OTA Updates | Shorebird |
| Animations | Rive + Flutter Animations |
| Voice Chat | LiveKit or Agora |
| Analytics | PostHog or Mixpanel |
| Crash Reporting | Sentry |
| Ads | Google AdMob (non-intrusive) |
| IAP | RevenueCat |

---

## Key Design Decisions

### Why Supabase?
- Postgres with Row-Level Security for data protection
- Realtime subscriptions for multiplayer sync
- Edge Functions for server-side validation
- Built-in auth with social providers

### Why Shorebird?
- Hot-patch game rules without app store updates
- A/B test new rule variants
- Instant bug fixes for game logic
- Feature flags for gradual rollouts

### Why Glass Morphism?
- Modern, premium feel
- Works well in both light and dark modes
- Allows game content to remain focal point
- Differentiates from traditional card game apps

---

## File Naming Conventions

```
# Dart files
snake_case.dart

# Feature structure
features/
  feature_name/
    data/           # Repositories, data sources
    domain/         # Entities, use cases (if needed)
    presentation/   # Screens, widgets, providers

# Assets
assets/
  cards/{skin_name}/     # Card face images
  boards/{game_name}/    # Board backgrounds
  rooms/{skin_name}/     # Table/room backgrounds
  audio/{game_name}/     # Game-specific sounds
  animations/            # Rive files
```

---

## Quality Standards

1. **No hardcoded strings** - Use constants or l10n
2. **No magic numbers** - Use named constants
3. **Error handling** - Always handle errors gracefully
4. **Accessibility** - Semantic labels, sufficient contrast
5. **Performance** - Lazy loading, pagination, caching
6. **Testing Pyramid**:
   - Unit tests for game logic (rules, moves, scoring)
   - Widget tests for UI components
   - Golden tests for visual regression
   - Integration tests for feature flows
   - Playwright E2E tests across 10+ device profiles

---

## Getting Started

Begin with `01-project-setup.md` to initialize the monorepo and install dependencies.

Each subsequent prompt should be executed after the previous one completes successfully. The prompts are designed to be self-contained but build upon each other.

**Important**: Do not skip prompts or execute them out of order, as later prompts depend on code generated by earlier ones.
