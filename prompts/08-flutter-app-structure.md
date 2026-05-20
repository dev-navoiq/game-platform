# Flutter App Structure

> **Prompt 8 of 18** | Sets up the main Flutter application with routing, theming, dependency injection, and feature modules.

## Overview

This prompt creates the Flutter application shell with proper architecture for scalability, navigation, theming, and state management using Riverpod.

---

## App Directory Structure

```
apps/flutter_app/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── app.dart                     # App widget
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart      # Environment config
│   │   │   └── constants.dart       # App constants
│   │   ├── di/
│   │   │   ├── injection.dart       # Dependency injection
│   │   │   └── providers.dart       # Global providers
│   │   ├── routing/
│   │   │   ├── app_router.dart      # GoRouter setup
│   │   │   └── routes.dart          # Route definitions
│   │   ├── theme/
│   │   │   ├── app_theme.dart       # Theme data
│   │   │   ├── colors.dart          # Color palette
│   │   │   └── typography.dart      # Text styles
│   │   ├── services/
│   │   │   ├── auth_service.dart    # Authentication
│   │   │   ├── supabase_service.dart # Database
│   │   │   ├── audio_service.dart   # Sound effects
│   │   │   └── analytics_service.dart
│   │   └── utils/
│   │       ├── extensions.dart      # Dart extensions
│   │       ├── validators.dart      # Input validation
│   │       └── formatters.dart      # Data formatting
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_repository.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       ├── register_screen.dart
│   │   │       └── providers/
│   │   │           └── auth_providers.dart
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── home_screen.dart
│   │   │       └── widgets/
│   │   │           ├── game_carousel.dart
│   │   │           └── quick_play_card.dart
│   │   ├── lobby/
│   │   │   ├── data/
│   │   │   │   └── room_repository.dart
│   │   │   └── presentation/
│   │   │       ├── lobby_screen.dart
│   │   │       ├── room_screen.dart
│   │   │       └── providers/
│   │   │           └── lobby_providers.dart
│   │   ├── game/
│   │   │   └── presentation/
│   │   │       ├── game_screen.dart
│   │   │       └── providers/
│   │   │           └── game_providers.dart
│   │   ├── profile/
│   │   │   ├── data/
│   │   │   │   └── profile_repository.dart
│   │   │   └── presentation/
│   │   │       ├── profile_screen.dart
│   │   │       └── settings_screen.dart
│   │   ├── shop/
│   │   │   └── presentation/
│   │   │       ├── shop_screen.dart
│   │   │       └── widgets/
│   │   │           ├── skin_preview.dart
│   │   │           └── purchase_button.dart
│   │   └── leaderboard/
│   │       └── presentation/
│   │           └── leaderboard_screen.dart
│   └── shared/
│       ├── widgets/
│       │   ├── glass_container.dart
│       │   ├── loading_overlay.dart
│       │   ├── error_display.dart
│       │   └── animated_button.dart
│       └── models/
│           └── user_model.dart
├── assets/
│   ├── images/
│   ├── audio/
│   ├── cards/
│   ├── boards/
│   └── animations/
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Main Entry Point

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI configuration
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Lock orientation for gameplay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Check for Shorebird updates
  await _checkForUpdates();

  // Preload audio
  await AudioService.instance.initialize();

  runApp(
    const ProviderScope(
      child: GamePlatformApp(),
    ),
  );
}

Future<void> _checkForUpdates() async {
  if (!ShorebirdCodePush().isShorebirdAvailable()) return;

  try {
    final isUpdateAvailable = await ShorebirdCodePush().isNewPatchAvailableForDownload();
    if (isUpdateAvailable) {
      await ShorebirdCodePush().downloadUpdateIfAvailable();
    }
  } catch (e) {
    debugPrint('Shorebird update check failed: $e');
  }
}
```

---

## App Widget

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/di/providers.dart';

class GamePlatformApp extends ConsumerWidget {
  const GamePlatformApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Game Platform',
      debugShowCheckedModeBanner: false,

      // Routing
      routerConfig: router,

