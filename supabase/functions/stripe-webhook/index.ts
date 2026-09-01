import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { fulfillPurchase } from '../_shared/purchase_fulfillment.ts';
import Stripe from 'https://esm.sh/stripe@17.5.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') || '';

serve(async (req) => {
  // Webhook doesn't use CORS — Stripe calls this directly
  const signature = req.headers.get('stripe-signature');
  if (!signature) {
    console.error('Missing stripe-signature header');
    return new Response('Missing signature', { status: 400 });
  }

  if (!webhookSecret) {
    console.error('STRIPE_WEBHOOK_SECRET not configured');
    return new Response('Webhook not configured', { status: 500 });
  }

  try {
    const body = await req.text();
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
    );

    const admin = getSupabaseAdmin();

    console.log('Processing Stripe webhook:', { type: event.type, id: event.id });

    switch (event.type) {
      case 'checkout.session.completed': {
        await handleCheckoutSessionCompleted(admin, event.data.object as Stripe.Checkout.Session);
        break;
      }

      case 'invoice.paid': {
        await handleInvoicePaid(admin, event.data.object as Stripe.Invoice);
        break;
      }

      case 'customer.subscription.deleted': {
        await handleSubscriptionCancelled(admin, event.data.object as Stripe.Subscription);
        break;
      }

      default:
        console.log('Unhandled webhook event type:', event.type);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Webhook error:', error);
    const message = error instanceof Error ? error.message : 'Webhook error';
    return new Response(message, { status: 400 });
  }
});

/**
 * Handle checkout.session.completed — initial purchase or subscription.
 * This is a fallback in case verify-web-purchase wasn't called by the client.
 */
async function handleCheckoutSessionCompleted(
  admin: ReturnType<typeof getSupabaseAdmin>,
  session: Stripe.Checkout.Session,
): Promise<void> {
  const userId = session.client_reference_id;
  const productKey = session.metadata?.product_key;
  const transactionId = (session.payment_intent || session.subscription) as string;

  if (!userId || !productKey || !transactionId) {
    console.error('Missing required metadata in checkout session:', {
      userId,
      productKey,
      transactionId,
      sessionId: session.id,
    });
    return;
  }

  if (session.payment_status !== 'paid') {
    console.log('Checkout session not paid yet:', session.payment_status);
    return;
  }

  try {
    const result = await fulfillPurchase(admin, {
      userId,
      productKey,
      transactionId,
      platform: 'web',
      receiptData: session.id,
      verificationResponse: session,
      pricePaidUsd: (session.amount_total || 0) / 100,
      currencyCode: session.currency?.toUpperCase() || 'USD',
    });

    console.log('Checkout session fulfilled via webhook:', {
      sessionId: session.id,
      receiptId: result.receiptId,
      alreadyFulfilled: result.alreadyFulfilled,
    });
  } catch (error) {
    console.error('Failed to fulfill checkout session:', error);
    throw error;
  }
}

/**
 * Handle invoice.paid — subscription renewals.
 * Grant monthly coins/gems for active subscribers.
 */
async function handleInvoicePaid(
  admin: ReturnType<typeof getSupabaseAdmin>,
  invoice: Stripe.Invoice,
): Promise<void> {
  // Skip if this is the first invoice (handled by checkout.session.completed)
  if (invoice.billing_reason === 'subscription_create') {
    console.log('Skipping first invoice (handled by checkout session)');
    return;
  }

  const subscriptionId = invoice.subscription as string;
  if (!subscriptionId) {
    console.log('Invoice has no subscription ID');
    return;
  }

  // Look up subscription to get customer metadata
  const subscription = await stripe.subscriptions.retrieve(subscriptionId);

  // Find the user by subscription in our records
  const { data: subHistory } = await admin
    .from('subscription_history')
    .select('user_id, tier')
    .eq('provider', 'stripe')
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .limit(100);

  // Match by looking for a profile with this subscription
  // The subscription was stored when checkout.session.completed was processed
  // For renewals, we need to find the user by checking their active subscription

  // Get user from Stripe customer metadata or subscription metadata
  const userId = subscription.metadata?.user_id;

  if (!userId) {
    console.warn('Could not find user for subscription renewal:', subscriptionId);
    return;
  }

  // Determine tier from subscription items
  const priceId = subscription.items.data[0]?.price?.id;

  // Look up the product by stripe_price_id
  const { data: product } = await admin
    .from('products')
    .select('product_key, subscription_tier')
    .eq('stripe_price_id', priceId)
    .single();

  if (!product) {
    console.warn('Could not find product for price:', priceId);
    return;
  }

  // Fulfill as a renewal (originalTransactionId indicates renewal)
  const transactionId = `renewal_${invoice.id}`;

  try {
    const result = await fulfillPurchase(admin, {
      userId,
      productKey: product.product_key,
      transactionId,
      platform: 'web',
      receiptData: invoice.id,
      verificationResponse: invoice,
      pricePaidUsd: (invoice.amount_paid || 0) / 100,
      currencyCode: invoice.currency?.toUpperCase() || 'USD',
      originalTransactionId: subscriptionId, // Marks this as a renewal
    });

    console.log('Subscription renewed via webhook:', {
      invoiceId: invoice.id,
      userId,
      tier: product.subscription_tier,
      receiptId: result.receiptId,
    });
  } catch (error) {
    console.error('Failed to process subscription renewal:', error);
    throw error;
  }
}

/**
 * Handle subscription cancellation — update user's subscription status.
 */
async function handleSubscriptionCancelled(
  admin: ReturnType<typeof getSupabaseAdmin>,
  subscription: Stripe.Subscription,
): Promise<void> {
  const userId = subscription.metadata?.user_id;

  if (!userId) {
    console.warn('Could not find user for cancelled subscription:', subscription.id);
    return;
  }

  // Mark subscription history as inactive
  await admin
    .from('subscription_history')
    .update({ is_active: false, auto_renew_enabled: false })
    .eq('user_id', userId)
    .eq('provider', 'stripe')
    .eq('is_active', true);

  // Note: We don't immediately downgrade the user's tier.
  // Their subscription_expires_at will naturally expire, and the
  // client/cron checks for expiration when granting benefits.

  console.log('Subscription cancelled:', {
    subscriptionId: subscription.id,
    userId,
  });
}
