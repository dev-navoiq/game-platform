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

/** Length-independent constant-accumulation compare (inputs already length-checked). */
function timingSafeEqual(a: string, b: string): boolean {
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const admin = getSupabaseAdmin();

    // ── Verify webhook secret (FAIL CLOSED) ───────────────────────────────
    // Previously the check was skipped entirely when the secret was unset,
    // letting anyone POST a fake purchase and grant themselves Max + currency.
    // Now: no secret configured → reject. See SECURITY-AUDIT H1 / GUIDELINES E2.
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

    const payload = await req.json();
    const event = payload.event;

    if (!event) return errorResponse('Missing event', 400);

    // Idempotency key: RevenueCat sends a stable event.id. We tag currency
    // grants with it and a unique index blocks replays of the same event.
    // reference_id is a uuid column, so only use the id if it is UUID-shaped;
    // otherwise fall back to no reference (grant still applies, just un-deduped).
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const rawEventId = (event.id as string) || (event.transaction_id as string) || '';
    const eventId = UUID_RE.test(rawEventId) ? rawEventId : null;

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

        // Grant monthly currency on initial purchase / renewal. Tag each grant
        // with the RevenueCat event id so a replayed webhook can't double-credit
        // (a unique index on currency_transactions enforces this). Each real
        // renewal carries a distinct event id, so legitimate monthly grants pass.
        if (eventType === 'INITIAL_PURCHASE' || eventType === 'RENEWAL') {
          const monthly = getMonthlyGrant(tier);
          try {
            if (monthly.coins > 0) {
              await creditCurrency(admin, appUserId, 'coins', monthly.coins, 'subscription_monthly', eventId ?? undefined);
            }
            if (monthly.gems > 0) {
              await creditCurrency(admin, appUserId, 'gems', monthly.gems, 'subscription_monthly', eventId ?? undefined);
            }
          } catch (e) {
            // Unique-index violation = this event was already processed; ignore.
            const msg = e instanceof Error ? e.message : String(e);
            if (!/duplicate key|unique constraint/i.test(msg)) throw e;
            console.log('verify-subscription: duplicate event grant skipped', eventId);
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
