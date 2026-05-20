import '../models/ad_placement.dart';
import '../models/currency.dart';

/// Abstract interface for ad impression persistence.
abstract class AdRepository {
  Future<AdImpression> recordImpression(
    String userId,
    AdType adType,
    AdPlacement placement,
  );
  Future<int> getRewardedAdCountToday(String userId);
  Future<DateTime?> getLastRewardedAdTime(String userId);
  Future<int> getCloseCountInWindow(String userId, Duration window);
  Future<CurrencyBalance> addRewardedAdCoins(String userId, int amount);
}

/// Service for ad gating logic, cooldowns, fatigue, and rewarded-ad rewards.
class AdService {
  final AdRepository _repository;

  AdService(this._repository);

  // ── Product-strategy constants ─────────────────────────────────────────

  /// Maximum rewarded ads a user may watch per calendar day.
  static const int maxRewardedPerDay = 5;

  /// Minimum time between rewarded ad watches.
  static const Duration rewardedCooldown = Duration(minutes: 20);

  /// Coins granted per completed rewarded ad.
  static const int rewardedAdCoinReward = 30;

  /// Number of ad closes within [fatigueWindow] that triggers a pause.
  static const int fatigueCloseThreshold = 3;

  /// Rolling window for measuring ad-close fatigue.
  static const Duration fatigueWindow = Duration(minutes: 10);

  /// Duration of the pause imposed after fatigue is detected.
  static const Duration fatiguePauseDuration = Duration(minutes: 30);

  // ── Public API ─────────────────────────────────────────────────────────

  /// Whether the user is currently eligible to watch a rewarded ad.
  Future<bool> canShowRewarded(String userId) async {
    // Check daily limit
    final todayCount = await _repository.getRewardedAdCountToday(userId);
    if (todayCount >= maxRewardedPerDay) return false;

    // Check cooldown
    final lastWatch = await _repository.getLastRewardedAdTime(userId);
    if (lastWatch != null) {
      final elapsed = DateTime.now().difference(lastWatch);
      if (elapsed < rewardedCooldown) return false;
    }

    // Check fatigue pause
    final recentCloses =
        await _repository.getCloseCountInWindow(userId, fatigueWindow);
    if (recentCloses >= fatigueCloseThreshold) return false;

    return true;
  }

  /// Record that an ad was shown. Returns the persisted impression.
  Future<AdImpression> recordImpression(
    String userId,
    AdType adType,
    AdPlacement placement,
  ) =>
      _repository.recordImpression(userId, adType, placement);

  /// Claim the coin reward for watching a rewarded ad.
  ///
  /// Throws [StateError] if the user is not eligible (daily limit, cooldown,
  /// or fatigue).
  Future<CurrencyBalance> claimRewardedAdReward(String userId) async {
    final canClaim = await canShowRewarded(userId);
    if (!canClaim) {
      throw StateError(
        'Cannot claim rewarded ad reward: daily limit, cooldown, or fatigue.',
      );
    }

    // Record the rewarded impression
    await _repository.recordImpression(
      userId,
      AdType.rewarded,
      AdPlacement.rewardedDoubleCoins,
    );

    // Grant coins
    return _repository.addRewardedAdCoins(userId, rewardedAdCoinReward);
  }
}
