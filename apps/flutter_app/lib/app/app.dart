import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/locale_provider.dart';
import '../core/di/monetization_providers.dart';
import '../core/di/providers.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'web_payment_handler.dart' if (dart.library.io) 'web_payment_handler_stub.dart';

class GamePlatformApp extends ConsumerStatefulWidget {
  const GamePlatformApp({super.key});

  @override
  ConsumerState<GamePlatformApp> createState() => _GamePlatformAppState();
}

class _GamePlatformAppState extends ConsumerState<GamePlatformApp>
    with WidgetsBindingObserver {
  StreamSubscription<List<Map<String, dynamic>>>? _profileSub;
  String? _profileSubUserId;
  String? _revenueCatUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Money can move server-side with no user action (prizes, auto-cancel
    // refunds) — without a live signal the wallet showed stale numbers until
    // resume (#177). Follow the user's own profiles row and refetch on change.
    ref.listenManual(currentUserProvider, (_, __) {
      _syncProfileSubscription();
      _syncRevenueCatIdentity();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncProfileSubscription();
        _syncRevenueCatIdentity();
        _handleStripeReturnIfNeeded();
      }
    });
  }

  /// Keep the RevenueCat app-user id equal to the Supabase user id so store
  /// purchases and webhooks are attributed to the right profile row.
  void _syncRevenueCatIdentity() {
    if (kIsWeb) return;
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == _revenueCatUserId) return;
    _revenueCatUserId = uid;
    final revenueCat = ref.read(revenueCatProvider);
    unawaited(() async {
      try {
        if (uid == null) {
          await revenueCat.logOut();
        } else {
          await revenueCat.logIn(uid);
        }
      } catch (e) {
        debugPrint('RevenueCat identity sync failed (non-fatal): $e');
      }
    }());
  }

  /// Check for Stripe payment return parameters and verify the purchase.
  void _handleStripeReturnIfNeeded() {
    if (!hasStripeReturnParams()) return;
    // Delay slightly to ensure the scaffold is available for snackbars
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        handleStripeReturn(ref, context);
      }
    });
  }

  void _syncProfileSubscription() {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == _profileSubUserId) return;
    _profileSub?.cancel();
    _profileSub = null;
    _profileSubUserId = uid;
    if (uid == null) return;
    var first = true;
    _profileSub = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .listen((rows) {
      // The stream replays the current row on subscribe — only changes after
      // that mean the balance actually moved.
      if (first) {
        first = false;
        return;
      }
      ref.invalidate(userProfileProvider);
    }, onError: (_) {
      // Realtime hiccup — resume/actions still refresh; drop silently.
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
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
