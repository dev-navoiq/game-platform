import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monetization/monetization.dart';

import '../../features/challenges/data/supabase_challenge_repository.dart';
import '../../features/season_pass/data/supabase_season_repository.dart';
import '../../features/shop/data/supabase_ad_repository.dart';
import '../../features/shop/data/supabase_currency_repository.dart';
import '../../features/shop/data/supabase_skin_repository.dart';
import '../config/env_config.dart';
import '../models/subscription_tier.dart' as app;
import '../services/ad_mode.dart';
import '../services/house_ads/house_ad_rotation.dart';
import '../services/mock_ad_platform.dart';
import '../services/mock_revenue_cat.dart';
import '../services/shared_prefs_game_end_ad_store.dart';
import '../services/subscription_service.dart';
import 'providers.dart';

// ── Web Payment Service ─────────────────────────────────────────────────────

/// Web payment service for Stripe checkout (web platform only).
/// Returns null on native platforms where RevenueCat is used instead.
final webPaymentServiceProvider = Provider<WebPaymentService?>((ref) {
  if (!kIsWeb) return null;
  return WebPaymentService(ref.watch(supabaseProvider));
});

// ── Repository providers ────────────────────────────────────────────────────

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  return SupabaseCurrencyRepository(ref.watch(supabaseProvider));
});

final skinRepositoryProvider = Provider<SkinRepository>((ref) {
  return SupabaseSkinRepository();
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return SupabaseChallengeRepository(ref.watch(supabaseProvider));
});

final seasonRepositoryProvider = Provider<SeasonRepository>((ref) {
  return SupabaseSeasonRepository(ref.watch(supabaseProvider));
});

final adRepositoryProvider = Provider<AdRepository>((ref) {
  return SupabaseAdRepository();
});

// ── Mock / platform providers ───────────────────────────────────────────────

/// RevenueCat wrapper — uses [MockRevenueCat] during local dev.
/// Override with a real implementation for production.
final revenueCatProvider = Provider<RevenueCatWrapper>((ref) {
  return MockRevenueCat();
});

bool get _isFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Which implementation serves the ad slots (house / google / mock).
///
/// Defaults: `mock` under `flutter test`, `google` in production, `house`
/// in development/staging (so the team sees our own creatives in the real
/// slots by default). Runtime-overridable — the `/dev/ads` gallery flips
/// this live via `ref.read(adModeProvider.notifier).state = …`.
final adModeProvider = StateProvider<AdMode>((ref) {
  return resolveDefaultAdMode(
    isTest: _isFlutterTest,
    environment: () => EnvConfig.environment,
  );
});

/// Ad platform — real Google AdMob only when [adModeProvider] is
/// [AdMode.google] on an Android/iOS device outside `flutter test`;
/// [MockAdPlatform] otherwise. In [AdMode.house] the slots are drawn
/// natively by the house-ad widgets, so no ad SDK is involved at all.
///
/// [GoogleAdPlatform] is cheap to construct: the Mobile Ads SDK is only
/// initialized lazily on the first ad load, which is itself gated on
/// [showAdsProvider] — so Pro/Max users never pay the SDK startup cost.
final adPlatformProvider = Provider<AdPlatform>((ref) {
  final mode = ref.watch(adModeProvider);
  final isMobileDevice = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (mode == AdMode.google && isMobileDevice && !_isFlutterTest) {
    final platform = GoogleAdPlatform(
      adUnitIds: GoogleAdUnitIds(
        banner: EnvConfig.admobBannerAdUnitId,
        interstitial: EnvConfig.admobInterstitialAdUnitId,
      ),
    );
    ref.onDispose(platform.dispose);
    return platform;
  }
  return MockAdPlatform();
});

/// Round-robin rotation over the house creative catalog, persisted via
/// shared_preferences so "which creative is next" survives restarts.
final houseAdRotationProvider = Provider<HouseAdRotation>((ref) {
  // shared_preferences has no host binding under `flutter test`; keep the
  // rotation in memory there so widget tests never hit the platform channel.
  return HouseAdRotation(
    _isFlutterTest
        ? InMemoryHouseAdRotationStore()
        : SharedPrefsHouseAdRotationStore(),
  );
});

