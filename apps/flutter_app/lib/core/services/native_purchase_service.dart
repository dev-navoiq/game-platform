import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_service.dart';

enum NativePurchaseStatus { success, cancelled, failed }

class NativePurchaseOutcome {
  final NativePurchaseStatus status;
  final String? message;
  final bool alreadyFulfilled;

  const NativePurchaseOutcome._(this.status, {this.message, this.alreadyFulfilled = false});

  const NativePurchaseOutcome.success({bool alreadyFulfilled = false})
      : this._(NativePurchaseStatus.success, alreadyFulfilled: alreadyFulfilled);
  const NativePurchaseOutcome.cancelled() : this._(NativePurchaseStatus.cancelled);
  const NativePurchaseOutcome.failed(String message)
      : this._(NativePurchaseStatus.failed, message: message);

  bool get isSuccess => status == NativePurchaseStatus.success;
  bool get isCancelled => status == NativePurchaseStatus.cancelled;
}

/// iOS/Android purchase flow: catalog lookup → store purchase via RevenueCat
/// → server verification (`verify-native-purchase`) which credits the wallet.
///
/// Web uses Stripe instead (see WebPaymentService).
class NativePurchaseService {
  NativePurchaseService({
    required SupabaseClient supabase,
    required RevenueCatWrapper revenueCat,
    required this.platform,
    required this.isEnabled,
  })  : _supabase = supabase,
        _revenueCat = revenueCat;

  final SupabaseClient _supabase;
  final RevenueCatWrapper _revenueCat;

  /// `'ios'` or `'android'` — sent to the server to pick the store product id.
  final String platform;

  /// False when no RevenueCat key is configured for this build; purchases
  /// then fail fast with a clear message instead of a confusing store error.
  final bool isEnabled;

  Map<String, _CatalogEntry>? _catalog;

  /// Product key for a subscription tier's monthly plan (`sub_pro_monthly`).
  static String subscriptionProductKey(String tierName) => 'sub_${tierName}_monthly';

  Future<NativePurchaseOutcome> purchase(String productKey) async {
    if (!isEnabled) {
      return const NativePurchaseOutcome.failed(
        'In-app purchases are not configured for this build.',
      );
    }
    try {
      final entry = await _lookup(productKey);
      final storeId = platform == 'ios' ? entry.iosId : entry.androidId;
      if (storeId == null || storeId.isEmpty) {
        return NativePurchaseOutcome.failed('Not available on $platform.');
      }

      final result = await _revenueCat.purchaseProduct(
        storeId,
        isSubscription: entry.isSubscription,
      );
      if (result == null) return const NativePurchaseOutcome.cancelled();

      return await _verify(productKey, result.transactionId);
    } catch (e) {
      return NativePurchaseOutcome.failed(_message(e));
    }
  }

  /// Re-sync the store account, then ask the server to (idempotently) fulfill
  /// any active subscription so the profile tier matches the store.
  Future<NativePurchaseOutcome> restore() async {
    if (!isEnabled) {
      return const NativePurchaseOutcome.failed(
        'In-app purchases are not configured for this build.',
      );
    }
    try {
      final entitlements = await _revenueCat.restorePurchases();
      final tiers = entitlements.where((e) => e == 'pro' || e == 'max').toList();
      if (tiers.isEmpty) {
        return const NativePurchaseOutcome.failed('No purchases to restore.');
      }
      for (final tier in tiers) {
        await _verify(subscriptionProductKey(tier), null);
      }
      return const NativePurchaseOutcome.success(alreadyFulfilled: true);
    } catch (e) {
      return NativePurchaseOutcome.failed(_message(e));
    }
  }

  Future<NativePurchaseOutcome> _verify(String productKey, String? transactionId) async {
    try {
      final res = await _supabase.functions.invoke(
        'verify-native-purchase',
        body: {
          'product_key': productKey,
          'platform': platform,
          if (transactionId != null) 'transaction_id': transactionId,
        },
      );
      final data = res.data;
      if (res.status != 200 || data is! Map) {
        final err = data is Map ? data['error'] : null;
        throw StateError('Verification failed: ${err ?? 'HTTP ${res.status}'}');
      }
      return NativePurchaseOutcome.success(
        alreadyFulfilled: data['already_fulfilled'] == true,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final err = details is Map ? details['error'] : null;
      throw StateError('Verification failed: ${err ?? e.reasonPhrase ?? e.status}');
    }
  }

  Future<_CatalogEntry> _lookup(String productKey) async {
    _catalog ??= await _loadCatalog();
    final entry = _catalog![productKey];
    if (entry == null) throw StateError('Unknown product: $productKey');
    return entry;
  }

  Future<Map<String, _CatalogEntry>> _loadCatalog() async {
    final rows = await _supabase
        .from('products')
        .select('product_key, product_type, ios_product_id, android_product_id')
        .eq('is_active', true);
    return {
      for (final row in rows)
        row['product_key'] as String: _CatalogEntry(
          isSubscription: row['product_type'] == 'subscription',
          iosId: row['ios_product_id'] as String?,
          androidId: row['android_product_id'] as String?,
        ),
    };
  }

  String _message(Object e) {
    if (e is StateError) return e.message;
    return e.toString();
  }
}

class _CatalogEntry {
  final bool isSubscription;
  final String? iosId;
  final String? androidId;
  const _CatalogEntry({required this.isSubscription, this.iosId, this.androidId});
}
