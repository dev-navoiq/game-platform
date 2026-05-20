import 'subscription_service.dart';

/// Mock implementation of [RevenueCatWrapper] for local development and testing.
///
/// Simulates tier changes in-memory without a real RevenueCat SDK connection.
/// Defaults to the free tier. Call [simulatePurchase] to upgrade the tier.
class MockRevenueCat implements RevenueCatWrapper {
  final Set<String> _activeEntitlements = {};

  /// Simulate purchasing a subscription by adding the entitlement identifier.
  ///
  /// Use `'pro'` or `'max'` to match [SubscriptionService.getCurrentTier] logic.
  void simulatePurchase(String entitlement) {
    _activeEntitlements.add(entitlement);
  }

  /// Simulate cancelling a subscription by removing the entitlement.
  void simulateCancel(String entitlement) {
    _activeEntitlements.remove(entitlement);
  }

  /// Reset to the free tier by clearing all entitlements.
  void reset() {
    _activeEntitlements.clear();
  }

  @override
  Future<List<String>> getActiveEntitlements() async {
    return _activeEntitlements.toList();
  }

  @override
  Future<bool> purchase({required String productId}) async {
    // Simulate a successful purchase by mapping the product ID to an entitlement.
    if (productId == 'pro_monthly') {
      _activeEntitlements
        ..remove('max')
        ..add('pro');
    } else if (productId == 'max_monthly') {
      _activeEntitlements
        ..remove('pro')
        ..add('max');
    }
    return true;
  }
}
