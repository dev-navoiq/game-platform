import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a purchase attempt.
class PurchaseResult {
  final String sessionId;
  final String productKey;
  final PurchaseStatus status;
  final String? receiptId;
  final String? errorMessage;

  const PurchaseResult({
    required this.sessionId,
    required this.productKey,
    required this.status,
    this.receiptId,
    this.errorMessage,
  });

  bool get isSuccess => status == PurchaseStatus.completed;
  bool get isPending => status == PurchaseStatus.pending;
}

enum PurchaseStatus {
  /// User was redirected to Stripe checkout
  pending,

  /// Purchase completed and verified
  completed,

  /// Purchase was cancelled by user
  cancelled,

  /// Purchase failed (payment declined, etc.)
  failed,
}

/// Product information from the database.
class WebProduct {
  final String productKey;
  final String displayName;
  final String? description;
  final double priceUsd;
  final String productType;
  final int? gemsGranted;
  final int? bonusGems;

  const WebProduct({
    required this.productKey,
    required this.displayName,
    this.description,
    required this.priceUsd,
    required this.productType,
    this.gemsGranted,
    this.bonusGems,
  });

  factory WebProduct.fromJson(Map<String, dynamic> json) {
    return WebProduct(
      productKey: json['product_key'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String?,
      priceUsd: (json['price_usd'] as num).toDouble(),
      productType: json['product_type'] as String,
      gemsGranted: json['gems_granted'] as int?,
      bonusGems: json['bonus_gems'] as int?,
    );
  }

  int get totalGems => (gemsGranted ?? 0) + (bonusGems ?? 0);
}

/// Stripe checkout session response.
class CheckoutSession {
  final String sessionId;
  final String url;

  const CheckoutSession({
    required this.sessionId,
    required this.url,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      sessionId: json['session_id'] as String,
      url: json['url'] as String,
    );
  }
}

/// Service for handling web payments via Stripe.
///
/// This service creates Stripe Checkout sessions and verifies purchases
/// after the user returns from payment.
class WebPaymentService {
  final SupabaseClient _supabase;

  WebPaymentService(this._supabase);

  /// Create a Stripe Checkout session for a product.
  ///
  /// Returns a [CheckoutSession] with the checkout URL to redirect the user to.
  /// The caller should redirect to `session.url` using url_launcher.
  Future<CheckoutSession> createCheckoutSession({
    required String productKey,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-stripe-checkout',
      body: {
        'product_key': productKey,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      },
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw WebPaymentException('Failed to create checkout session: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return CheckoutSession.fromJson(data);
  }

  /// Verify a purchase after the user returns from Stripe Checkout.
  ///
  /// This should be called when the app receives a success callback from Stripe
  /// with the session_id query parameter.
  ///
  /// Returns a [PurchaseResult] indicating whether the purchase was successful.
  Future<PurchaseResult> verifyPurchase(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'verify-web-purchase',
      body: {'session_id': sessionId},
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Verification failed';
      return PurchaseResult(
        sessionId: sessionId,
        productKey: '',
        status: PurchaseStatus.failed,
        errorMessage: error.toString(),
      );
    }

    final data = response.data as Map<String, dynamic>;
    final success = data['success'] == true;

    return PurchaseResult(
      sessionId: sessionId,
      productKey: '',
      status: success ? PurchaseStatus.completed : PurchaseStatus.failed,
      receiptId: data['receipt_id'] as String?,
      errorMessage: data['message'] as String?,
    );
  }

  /// Get available products for purchase from the database.
  Future<List<WebProduct>> getProducts({
    List<String>? productKeys,
    String? productType,
  }) async {
    var query = _supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .not('stripe_price_id', 'is', null);

    if (productKeys != null && productKeys.isNotEmpty) {
      query = query.inFilter('product_key', productKeys);
    }

    if (productType != null) {
      query = query.eq('product_type', productType);
    }

    final response = await query.order('price_usd', ascending: true);
    return (response as List).map((p) => WebProduct.fromJson(p)).toList();
  }

  /// Get available gem packs for purchase.
  Future<List<WebProduct>> getGemPacks() async {
    return getProducts(productType: 'gem_pack');
  }

  /// Get available subscriptions for purchase.
  Future<List<WebProduct>> getSubscriptions() async {
    return getProducts(productType: 'subscription');
  }
}

/// Exception thrown when a web payment operation fails.
class WebPaymentException implements Exception {
  final String message;

  const WebPaymentException(this.message);

  @override
  String toString() => 'WebPaymentException: $message';
}
