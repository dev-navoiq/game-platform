import '../config/env_config.dart';

/// Which implementation serves the app's ad slots.
///
/// - [house]: our own natively-drawn creatives (dev/staging default) — lets
///   the team see how ads sit in the real slots and how our own creatives
///   look, without touching the AdMob SDK.
/// - [google]: real AdMob (production default; test unit IDs until real
///   units exist).
/// - [mock]: silent no-op platform (always used under `flutter test`).
enum AdMode { house, google, mock }

/// Pure default-mode resolution, kept free of provider/Platform plumbing so
/// it can be unit-tested directly.
///
/// - Tests always get [AdMode.mock].
/// - Production gets [AdMode.google].
/// - Development/staging get [AdMode.house].
/// - If [environment] throws (EnvConfig not initialized, e.g. an isolated
///   widget tree), fall back to [AdMode.house] — never the real SDK.
AdMode resolveDefaultAdMode({
  required bool isTest,
  required Environment Function() environment,
}) {
  if (isTest) return AdMode.mock;
  try {
    return environment() == Environment.production
        ? AdMode.google
        : AdMode.house;
  } catch (_) {
    return AdMode.house;
  }
}
