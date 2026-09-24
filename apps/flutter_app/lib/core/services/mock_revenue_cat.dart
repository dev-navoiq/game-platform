import 'subscription_service.dart';

/// Mock implementation of [RevenueCatWrapper] for local development and testing.
///
/// Simulates tier changes in-memory without a real RevenueCat SDK connection.
/// Defaults to the free tier. Call [simulatePurchase] to upgrade the tier.
class MockRevenueCat implements RevenueCatWrapper {
  final Set<String> _activeEntitlements = {};
  String? _appUserId;
  int _txCounter = 0;

  /// The identity most recently passed to [logIn] (null after [logOut]).
  String? get appUserId => _appUserId;

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
    _appUserId = null;
  }

  @override
  Future<void> logIn(String appUserId) async {
    _appUserId = appUserId;
  }

  @override
  Future<void> logOut() async {
    _appUserId = null;
  }

  @override
  Future<List<String>> getActiveEntitlements() async {
    return _activeEntitlements.toList();
  }

  @override
  Future<bool> purchase({required String productId}) async {
    _applyEntitlementFor(productId);
    return true;
  }

  @override
  Future<NativePurchaseResult?> purchaseProduct(
    String storeProductId, {
    required bool isSubscription,
  }) async {
    if (isSubscription) _applyEntitlementFor(storeProductId);
    return NativePurchaseResult(
      productId: storeProductId,
      transactionId: 'mock-txn-${++_txCounter}',
    );
  }

  @override
  Future<List<String>> restorePurchases() async {
    return _activeEntitlements.toList();
  }

  /// Map a product id (`pro_monthly`, `com.navoiq.gathr.max_monthly`, …) to
  /// the entitlement it grants. Tiers are mutually exclusive.
  void _applyEntitlementFor(String productId) {
    if (productId.contains('pro_monthly')) {
      _activeEntitlements
        ..remove('max')
        ..add('pro');
    } else if (productId.contains('max_monthly')) {
      _activeEntitlements
        ..remove('pro')
        ..add('max');
    }
  }
}