      // Theming
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Localization (if needed)
      // localizationsDelegates: AppLocalizations.localizationsDelegates,
      // supportedLocales: AppLocalizations.supportedLocales,

      builder: (context, child) {
        return MediaQuery(
          // Prevent system text scaling from breaking UI
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
```

---

## App Configuration

```dart
// lib/core/config/app_config.dart
import 'package:flutter/foundation.dart';

enum Environment { development, staging, production }

class AppConfig {
  static Environment _environment = Environment.development;

  static void initialize(Environment env) {
    _environment = env;
  }

  static Environment get environment => _environment;

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;

  // Supabase
  static String get supabaseUrl {
    switch (_environment) {
      case Environment.development:
        return const String.fromEnvironment('SUPABASE_URL_DEV',
          defaultValue: 'https://your-project.supabase.co');
      case Environment.staging:
        return const String.fromEnvironment('SUPABASE_URL_STAGING');
      case Environment.production:
        return const String.fromEnvironment('SUPABASE_URL_PROD');
    }
  }

  static String get supabaseAnonKey {
    switch (_environment) {
      case Environment.development:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_DEV',
          defaultValue: 'your-anon-key');
      case Environment.staging:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_STAGING');
      case Environment.production:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_PROD');
    }
  }

  // Feature flags
  static bool get enableVoiceChat =>
    const bool.fromEnvironment('ENABLE_VOICE_CHAT', defaultValue: true);

  static bool get enableAds =>
    const bool.fromEnvironment('ENABLE_ADS', defaultValue: true);

  static bool get enableAnalytics =>
    !kDebugMode && const bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: true);
}
```

```dart
// lib/core/config/constants.dart
class AppConstants {
  AppConstants._();

  // Timing
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  static const Duration cardDealDelay = Duration(milliseconds: 150);

  // Sizes
  static const double borderRadius = 16.0;
  static const double cardAspectRatio = 0.7;
  static const double glassBlur = 10.0;

  // Game
  static const int maxRoomPlayers = 6;
  static const int maxChatMessages = 100;
  static const int turnTimeoutSeconds = 30;

  // Storage keys
  static const String keyThemeMode = 'theme_mode';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyMusicEnabled = 'music_enabled';
  static const String keyCardSkin = 'card_skin';
  static const String keyRoomSkin = 'room_skin';
}
```

---

## Routing

```dart
// lib/core/routing/routes.dart
class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Main
  static const home = '/home';
  static const profile = '/profile';
  static const settings = '/settings';
  static const shop = '/shop';
  static const leaderboard = '/leaderboard';
  static const favorites = '/favorites';
  static const history = '/history';

  // Lobby
  static const lobby = '/lobby/:gameType';
  static const room = '/room/:roomId';

  // Game
  static const game = '/game/:gameId';

  // Tournaments
  static const tournaments = '/tournaments';
  static const tournament = '/tournament/:tournamentId';

