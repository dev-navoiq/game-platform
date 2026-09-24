import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { creditCurrency } from './currency.ts';

/**
 * Unified purchase fulfillment logic for all platforms.
 *
 * Flow:
 * 1. Fetch product from products table
 * 2. Check idempotency: has this transaction_id been processed?
 * 3. Insert receipt record (FIRST, before crediting)
 * 4. Fulfill based on product type:
 *    - gem_pack: Credit gems using atomic creditCurrency
 *    - subscription: Activate subscription tier + grant monthly coins/gems
 * 5. Return success with receipt ID
 *
 * Idempotency: If transaction_id already exists (unique constraint violation),
 * returns success immediately with existing receipt ID. Prevents double-credit
 * on network retries, user double-tap, webhook replays, etc.
 */
export async function fulfillPurchase(
  admin: SupabaseClient,
  params: {
    userId: string;
    productKey: string;
    transactionId: string;
    platform: 'ios' | 'android' | 'web';
    receiptData?: string;
    verificationResponse?: unknown;
    pricePaidUsd?: number;
    currencyCode?: string;
    originalTransactionId?: string; // For subscription renewals
    expiresAt?: string; // Store-reported subscription expiry (ISO); preferred over now+1mo
  },
): Promise<{ success: boolean; receiptId: string; alreadyFulfilled: boolean }> {
  // 1. Fetch product from catalog
  const { data: product, error: productErr } = await admin
    .from('products')
    .select('*')
    .eq('product_key', params.productKey)
    .eq('is_active', true)
    .maybeSingle();

  if (productErr) throw new Error(`Product lookup failed: ${productErr.message}`);
  if (!product) throw new Error(`Product not found or inactive: ${params.productKey}`);

  // 2. Check idempotency: transaction already processed?
  const { data: existingReceipt } = await admin
    .from('purchase_receipts')
    .select('id, status, fulfilled_at')
    .eq('transaction_id', params.transactionId)
    .maybeSingle();

  if (existingReceipt) {
    console.log('Purchase already fulfilled:', {
      transactionId: params.transactionId,
      receiptId: existingReceipt.id,
      status: existingReceipt.status,
    });
    return {
      success: existingReceipt.status === 'verified',
      receiptId: existingReceipt.id,
      alreadyFulfilled: true,
    };
  }

  // 3. Insert receipt record FIRST (before crediting currency)
  // If unique constraint fails due to race condition, catch and return early
  const receiptPayload = {
    user_id: params.userId,
    product_id: product.id,
    platform: params.platform,
    transaction_id: params.transactionId,
    original_transaction_id: params.originalTransactionId ?? null,
    receipt_data: params.receiptData ?? null,
    status: 'verified' as const,
    verified_at: new Date().toISOString(),
    verification_response: params.verificationResponse ?? null,
    price_paid_usd: params.pricePaidUsd ?? product.price_usd,
    currency_code: params.currencyCode ?? 'USD',
  };

  const { data: receipt, error: receiptErr } = await admin
    .from('purchase_receipts')
    .insert(receiptPayload)
    .select('id')
    .single();

  if (receiptErr) {
    // If unique constraint violation (23505), another process already fulfilled
    if (receiptErr.code === '23505') {
      console.log('Race condition: another process fulfilled this transaction');
      // Fetch the existing receipt
      const { data: raceReceipt } = await admin
        .from('purchase_receipts')
        .select('id')
        .eq('transaction_id', params.transactionId)
        .single();
      return {
        success: true,
        receiptId: raceReceipt?.id ?? '',
        alreadyFulfilled: true,
      };
    }
    throw new Error(`Receipt insert failed: ${receiptErr.message}`);
  }

  // 4. Fulfill based on product type
  try {
    if (product.product_type === 'gem_pack') {
      await fulfillGemPack(admin, params.userId, product, receipt.id);
    } else if (product.product_type === 'subscription') {
      await fulfillSubscription(admin, params.userId, product, receipt.id, params);
    } else {
      throw new Error(`Unknown product type: ${product.product_type}`);
    }

    // Mark receipt as fulfilled
    await admin
      .from('purchase_receipts')
      .update({ fulfilled_at: new Date().toISOString() })
      .eq('id', receipt.id);

    console.log('Purchase fulfilled successfully:', {
      userId: params.userId,
      productKey: params.productKey,
      transactionId: params.transactionId,
      receiptId: receipt.id,
    });

    return { success: true, receiptId: receipt.id, alreadyFulfilled: false };
  } catch (fulfillErr) {
    // Log fulfillment error but don't throw (receipt is already inserted)
    console.error('Fulfillment error:', fulfillErr);
    await admin
      .from('purchase_receipts')
      .update({
        status: 'failed',
        fulfillment_error: (fulfillErr as Error).message,
      })
      .eq('id', receipt.id);

    throw new Error(`Fulfillment failed: ${(fulfillErr as Error).message}`);
  }
}

/**
 * Fulfill a gem pack purchase by crediting gems to user's wallet.
 * Uses atomic creditCurrency to ensure wallet = Σ ledger.
 */
