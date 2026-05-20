import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Subscription tiers with monthly pricing.
enum SubscriptionTier {
  free,
  pro,
  max;

  /// Monthly price in USD.
  double get priceUsd {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.pro:
        return 3.99;
      case SubscriptionTier.max:
        return 7.99;
    }
  }
}

/// Benefits granted by each subscription tier.
///
/// Use [TierBenefits.forTier] to get the canonical benefits for a tier.
/// A value of `-1` for [rerollsPerDay] means unlimited.
@immutable
class TierBenefits extends Equatable {
  final SubscriptionTier tier;
  final bool ads;
  final int dailyCoins;
  final int rerollsPerDay;
  final int maxFriends;
  final bool exclusiveSkins;
  final bool premiumSeasonPass;

  const TierBenefits({
    required this.tier,
    required this.ads,
    required this.dailyCoins,
    required this.rerollsPerDay,
    required this.maxFriends,
    this.exclusiveSkins = false,
    this.premiumSeasonPass = false,
  });

  /// Whether rerolls are unlimited for this tier.
  bool get unlimitedRerolls => rerollsPerDay < 0;

  // ── Canonical tier definitions ─────────────────────────────────────────

  static const free = TierBenefits(
    tier: SubscriptionTier.free,
    ads: true,
    dailyCoins: 200,
    rerollsPerDay: 1,
    maxFriends: 20,
  );

  static const pro = TierBenefits(
    tier: SubscriptionTier.pro,
    ads: false,
    dailyCoins: 800,
    rerollsPerDay: 3,
    maxFriends: 100,
    exclusiveSkins: true,
  );

  static const max = TierBenefits(
    tier: SubscriptionTier.max,
    ads: false,
    dailyCoins: 2500,
    rerollsPerDay: -1, // unlimited
    maxFriends: 500,
    exclusiveSkins: true,
    premiumSeasonPass: true,
  );

  /// Look up benefits for a given tier.
  static TierBenefits forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return free;
      case SubscriptionTier.pro:
        return pro;
      case SubscriptionTier.max:
        return max;
    }
  }

  @override
  List<Object?> get props => [
        tier,
        ads,
        dailyCoins,
        rerollsPerDay,
        maxFriends,
        exclusiveSkins,
        premiumSeasonPass,
      ];
}
