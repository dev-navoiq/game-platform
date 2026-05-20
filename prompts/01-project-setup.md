# 01 - Project Setup

> Initialize the monorepo structure, dependencies, and tooling for the game platform.

## Task

Create a Flutter monorepo with Melos for the game platform with the following structure:

```
game-platform/
├── apps/
│   └── flutter_app/              # Main Flutter application
├── packages/
│   ├── game_core/                # Abstract game framework
│   ├── game_twenty_nine/         # Twenty-Nine card game
│   ├── game_oh_hell/             # Oh Hell! card game
│   ├── game_hearts/              # Hearts card game
│   ├── game_spades/              # Spades card game
│   ├── game_bridge/              # Bridge card game
│   ├── game_rummy/               # Rummy card game
│   ├── game_chess/               # Chess board game
│   ├── game_ludo/                # Ludo board game
│   ├── game_sequence/            # Sequence board game
│   ├── bot_strategies/           # AI players for all games
│   ├── social_core/              # Chat, voice, moderation
│   └── monetization/             # IAP, ads, subscriptions
├── supabase/
│   ├── migrations/               # Database migrations
│   ├── functions/                # Edge functions
│   └── config.toml               # Supabase config
├── melos.yaml                    # Monorepo config
├── pubspec.yaml                  # Root pubspec
└── docs/
    └── prompts/                  # These prompt files
```

## Melos Configuration

Create `melos.yaml`:

```yaml
name: game_platform
repository: https://github.com/yourusername/game-platform

packages:
  - apps/*
  - packages/*

command:
  bootstrap:
    usePubspecOverrides: true

scripts:
  analyze:
    run: melos exec -- flutter analyze
    description: Analyze all packages

  format:
    run: melos exec -- dart format .
    description: Format all packages

  test:
    run: melos exec -- flutter test
    description: Run tests in all packages
    packageFilters:
      dirExists: test

  build_runner:
    run: melos exec -- flutter pub run build_runner build --delete-conflicting-outputs
    description: Run build_runner in all packages
    packageFilters:
      dependsOn: build_runner

  clean:
    run: melos exec -- flutter clean
    description: Clean all packages

  get:
    run: melos exec -- flutter pub get
    description: Get dependencies for all packages
```

## Flutter App Dependencies

Create `apps/flutter_app/pubspec.yaml`:

```yaml
name: flutter_app
description: Multiplayer Game Platform
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.0

  # Backend
  supabase_flutter: ^2.5.6

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.2

  # Serialization
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  equatable: ^2.0.5

  # UI
  flutter_animate: ^4.5.0
  rive: ^0.13.4
  lottie: ^3.1.0
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0

  # Glass UI
  glassmorphism: ^3.0.0
  blur: ^3.1.0

  # Audio
  audioplayers: ^6.0.0
  just_audio: ^0.9.36

  # Voice Chat
  livekit_client: ^2.1.0
  permission_handler: ^11.3.0

  # Monetization
  purchases_flutter: ^6.25.0  # RevenueCat
  google_mobile_ads: ^5.0.0

  # Analytics & Monitoring
  sentry_flutter: ^8.2.0
  posthog_flutter: ^4.0.0

  # Utils
  uuid: ^4.3.3
  intl: ^0.19.0
  collection: ^1.18.0

  # Local packages
  game_core:
    path: ../../packages/game_core
  game_twenty_nine:
    path: ../../packages/game_twenty_nine
  game_oh_hell:
    path: ../../packages/game_oh_hell
  game_hearts:
    path: ../../packages/game_hearts
  game_spades:
    path: ../../packages/game_spades
  game_bridge:
    path: ../../packages/game_bridge
  game_rummy:
    path: ../../packages/game_rummy
  game_chess:
    path: ../../packages/game_chess
  game_ludo:
    path: ../../packages/game_ludo
  game_sequence:
    path: ../../packages/game_sequence
  bot_strategies:
    path: ../../packages/bot_strategies
  social_core:
    path: ../../packages/social_core
  monetization:
    path: ../../packages/monetization

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  riverpod_generator: ^2.4.0
  go_router_builder: ^2.4.1
  hive_generator: ^2.0.1
  mocktail: ^1.0.3
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true

  assets:
    - assets/cards/
    - assets/boards/
    - assets/rooms/
    - assets/audio/
    - assets/animations/
    - assets/icons/
    - assets/shared/

  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Regular.ttf
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fonts/Poppins-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Poppins-Bold.ttf
          weight: 700
```

## Package Template

Each game package should have this structure:

```yaml
# packages/game_xxx/pubspec.yaml
name: game_xxx
description: XXX game implementation
version: 0.1.0

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  game_core:
    path: ../game_core
  equatable: ^2.0.5
  collection: ^1.18.0
  meta: ^1.11.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.3
```

