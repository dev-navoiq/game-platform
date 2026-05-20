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

/// Mock implementation of [AdPlatform] for local development and testing.
///
/// Simulates ad display delays without showing real ads:
/// - Banner: completes immediately
/// - Interstitial: 3 second delay
/// - Rewarded: 5 second delay, always returns `true` (watched)
class MockAdPlatform implements AdPlatform {
  bool _disposed = false;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('MockAdPlatform has been disposed');
    }
  }

  @override
  Future<void> showBanner() async {
    _checkDisposed();
    // Banner completes immediately in mock.
  }

  @override
  Future<void> showInterstitial() async {
    _checkDisposed();
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  @override
  Future<bool> showRewarded() async {
    _checkDisposed();
    await Future<void>.delayed(const Duration(seconds: 5));
    return true; // User always watches the full ad in mock.
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
