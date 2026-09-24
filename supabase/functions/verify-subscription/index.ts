import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';
import { fulfillPurchase, findProductKeyByStoreId } from '../_shared/purchase_fulfillment.ts';
import { baseStoreProductId } from '../_shared/revenuecat.ts';

/**
 * RevenueCat webhook receiver (iOS + Android purchases and subscription
 * lifecycle). Server-authoritative source of truth for native purchases; the
 * client-initiated verify-native-purchase path is the fast lane and both share
 * one idempotency key (store transaction id) via fulfillPurchase.
 *
 * Expected header:  Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
 *
 * Events:
 *   INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE, NON_RENEWING_PURCHASE → fulfill
 *   CANCELLATION      → auto-renew off (tier stays until EXPIRATION)
 *   UNCANCELLATION    → auto-renew back on
 *   BILLING_ISSUE     → flag on subscription_history
 *   EXPIRATION        → downgrade to free
 *   TEST / others     → acknowledged, no-op
 *
 * Always answer 2xx for events we choose to ignore — RevenueCat retries
 * non-2xx responses for hours, which is only useful for transient failures.
 */

/** Length-independent constant-accumulation compare (inputs already length-checked). */
function timingSafeEqual(a: string, b: string): boolean {
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** RevenueCat `store` → our platform enum. Null for stores we don't fulfill here. */
function platformForStore(store: string | undefined): 'ios' | 'android' | null {
  switch (store) {
    case 'APP_STORE':
    case 'MAC_APP_STORE':
      return 'ios';
    case 'PLAY_STORE':
      return 'android';
    default:
      return null;
  }
}

/**
 * The Supabase user id. We call Purchases.logIn(supabaseUserId) on device, so
 * app_user_id is normally our uuid; if RevenueCat reports the anonymous id
 * instead, look through the aliases for the uuid.
 */
function resolveUserId(event: Record<string, unknown>): string | null {
  const candidates = [
    event.app_user_id as string | undefined,
    event.original_app_user_id as string | undefined,
    ...((event.aliases as string[] | undefined) ?? []),
  ];
  return candidates.find((id) => id && UUID_RE.test(id)) ?? null;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const admin = getSupabaseAdmin();

    // ── Verify webhook secret (FAIL CLOSED) ───────────────────────────────
    const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
    if (!webhookSecret) {
      console.error('verify-subscription: REVENUECAT_WEBHOOK_SECRET not set; rejecting.');
      return errorResponse('Webhook not configured', 503, 'WEBHOOK_UNCONFIGURED');
    }
    const authHeader = req.headers.get('Authorization') ?? '';
    const expected = `Bearer ${webhookSecret}`;
    if (authHeader.length !== expected.length || !timingSafeEqual(authHeader, expected)) {
      return errorResponse('Invalid webhook secret', 401);
    }

    const payload = await req.json().catch(() => ({}));
    const event = payload.event as Record<string, unknown> | undefined;
    if (!event) return errorResponse('Missing event', 400);

    const eventType = event.type as string;
    if (eventType === 'TEST') return jsonResponse({ received: true, note: 'test event' });

    const userId = resolveUserId(event);
    if (!userId) {
      console.warn('verify-subscription: no Supabase user id on event; ignoring', {
        type: eventType,
        appUserId: event.app_user_id,
      });
      return jsonResponse({ received: true, note: 'no user id' });
    }

    const platform = platformForStore(event.store as string | undefined);
    const rawProductId = (event.product_id as string | undefined) ?? '';
    const storeProductId = baseStoreProductId(rawProductId);
    const expiresAt = event.expiration_at_ms
      ? new Date(event.expiration_at_ms as number).toISOString()
      : undefined;

    switch (eventType) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'NON_RENEWING_PURCHASE': {
        if (!platform) {
          console.log('verify-subscription: store not handled here', event.store);
          return jsonResponse({ received: true, note: `store ${event.store} ignored` });
        }
        const productKey = await findProductKeyByStoreId(admin, storeProductId, platform);
        if (!productKey) {
          // Catalog mismatch is a config error; retrying won't fix it.
          console.error('verify-subscription: unknown store product', { storeProductId, platform });
          return jsonResponse({ received: true, note: 'unknown product' });
        }

        const transactionId = (event.transaction_id as string | undefined) ||
          (event.id as string | undefined);
        if (!transactionId) return errorResponse('Missing transaction_id', 400);

        const result = await fulfillPurchase(admin, {
          userId,
          productKey,
          transactionId,
          originalTransactionId: event.original_transaction_id as string | undefined,
          platform,
          receiptData: event.id as string | undefined,
          verificationResponse: event,
          pricePaidUsd: typeof event.price === 'number' ? event.price : undefined,
          currencyCode: (event.currency as string | undefined)?.toUpperCase(),
          expiresAt,
        });

        // Referral tier 4 (referee subscribed) — first subscription only.
        if (eventType === 'INITIAL_PURCHASE' && !result.alreadyFulfilled) {
          await grantReferralTier4(admin, userId);
        }

        console.log('verify-subscription: fulfilled', {
          type: eventType,
          userId,
          productKey,
          transactionId,
          alreadyFulfilled: result.alreadyFulfilled,
        });
        break;
      }

      case 'CANCELLATION': {
        // Auto-renew turned off; access continues until EXPIRATION.
        await admin
          .from('subscription_history')
          .update({ auto_renew_enabled: false })
          .eq('user_id', userId)
          .eq('is_active', true);
        break;
      }

      case 'UNCANCELLATION': {
        await admin
          .from('subscription_history')
          .update({ auto_renew_enabled: true, billing_issue_detected_at: null })
          .eq('user_id', userId)
          .eq('is_active', true);
        break;
      }

      case 'BILLING_ISSUE': {
        await admin
          .from('subscription_history')
          .update({
            billing_issue_detected_at: new Date().toISOString(),
            grace_period_expires_at: event.grace_period_expiration_at_ms
              ? new Date(event.grace_period_expiration_at_ms as number).toISOString()
              : null,
          })
          .eq('user_id', userId)
          .eq('is_active', true);
        break;
      }

      case 'EXPIRATION': {
        await admin
          .from('profiles')
          .update({ subscription_tier: 'free', subscription_expires_at: expiresAt ?? null })
          .eq('id', userId);
        await admin
          .from('subscription_history')
          .update({ is_active: false })
          .eq('user_id', userId)
          .eq('is_active', true);
        console.log('verify-subscription: expired → free', { userId });
        break;
      }

      default:
        console.log(`verify-subscription: unhandled event type ${eventType}`);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error('verify-subscription error:', error);
    return errorResponse('Internal server error', 500);
  }
});

async function grantReferralTier4(
  admin: ReturnType<typeof getSupabaseAdmin>,
  refereeId: string,
): Promise<void> {
  const { data: referral } = await admin
    .from('referrals')
    .select('*')
    .eq('referee_id', refereeId)
    .lt('tier_reached', 4)
    .maybeSingle();
  if (!referral) return;

  await admin
    .from('referrals')
    .update({
      tier_reached: 4,
      rewarded_at: [...(referral.rewarded_at || []), new Date().toISOString()],
    })
    .eq('id', referral.id);

  // Referrer gets 500 coins + 50 gems (reference = referral id → idempotent)
  await creditCurrency(admin, referral.referrer_id, 'coins', 500, 'referral_reward_tier4', referral.id);
  await creditCurrency(admin, referral.referrer_id, 'gems', 50, 'referral_reward_tier4', referral.id);
}
