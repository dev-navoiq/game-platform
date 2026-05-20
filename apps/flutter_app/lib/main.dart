import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
export 'app/app.dart' show GamePlatformApp;
import 'core/config/env_config.dart';
import 'core/game_registry_init.dart';
import 'core/services/config_sync_service.dart';
import 'core/services/feature_flags.dart';
import 'core/services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SystemChrome is not supported on web
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Select env at build time via --dart-define=ENV=staging|production.
  // Defaults to development for `flutter run` without flags.
  const envName = String.fromEnvironment('ENV', defaultValue: 'development');
  final env = Environment.values.firstWhere(
    (e) => e.name == envName,
    orElse: () => Environment.development,
  );
  EnvConfig.initialize(env);

  // Supabase init must complete before runApp — the client is required for
  // auth and any first-frame screen that queries the DB. Bounded so an
  // unreachable backend can't pin the splash screen for the full TCP timeout.
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Supabase.initialize timed out or failed: $e');
  }

  initializeGameRegistry();

  // Feature flags + config sync + OTA check are non-blocking — they cache
  // locally and fall back to defaults if the network is down. Kicking them
  // off after runApp lets the UI render immediately on a cold start.
  unawaited(_initializeBackgroundServices());

  final sentryDsn = EnvConfig.sentryDsn;
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = EnvConfig.environment.name;
      },
      appRunner: () => runApp(
        const ProviderScope(
          child: GamePlatformApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: GamePlatformApp(),
      ),
    );
  }
}

Future<void> _initializeBackgroundServices() async {
  try {
    final client = Supabase.instance.client;
    await FeatureFlags.instance
        .initialize(supabase: client, userId: client.auth.currentUser?.id)
        .timeout(const Duration(seconds: 5));
    await ConfigSyncService.instance
        .initialize(client)
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Background services init failed (non-fatal): $e');
  }
  try {
    await UpdateService.instance.initialize();
  } catch (e) {
    debugPrint('UpdateService init failed (non-fatal): $e');
  }
}