  // Helper methods
  static String lobbyPath(String gameType) => '/lobby/$gameType';
  static String roomPath(String roomId) => '/room/$roomId';
  static String gamePath(String gameId) => '/game/$gameId';
  static String tournamentPath(String tournamentId) => '/tournament/$tournamentId';
}
```

```dart
// lib/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lobby/presentation/lobby_screen.dart';
import '../../features/lobby/presentation/room_screen.dart';
import '../../features/game/presentation/game_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../di/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    // Refresh when auth state changes
    refreshListenable: authState,

    // Redirect logic
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
                          state.matchedLocation == AppRoutes.register;

      // Splash screen logic
      if (state.matchedLocation == AppRoutes.splash) {
        return isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      // Redirect to login if not authenticated
      if (!isLoggedIn && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Redirect to home if authenticated and trying to access auth routes
      if (isLoggedIn && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },

    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.shop,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ShopScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaderboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Game routes (full screen, no shell)
      GoRoute(
        path: AppRoutes.lobby,
        builder: (context, state) => LobbyScreen(
          gameType: state.pathParameters['gameType']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.room,
        builder: (context, state) => RoomScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.game,
        builder: (context, state) => GameScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const MainBottomNav(),
    );
  }
}

class MainBottomNav extends ConsumerWidget {
  const MainBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/shop')) currentIndex = 1;
    if (location.startsWith('/leaderboard')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0: context.go(AppRoutes.home);
          case 1: context.go(AppRoutes.shop);
          case 2: context.go(AppRoutes.leaderboard);
          case 3: context.go(AppRoutes.profile);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store),
          label: 'Shop',
        ),
        NavigationDestination(
          icon: Icon(Icons.leaderboard_outlined),
          selectedIcon: Icon(Icons.leaderboard),
          label: 'Ranks',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Unknown error'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Global Providers

```dart
// lib/core/di/providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../config/constants.dart';

// Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
});

// Current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    // Load from shared preferences
    // final prefs = await SharedPreferences.getInstance();
    // final themeName = prefs.getString(AppConstants.keyThemeMode);
    // if (themeName != null) {
    //   state = ThemeMode.values.byName(themeName);
    // }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString(AppConstants.keyThemeMode, mode.name);
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

// Sound settings
final soundEnabledProvider = StateProvider<bool>((ref) => true);
final musicEnabledProvider = StateProvider<bool>((ref) => true);

// Audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});

// Selected skins
final selectedCardSkinProvider = StateProvider<String>((ref) => 'default');
final selectedRoomSkinProvider = StateProvider<String>((ref) => 'default');

// Connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  // Monitor internet connectivity
  return Stream.value(true); // Placeholder
});
```

---

## Theme System

```dart
// lib/core/theme/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const primary = Color(0xFF6366F1);      // Indigo
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4F46E5);

  // Secondary palette
  static const secondary = Color(0xFF22D3EE);    // Cyan
  static const secondaryLight = Color(0xFF67E8F9);
  static const secondaryDark = Color(0xFF06B6D4);

  // Accent colors
  static const accent = Color(0xFFF472B6);       // Pink
  static const success = Color(0xFF10B981);      // Green
  static const warning = Color(0xFFF59E0B);      // Amber
  static const error = Color(0xFFEF4444);        // Red

  // Neutral palette (light mode)
  static const surfaceLight = Color(0xFFF8FAFC);
  static const backgroundLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1E293B);
  static const textSecondaryLight = Color(0xFF64748B);

  // Neutral palette (dark mode)
  static const surfaceDark = Color(0xFF1E1E2E);
  static const backgroundDark = Color(0xFF11111B);
  static const cardDark = Color(0xFF282839);
  static const textPrimaryDark = Color(0xFFF1F5F9);
  static const textSecondaryDark = Color(0xFF94A3B8);

  // Glass effect colors
  static const glassLight = Color(0x40FFFFFF);
  static const glassDark = Color(0x40000000);
  static const glassBorder = Color(0x20FFFFFF);

  // Game-specific colors
  static const cardRed = Color(0xFFDC2626);
  static const cardBlack = Color(0xFF1F2937);
  static const suitHearts = Color(0xFFDC2626);
  static const suitDiamonds = Color(0xFFDC2626);
  static const suitClubs = Color(0xFF1F2937);
  static const suitSpades = Color(0xFF1F2937);

  // Player colors
  static const player1 = Color(0xFFEF4444);  // Red
  static const player2 = Color(0xFF3B82F6);  // Blue
  static const player3 = Color(0xFF22C55E);  // Green
  static const player4 = Color(0xFFF59E0B);  // Yellow

  static Color playerColor(int index) {
    const colors = [player1, player2, player3, player4];
    return colors[index % colors.length];
  }
}
```

```dart
// lib/core/theme/typography.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
```

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryLight,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryLight,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primaryLight.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.textTheme.labelMedium,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryDark,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.textTheme.labelMedium,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
```

---

## Core Services

### Auth Service

```dart
// lib/core/services/auth_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    // Create profile
    if (response.user != null) {
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'username': username,
        'email': email,
      });
    }

    return response;
  }

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.gameplatform://login-callback/',
    );
  }

  Future<void> signInWithApple() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.gameplatform://login-callback/',
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}
```

### Audio Service

```dart
// lib/core/services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> initialize() async {
    await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer.stop();
    }
  }

  Future<void> playCardDeal() async {
    await _playEffect('audio/card_deal.mp3');
  }

  Future<void> playCardPlay() async {
    await _playEffect('audio/card_play.mp3');
  }

  Future<void> playTrickWin() async {
    await _playEffect('audio/trick_win.mp3');
  }

  Future<void> playGameWin() async {
    await _playEffect('audio/game_win.mp3');
  }

  Future<void> playGameLose() async {
    await _playEffect('audio/game_lose.mp3');
  }

  Future<void> playButtonClick() async {
    await _playEffect('audio/button_click.mp3');
  }

  Future<void> playNotification() async {
    await _playEffect('audio/notification.mp3');
  }

  Future<void> _playEffect(String path) async {
    if (!_soundEnabled) return;
    await _effectsPlayer.play(AssetSource(path));
  }

  Future<void> playBackgroundMusic(String path) async {
    if (!_musicEnabled) return;
    await _musicPlayer.play(AssetSource(path));
    await _musicPlayer.setVolume(0.3);
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  void dispose() {
    _effectsPlayer.dispose();
    _musicPlayer.dispose();
  }
}
```

---

## Shared Utilities

```dart
// lib/core/utils/extensions.dart
import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  Size get screenSize => MediaQuery.of(this).size;
  EdgeInsets get padding => MediaQuery.of(this).padding;
  bool get isDark => theme.brightness == Brightness.dark;
}

extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get initials {
    final words = split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${day}/${month}/${year}';
  }
}

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
```

```dart
// lib/core/utils/validators.dart
class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 20) {
      return 'Username must be less than 20 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
```

---

## pubspec.yaml

```yaml
name: flutter_app
description: Multiplayer game platform

publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Navigation
  go_router: ^14.0.0

  # Backend
  supabase_flutter: ^2.3.0

  # OTA Updates
  shorebird_code_push: ^1.1.0

  # UI
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0

  # Animations
  flutter_animate: ^4.3.0
  rive: ^0.12.0

  # Audio
  audioplayers: ^5.2.0

  # Storage
  shared_preferences: ^2.2.0
  hive_flutter: ^1.1.0

  # Utils
  uuid: ^4.2.0
  intl: ^0.19.0
  equatable: ^2.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

  # Analytics
  posthog_flutter: ^4.0.0
  sentry_flutter: ^7.14.0

  # Game packages (local)
  game_core:
    path: ../../packages/game_core
  game_twenty_nine:
    path: ../../packages/game_twenty_nine
  game_oh_hell:
    path: ../../packages/game_oh_hell
  game_chess:
    path: ../../packages/game_chess
  game_ludo:
    path: ../../packages/game_ludo
  game_sequence:
    path: ../../packages/game_sequence
  bot_strategies:
    path: ../../packages/bot_strategies

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  mocktail: ^1.0.0
  golden_toolkit: ^0.15.0

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/audio/
    - assets/cards/
    - assets/boards/
    - assets/animations/

  fonts:
    - family: GameIcons
      fonts:
        - asset: assets/fonts/game_icons.ttf
```

---

## Analysis Options

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - avoid_empty_else
    - avoid_print
    - avoid_relative_lib_imports
    - avoid_returning_null_for_future
    - avoid_slow_async_io
    - avoid_types_as_parameter_names
    - avoid_unused_constructor_parameters
    - cancel_subscriptions
    - close_sinks
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_in_for_each
    - prefer_final_locals
    - sort_constructors_first
    - sort_unnamed_constructors_first
    - unawaited_futures
    - unnecessary_await_in_return
    - use_key_in_widget_constructors
```

---

## Integration Notes

1. **Navigation**: Use `context.go()` for navigation, `context.push()` for modals
2. **State**: All state through Riverpod providers - no StatefulWidgets needed
3. **Theme**: Access via `context.theme` extension
4. **Audio**: Play sounds via `ref.read(audioServiceProvider).playCardDeal()`
5. **Auth**: Check auth state via `ref.watch(authStateProvider)`
