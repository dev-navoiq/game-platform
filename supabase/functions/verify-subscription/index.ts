import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';

/**
 * RevenueCat webhook receiver.
 * Updates subscription tier and grants monthly currency.
 *
 * Expected headers:
 *   Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
 *
 * RevenueCat event types we handle:
 *   INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION
 */
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const admin = getSupabaseAdmin();

    // ── Verify webhook secret ─────────────────────────────────────────────
    const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
    const authHeader = req.headers.get('Authorization');

    if (webhookSecret && authHeader !== `Bearer ${webhookSecret}`) {
      return errorResponse('Invalid webhook secret', 401);
    }

    const payload = await req.json();
    const event = payload.event;

    if (!event) return errorResponse('Missing event', 400);

    const eventType = event.type as string;
    const appUserId = event.app_user_id as string;
    const productId = event.product_id as string;
    const expirationAt = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null;

    if (!appUserId) return errorResponse('Missing app_user_id', 400);

    // ── Map product ID to tier ────────────────────────────────────────────
    const tier = mapProductToTier(productId);

    switch (eventType) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL': {
        // Update profile tier
        await admin
          .from('profiles')
          .update({
            subscription_tier: tier,
            subscription_expires_at: expirationAt,
          })
          .eq('id', appUserId);

        // Record in subscription_history
        await admin.from('subscription_history').insert({
          user_id: appUserId,
          tier,
          provider: event.store || 'unknown',
          transaction_id: event.transaction_id || event.id || 'webhook',
          expires_at: expirationAt || new Date(Date.now() + 30 * 86400000).toISOString(),
          is_active: true,
          price_usd: event.price_in_purchased_currency || null,
        });

        // Grant monthly currency on initial purchase
        if (eventType === 'INITIAL_PURCHASE' || eventType === 'RENEWAL') {
          const monthly = getMonthlyGrant(tier);
          if (monthly.coins > 0) {
            await creditCurrency(admin, appUserId, 'coins', monthly.coins, 'subscription_monthly');
          }
          if (monthly.gems > 0) {
            await creditCurrency(admin, appUserId, 'gems', monthly.gems, 'subscription_monthly');
          }
        }

        // ── Check referral tier 4 (subscribes) ────────────────────────────
        if (eventType === 'INITIAL_PURCHASE') {
          const { data: referral } = await admin
            .from('referrals')
            .select('*')
            .eq('referee_id', appUserId)
            .lt('tier_reached', 4)
            .maybeSingle();

          if (referral) {
            await admin
              .from('referrals')
              .update({
                tier_reached: 4,
                rewarded_at: [...(referral.rewarded_at || []), new Date().toISOString()],
              })
              .eq('id', referral.id);

            // Referrer gets 500 coins + 50 gems
            await creditCurrency(admin, referral.referrer_id, 'coins', 500, 'referral_reward_tier4', referral.id);
            await creditCurrency(admin, referral.referrer_id, 'gems', 50, 'referral_reward_tier4', referral.id);
          }
        }

        break;
      }

      case 'CANCELLATION':
      case 'EXPIRATION': {
        // Downgrade to free
        await admin
          .from('profiles')
          .update({ subscription_tier: 'free' })
          .eq('id', appUserId);

        // Deactivate subscription history
        await admin
          .from('subscription_history')
          .update({ is_active: false })
          .eq('user_id', appUserId)
          .eq('is_active', true);

        break;
      }

      default:
        console.log(`Unhandled event type: ${eventType}`);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error('Verify subscription error:', error);
    return errorResponse('Internal server error', 500);
  }
});

function mapProductToTier(productId: string): 'free' | 'pro' | 'max' {
  if (!productId) return 'free';
  const lower = productId.toLowerCase();
  if (lower.includes('max') || lower.includes('premium')) return 'max';
  if (lower.includes('pro') || lower.includes('plus')) return 'pro';
  return 'free';
}

function getMonthlyGrant(tier: string): { coins: number; gems: number } {
  switch (tier) {
    case 'pro': return { coins: 800, gems: 80 };
    case 'max': return { coins: 2500, gems: 300 };
    default: return { coins: 0, gems: 0 };
  }
}