async function fulfillGemPack(
  admin: SupabaseClient,
  userId: string,
  product: {
    gems_granted: number;
    bonus_gems: number;
  },
  receiptId: string,
): Promise<void> {
  const totalGems = product.gems_granted + (product.bonus_gems ?? 0);
  if (totalGems <= 0) {
    throw new Error('Gem pack must grant > 0 gems');
  }

  const { credited } = await creditCurrency(
    admin,
    userId,
    'gems',
    totalGems,
    'gem_purchase',
    receiptId, // reference_id = receipt ID for audit trail
  );

  if (!credited) {
    console.warn('Gems were not credited (duplicate reference_id?)', {
      userId,
      receiptId,
      totalGems,
    });
  }
}

/**
 * Fulfill a subscription purchase by:
 * 1. Updating user's subscription tier and expiration
 * 2. Inserting subscription_history record
 * 3. Granting monthly coins/gems for this tier
 *
 * For renewals, extends existing expiration by 1 month.
 * For new subscriptions, sets expiration to now + 1 month.
 */
async function fulfillSubscription(
  admin: SupabaseClient,
  userId: string,
  product: {
    subscription_tier: 'pro' | 'max';
    billing_period?: { months?: number };
  },
  receiptId: string,
  params: {
    transactionId: string;
    originalTransactionId?: string;
    platform: 'ios' | 'android' | 'web';
    expiresAt?: string;
  },
): Promise<void> {
  if (!product.subscription_tier) {
    throw new Error('Subscription product must have subscription_tier');
  }

  // Determine provider string from platform
  const providerMap: Record<string, string> = {
    ios: 'apple',
    android: 'google',
    web: 'stripe',
  };
  const provider = providerMap[params.platform] ?? 'stripe';

  // Calculate new expiration date
  // If renewal (has original_transaction_id), extend from current expiration
  // Otherwise, start from now
  const { data: profile } = await admin
    .from('profiles')
    .select('subscription_tier, subscription_expires_at')
    .eq('id', userId)
    .single();

  let expiresAt: Date;
  // Apple/Google set original_transaction_id == transaction_id on the FIRST
  // purchase, so "has an original id" alone does not mean renewal.
  const isRenewal = !!params.originalTransactionId &&
    params.originalTransactionId !== params.transactionId;

  if (params.expiresAt) {
    // Trust the store's expiry when we have it (RevenueCat / webhooks).
    expiresAt = new Date(params.expiresAt);
  } else if (isRenewal && profile?.subscription_expires_at) {
    // Renewal: extend from current expiration (even if expired)
    expiresAt = new Date(profile.subscription_expires_at);
    expiresAt.setMonth(expiresAt.getMonth() + 1);
  } else {
    // New subscription: start from now
    expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + 1);
  }

  // Update profile subscription tier and expiration
  await admin
    .from('profiles')
    .update({
      subscription_tier: product.subscription_tier,
      subscription_expires_at: expiresAt.toISOString(),
    })
    .eq('id', userId);

  // Insert subscription_history record
  await admin.from('subscription_history').insert({
    user_id: userId,
    tier: product.subscription_tier,
    provider,
    transaction_id: receiptId, // Use our internal receipt ID
    started_at: new Date().toISOString(),
    expires_at: expiresAt.toISOString(),
    is_active: true,
    platform: params.platform,
    product_id: receiptId, // Reference to purchase_receipts.id
    auto_renew_enabled: true,
  });

  // Grant monthly coins and gems based on tier
  const monthlyGrants = getMonthlyGrants(product.subscription_tier);

  if (monthlyGrants.coins > 0) {
    await creditCurrency(
      admin,
      userId,
      'coins',
      monthlyGrants.coins,
      'subscription_monthly_grant',
      receiptId,
    );
  }

  if (monthlyGrants.gems > 0) {
    await creditCurrency(
      admin,
      userId,
      'gems',
      monthlyGrants.gems,
      'subscription_monthly_grant',
      receiptId,
    );
  }

  console.log('Subscription activated:', {
    userId,
    tier: product.subscription_tier,
    expiresAt: expiresAt.toISOString(),
    isRenewal,
    coinsGranted: monthlyGrants.coins,
    gemsGranted: monthlyGrants.gems,
  });
}

/**
 * Resolve a store product id (App Store / Play Store) to our product_key.
 * Google base-plan suffixes (`product:basePlan`) are stripped by the caller.
 */
export async function findProductKeyByStoreId(
  admin: SupabaseClient,
  storeProductId: string,
  platform: 'ios' | 'android',
): Promise<string | null> {
  const column = platform === 'ios' ? 'ios_product_id' : 'android_product_id';
  const { data, error } = await admin
    .from('products')
    .select('product_key')
    .eq(column, storeProductId)
    .eq('is_active', true)
    .maybeSingle();
  if (error) throw new Error(`Product lookup by store id failed: ${error.message}`);
  return data?.product_key ?? null;
}

/**
 * Get monthly coin/gem grants for a subscription tier.
 * Matches the subscription tiers defined in Flutter app.
 */
function getMonthlyGrants(tier: 'pro' | 'max'): { coins: number; gems: number } {
  const grants: Record<string, { coins: number; gems: number }> = {
    pro: { coins: 800, gems: 80 },
    max: { coins: 2500, gems: 300 },
  };
  return grants[tier] ?? { coins: 0, gems: 0 };
}
