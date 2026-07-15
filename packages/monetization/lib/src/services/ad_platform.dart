/// Abstract interface for ad platform operations.
///
/// Implementations wrap the real ad SDK (e.g. Google AdMob) or provide
/// a mock for local development and testing.
abstract class AdPlatform {
  /// Show a banner ad. Completes when the banner is displayed.
  Future<void> showBanner();

  /// Show a full-screen interstitial ad. Completes when the ad is closed.
  Future<void> showInterstitial();

  /// Show a rewarded ad. Resolves to `true` if the user watched the entire
  /// ad and earned the reward, `false` if they dismissed early.
  Future<bool> showRewarded();

  /// Dispose of any loaded ad resources.
  void dispose();
}
