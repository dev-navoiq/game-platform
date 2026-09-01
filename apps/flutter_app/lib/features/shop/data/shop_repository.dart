import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for shop purchases using coins/gems
class ShopRepository {
  final SupabaseClient _supabase;

  ShopRepository(this._supabase);

  /// Purchase a skin or theme with coins or gems
  Future<PurchaseResult> purchaseShopItem({
    required String assetKey,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'purchase-shop-item',
        body: {'asset_key': assetKey},
      );

      if (response.status != 200) {
        final data = response.data;
        if (data is Map && data['error'] != null) {
          throw PurchaseException(data['message'] ?? 'Purchase failed');
        }
        throw PurchaseException('Purchase failed with status ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return PurchaseResult.fromJson(data);
    } on PurchaseException {
      rethrow;
    } catch (e) {
      throw PurchaseException('Purchase failed: ${e.toString()}');
    }
  }

  /// Get owned skins for current user
  Future<List<String>> getOwnedSkins() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('user_skins')
          .select('skin_id, skins!inner(asset_key)')
          .eq('user_id', userId);

      return (response as List)
          .map((row) => row['skins']['asset_key'] as String)
          .toList();
    } catch (e) {
      // Return empty list on error (user just won't see owned skins)
      return [];
    }
  }
}

/// Result of a successful purchase
class PurchaseResult {
  final bool success;
  final String skinName;
  final String skinType;
  final String currency;
  final int amountPaid;
  final int balanceAfter;

  PurchaseResult({
    required this.success,
    required this.skinName,
    required this.skinType,
    required this.currency,
    required this.amountPaid,
    required this.balanceAfter,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      success: json['success'] ?? false,
      skinName: json['skin']?['name'] ?? '',
      skinType: json['skin']?['skin_type'] ?? '',
      currency: json['currency'] ?? '',
      amountPaid: json['amount_paid'] ?? 0,
      balanceAfter: json['balance_after'] ?? 0,
    );
  }
}

/// Custom exception for purchase errors
class PurchaseException implements Exception {
  final String message;

  PurchaseException(this.message);

  @override
  String toString() => message;
}