## Shorebird Setup

Create `apps/flutter_app/shorebird.yaml`:

```yaml
# Shorebird configuration
app_id: YOUR_APP_ID_HERE

# Flavors for different environments
flavors:
  development:
    app_id: YOUR_DEV_APP_ID
  staging:
    app_id: YOUR_STAGING_APP_ID
  production:
    app_id: YOUR_PROD_APP_ID
```

## Environment Configuration

Create `apps/flutter_app/lib/core/config/env_config.dart`:

```dart
enum Environment { development, staging, production }

class EnvConfig {
  static late Environment _environment;
  static late String _supabaseUrl;
  static late String _supabaseAnonKey;
  static late String _livekitUrl;
  static late String _revenueCatApiKey;
  static late String _sentryDsn;
  static late String _posthogApiKey;

  static Environment get environment => _environment;
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get livekitUrl => _livekitUrl;
  static String get revenueCatApiKey => _revenueCatApiKey;
  static String get sentryDsn => _sentryDsn;
  static String get posthogApiKey => _posthogApiKey;

  static void initialize(Environment env) {
    _environment = env;

    switch (env) {
      case Environment.development:
        _supabaseUrl = 'http://localhost:54321';
        _supabaseAnonKey = 'your-local-anon-key';
        _livekitUrl = 'ws://localhost:7880';
        _revenueCatApiKey = 'your-dev-rc-key';
        _sentryDsn = '';
        _posthogApiKey = '';
        break;
      case Environment.staging:
        _supabaseUrl = 'https://your-staging.supabase.co';
        _supabaseAnonKey = 'your-staging-anon-key';
        _livekitUrl = 'wss://your-staging.livekit.cloud';
        _revenueCatApiKey = 'your-staging-rc-key';
        _sentryDsn = 'your-staging-sentry-dsn';
        _posthogApiKey = 'your-staging-posthog-key';
        break;
      case Environment.production:
        _supabaseUrl = 'https://your-prod.supabase.co';
        _supabaseAnonKey = 'your-prod-anon-key';
        _livekitUrl = 'wss://your-prod.livekit.cloud';
        _revenueCatApiKey = 'your-prod-rc-key';
        _sentryDsn = 'your-prod-sentry-dsn';
        _posthogApiKey = 'your-prod-posthog-key';
        break;
    }
  }
}
```

## Main Entry Point

Create `apps/flutter_app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env_config.dart';
import 'core/game_registry_init.dart';
import 'core/services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize environment
  EnvConfig.initialize(Environment.production);

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize game registry
  initializeGameRegistry();

  // Initialize update service (Shorebird)
  await UpdateService.instance.initialize();

  // Initialize Sentry and run app
  await SentryFlutter.init(
    (options) {
      options.dsn = EnvConfig.sentryDsn;
      options.tracesSampleRate = 0.2;
      options.environment = EnvConfig.environment.name;
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: GamePlatformApp(),
      ),
    ),
  );
}
```

## Directory Creation Commands

Run these commands to create the directory structure:

```bash
# Create package directories
mkdir -p packages/{game_core,game_twenty_nine,game_oh_hell,game_hearts,game_spades,game_bridge,game_rummy,game_chess,game_ludo,game_sequence,bot_strategies,social_core,monetization}/lib/src

# Create app directories
mkdir -p apps/flutter_app/lib/{app,core/{config,services,di},features/{auth,home,lobby,room,game,profile,settings,shop}/presentation/{screens,widgets,providers},features/{auth,home,lobby,room,game,profile,settings,shop}/data,shared/{widgets,utils,extensions,constants}}

# Create asset directories
mkdir -p apps/flutter_app/assets/{cards/{classic,modern,minimal,neon},boards/{chess,ludo,sequence},rooms/{classic,casino,nature,space},audio/{common,twenty_nine,oh_hell,hearts,chess,ludo},animations,icons,fonts,shared}

# Create supabase directories
mkdir -p supabase/{migrations,functions/{create-room,validate-move,matchmaking,voice-token,_shared}}

# Create test directories
mkdir -p apps/flutter_app/test/{unit,widget,integration}
mkdir -p packages/{game_core,game_twenty_nine,game_oh_hell,bot_strategies}/test

# Create docs directory
mkdir -p docs/prompts
```

## Verification

After setup, verify with:

```bash
# Bootstrap all packages
melos bootstrap

# Run analysis
melos analyze

# Run tests
melos test
```

## Expected Output

- Monorepo structure with all packages initialized
- All dependencies installed
- Build configuration ready
- Environment config set up
- Entry point configured with proper initialization
