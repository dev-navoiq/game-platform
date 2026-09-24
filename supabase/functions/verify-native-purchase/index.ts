import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { fulfillPurchase } from '../_shared/purchase_fulfillment.ts';
import { fetchRcSubscriber, findVerifiedPurchase } from '../_shared/revenuecat.ts';

/**
 * Verify + fulfill an iOS/Android purchase made through RevenueCat.
 *
 * Native counterpart of verify-web-purchase. The device completes the store
 * purchase via the RevenueCat SDK, then calls this with:
 *   { product_key, platform: 'ios'|'android', transaction_id? }
 *
 * We confirm the purchase against RevenueCat's REST API for the calling user
 * (RevenueCat has already validated the receipt with Apple/Google) and run the
 * shared fulfillment, which is idempotent on transaction_id — so if the
 * RevenueCat webhook (verify-subscription) already credited this purchase,
 * this call is a no-op that still returns success.
 */
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body = await req.json().catch(() => ({}));
    const productKey = body.product_key as string | undefined;
    const platform = body.platform as string | undefined;
    const transactionId = (body.transaction_id as string | undefined) || undefined;

    if (!productKey) return errorResponse('product_key is required', 400);
    if (platform !== 'ios' && platform !== 'android') {
      return errorResponse("platform must be 'ios' or 'android'", 400);
    }

    const { data: product, error: productErr } = await admin
      .from('products')
      .select('product_key, product_type, ios_product_id, android_product_id')
      .eq('product_key', productKey)
      .eq('is_active', true)
      .maybeSingle();
    if (productErr) throw productErr;
    if (!product) return errorResponse('Product not found or inactive', 404);

    const storeProductId = platform === 'ios'
      ? product.ios_product_id
      : product.android_product_id;
    if (!storeProductId) {
      return errorResponse(`Product not available on ${platform}`, 400);
    }

    const subscriber = await fetchRcSubscriber(user.id);
    const purchase = findVerifiedPurchase(
      subscriber,
      storeProductId,
      product.product_type,
      transactionId,
    );
    if (!purchase) {
      console.warn('verify-native-purchase: no matching purchase', {
        userId: user.id,
        productKey,
        storeProductId,
        transactionId,
      });
      return errorResponse('Purchase not found for this user', 402, 'PURCHASE_NOT_FOUND');
    }

    const result = await fulfillPurchase(admin, {
      userId: user.id,
      productKey,
      transactionId: purchase.transactionId,
      originalTransactionId: purchase.originalTransactionId,
      platform,
      receiptData: transactionId ?? purchase.transactionId,
      verificationResponse: purchase.raw,
      pricePaidUsd: purchase.priceUsd,
      currencyCode: purchase.currencyCode?.toUpperCase(),
      expiresAt: purchase.expiresAt,
    });

    console.log('verify-native-purchase: fulfilled', {
      userId: user.id,
      productKey,
      platform,
      transactionId: purchase.transactionId,
      receiptId: result.receiptId,
      alreadyFulfilled: result.alreadyFulfilled,
      sandbox: purchase.isSandbox,
    });

    return jsonResponse({
      success: result.success,
      receipt_id: result.receiptId,
      already_fulfilled: result.alreadyFulfilled,
    });
  } catch (error) {
    console.error('verify-native-purchase error:', error);
    const message = error instanceof Error ? error.message : 'Verification failed';
    return errorResponse(message, 500);
  }
});
