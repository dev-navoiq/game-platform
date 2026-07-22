import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/locale_provider.dart';
import '../core/di/providers.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class GamePlatformApp extends ConsumerStatefulWidget {
  const GamePlatformApp({super.key});

  @override
  ConsumerState<GamePlatformApp> createState() => _GamePlatformAppState();
}

class _GamePlatformAppState extends ConsumerState<GamePlatformApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Server-side data (balances, tournament lists) can change while the app
    // is backgrounded — refetch on resume so the UI never shows stale money
    // or misses newly created tournaments.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(userProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Gathr',
      debugShowCheckedModeBanner: false,

      // Routing
      routerConfig: router,

      // Localization — locale is null unless the user picked a language in
      // Settings, in which case it overrides the device locale.
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // Theming
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
