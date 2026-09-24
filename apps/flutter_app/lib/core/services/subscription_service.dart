import '../models/subscription_tier.dart';

/// Outcome of a completed store purchase (App Store / Play Store).
class NativePurchaseResult {
  /// Store product identifier that was bought.
  final String productId;

  /// Store transaction identifier. Present for consumables; may be null for
  /// subscriptions on some platforms — the server can resolve it itself.
  final String? transactionId;

  const NativePurchaseResult({required this.productId, this.transactionId});
}

/// Thin seam over the RevenueCat SDK so the app can run against a mock in
/// dev/tests and the real store SDK on devices.
abstract class RevenueCatWrapper {
  /// Identify the store user as our Supabase user so webhooks carry our id.
  Future<void> logIn(String appUserId);

  /// Drop back to an anonymous store user (on sign-out).
  Future<void> logOut();

  /// Identifiers of currently active entitlements (e.g. `pro`, `max`).
  Future<List<String>> getActiveEntitlements();

  /// Legacy subscription purchase by product id → success flag.
  Future<bool> purchase({required String productId});

  /// Purchase any store product. Returns null if the user cancelled; throws
  /// on failure with a user-presentable message.
  Future<NativePurchaseResult?> purchaseProduct(
    String storeProductId, {
    required bool isSubscription,
  });

  /// Re-sync purchases from the store account → active entitlements.
  Future<List<String>> restorePurchases();
}

class SubscriptionService {
  final RevenueCatWrapper _revenueCat;

  SubscriptionService({required RevenueCatWrapper revenueCat})
      : _revenueCat = revenueCat;

  Future<SubscriptionTier> getCurrentTier() async {
    final entitlements = await _revenueCat.getActiveEntitlements();
    return tierForEntitlements(entitlements);
  }

  Future<bool> purchaseSubscription(SubscriptionTier tier) async {
    if (tier == SubscriptionTier.free) return true;
    return await _revenueCat.purchase(productId: tier.productId);
  }

  /// Restore from the store account and return the resulting tier.
  Future<SubscriptionTier> restore() async {
    final entitlements = await _revenueCat.restorePurchases();
    return tierForEntitlements(entitlements);
  }

  static SubscriptionTier tierForEntitlements(List<String> entitlements) {
    if (entitlements.contains('max')) return SubscriptionTier.max;
    if (entitlements.contains('pro')) return SubscriptionTier.pro;
    return SubscriptionTier.free;
  }
}
