import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monetization/monetization.dart';

import '../../features/challenges/data/supabase_challenge_repository.dart';
import '../../features/season_pass/data/supabase_season_repository.dart';
import '../../features/shop/data/supabase_ad_repository.dart';
import '../../features/shop/data/supabase_currency_repository.dart';
import '../../features/shop/data/supabase_skin_repository.dart';
import '../models/subscription_tier.dart' as app;
import '../services/mock_ad_platform.dart';
import '../services/mock_revenue_cat.dart';
import '../services/subscription_service.dart';

// ── Repository providers ────────────────────────────────────────────────────

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  return SupabaseCurrencyRepository();
});

final skinRepositoryProvider = Provider<SkinRepository>((ref) {
  return SupabaseSkinRepository();
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return SupabaseChallengeRepository();
});

final seasonRepositoryProvider = Provider<SeasonRepository>((ref) {
  return SupabaseSeasonRepository();
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

/// Ad platform — uses [MockAdPlatform] during local dev.
/// Override with a real AdMob implementation for production.
final adPlatformProvider = Provider<AdPlatform>((ref) {
  return MockAdPlatform();
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

/// The user's current coin + gem balance. Starts at zero; screens should
/// load the real balance from [CurrencyService] and update this provider.
final currencyBalanceProvider = StateProvider<CurrencyBalance>((ref) {
  return const CurrencyBalance.zero();
});

/// The user's current subscription tier (app-level enum with full metadata).
/// Updated after login and after any purchase via [SubscriptionService].
final currentTierProvider = StateProvider<app.SubscriptionTier>((ref) {
  return app.SubscriptionTier.free;
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
