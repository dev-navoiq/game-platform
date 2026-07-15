import 'package:monetization/monetization.dart' show AdPlatform;

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
