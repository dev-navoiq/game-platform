import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'subscription_service.dart';

/// [RevenueCatWrapper] backed by the real RevenueCat SDK (StoreKit on iOS,
/// Play Billing on Android).
///
/// Configuration is lazy and happens once; the first caller that knows the
/// Supabase user id wins so we avoid creating a throwaway anonymous RevenueCat
/// user before login.
class RealRevenueCat implements RevenueCatWrapper {
  RealRevenueCat({required this.apiKey});

  final String apiKey;
  Future<void>? _configuring;

  Future<void> _ensureConfigured({String? appUserId}) {
    return _configuring ??= () async {
      if (await Purchases.isConfigured) return;
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = appUserId,
      );
    }();
  }

  @override
  Future<void> logIn(String appUserId) async {
    await _ensureConfigured(appUserId: appUserId);
    // Idempotent when already identified as this user; aliases the anonymous
    // user otherwise so prior sandbox purchases follow the account.
    await Purchases.logIn(appUserId);
  }

  @override
  Future<void> logOut() async {
    await _ensureConfigured();
    if (!await Purchases.isAnonymous) {
      await Purchases.logOut();
    }
  }

  @override
  Future<List<String>> getActiveEntitlements() async {
    await _ensureConfigured();
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.keys.toList();
  }

  @override
  Future<bool> purchase({required String productId}) async {
    final result = await purchaseProduct(productId, isSubscription: true);
    return result != null;
  }

  @override
  Future<NativePurchaseResult?> purchaseProduct(
    String storeProductId, {
    required bool isSubscription,
  }) async {
    await _ensureConfigured();

    final products = await Purchases.getProducts(
      [storeProductId],
      productCategory: isSubscription
          ? ProductCategory.subscription
          : ProductCategory.nonSubscription,
    );
    if (products.isEmpty) {
      throw StateError(
        'This item is not available in the store yet ($storeProductId).',
      );
    }

    try {
      final info = await Purchases.purchaseStoreProduct(products.first);
      return NativePurchaseResult(
        productId: storeProductId,
        transactionId: _latestTransactionId(info, storeProductId),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return null;
      throw StateError(_describe(code, e));
    }
  }

  @override
  Future<List<String>> restorePurchases() async {
    await _ensureConfigured();
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.keys.toList();
  }

  /// Most recent consumable transaction for [productId], if any. Subscriptions
  /// don't surface a transaction id in CustomerInfo; the server resolves it.
  String? _latestTransactionId(CustomerInfo info, String productId) {
    final txns = info.nonSubscriptionTransactions
        .where((t) => t.productIdentifier == productId)
        .toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    return txns.isEmpty ? null : txns.last.transactionIdentifier;
  }

  String _describe(PurchasesErrorCode code, PlatformException e) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending approval. Your items will arrive once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this. Try "Restore Purchases".';
      case PurchasesErrorCode.networkError:
        return 'Network error. Please try again.';
      case PurchasesErrorCode.storeProblemError:
        return 'The store is unavailable right now. Please try again later.';
      default:
        return e.message ?? 'Purchase failed (${code.name}).';
    }
  }
}
