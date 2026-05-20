import '../models/subscription_tier.dart';

abstract class RevenueCatWrapper {
  Future<List<String>> getActiveEntitlements();
  Future<bool> purchase({required String productId});
}

class SubscriptionService {
  final RevenueCatWrapper _revenueCat;

  SubscriptionService({required RevenueCatWrapper revenueCat})
      : _revenueCat = revenueCat;

  Future<SubscriptionTier> getCurrentTier() async {
    final entitlements = await _revenueCat.getActiveEntitlements();

    if (entitlements.contains('max')) return SubscriptionTier.max;
    if (entitlements.contains('pro')) return SubscriptionTier.pro;
    return SubscriptionTier.free;
  }

  Future<bool> purchaseSubscription(SubscriptionTier tier) async {
    if (tier == SubscriptionTier.free) return true;
    return await _revenueCat.purchase(productId: tier.productId);
  }
}