/// Cadence policy for the game-end interstitial (free tier only):
/// every 2nd completed game, at least 3 minutes apart, and every 3rd
/// consumed slot serves the in-house Pro-upsell overlay instead of AdMob.
/// Counters persist across restarts via shared_preferences.
final gameEndAdCadenceProvider = Provider<GameEndInterstitialCadence>((ref) {
  return GameEndInterstitialCadence(
    SharedPrefsGameEndAdStore(),
    isFatigued: () async {
      // Reuse the AdService fatigue signal (N ad closes within the window).
      try {
        final userId = ref.read(currentUserProvider)?.id;
        if (userId == null) return false;
        final closes = await ref
            .read(adRepositoryProvider)
            .getCloseCountInWindow(userId, AdService.fatigueWindow);
        return closes >= AdService.fatigueCloseThreshold;
      } catch (_) {
        return false; // Fatigue is best-effort; fail open.
      }
    },
  );
});

/// Subscription service backed by the RevenueCat wrapper.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(revenueCat: ref.read(revenueCatProvider));
});

// ── Service providers ───────────────────────────────────────────────────────

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService(ref.read(currencyRepositoryProvider));
});

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(ref.read(adRepositoryProvider));
});

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.read(challengeRepositoryProvider));
});

final seasonServiceProvider = Provider<SeasonService>((ref) {
  return SeasonService(ref.read(seasonRepositoryProvider));
});

final skinServiceProvider = Provider<SkinService>((ref) {
  return SkinService(ref.read(skinRepositoryProvider));
});

// ── Derived / state providers ───────────────────────────────────────────────

/// The user's current coin + gem balance, derived from their profile row.
/// Refreshes when [userProfileProvider] is invalidated.
final currencyBalanceProvider = Provider<CurrencyBalance>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return const CurrencyBalance.zero();
  return CurrencyBalance(coins: profile.coins, gems: profile.gems);
});

/// The user's current subscription tier (app-level enum with full metadata),
/// derived from their profile row.
final currentTierProvider = Provider<app.SubscriptionTier>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  switch (profile?.subscriptionTier) {
    case 'pro':
      return app.SubscriptionTier.pro;
    case 'max':
      return app.SubscriptionTier.max;
    default:
      return app.SubscriptionTier.free;
  }
});

/// Tier benefits derived from the monetization package's [TierBenefits].
/// Maps the app-level tier to the monetization package's tier and returns
/// the canonical benefit set.
final tierBenefitsProvider = Provider<TierBenefits>((ref) {
  final appTier = ref.watch(currentTierProvider);

  // Map the app-level SubscriptionTier to the monetization package's enum.
  final SubscriptionTier monetizationTier;
  switch (appTier) {
    case app.SubscriptionTier.free:
      monetizationTier = SubscriptionTier.free;
    case app.SubscriptionTier.pro:
      monetizationTier = SubscriptionTier.pro;
    case app.SubscriptionTier.max:
      monetizationTier = SubscriptionTier.max;
  }

  return TierBenefits.forTier(monetizationTier);
});

/// Whether the current tier should see ads.
final showAdsProvider = Provider<bool>((ref) {
  return ref.watch(tierBenefitsProvider).ads;
});

/// Active challenges for display in the UI. Starts empty; screens should
/// load from [ChallengeService] and update this provider.
final activeChallengesProvider = StateProvider<List<UserChallenge>>((ref) {
  return [];
});

/// The current season, if one is active. Starts as null; screens should
/// load from [SeasonService] and update this provider.
final currentSeasonProvider = StateProvider<Season?>((ref) {
  return null;
});

/// The user's progress in the current season. Starts at defaults; screens
/// should load from [SeasonService] and update this provider.
final seasonProgressProvider = StateProvider<UserSeasonProgress?>((ref) {
  return null;
});
