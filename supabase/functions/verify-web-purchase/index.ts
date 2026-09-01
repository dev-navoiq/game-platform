import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { fulfillPurchase } from '../_shared/purchase_fulfillment.ts';
import Stripe from 'https://esm.sh/stripe@17.5.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

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
    const sessionId = body.session_id as string;

    if (!sessionId) {
      return errorResponse('session_id is required', 400);
    }

    // Retrieve session from Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    // Verify session belongs to this user
    if (session.client_reference_id !== user.id) {
      console.warn('Session user mismatch:', {
        sessionUserId: session.client_reference_id,
        requestUserId: user.id,
      });
      return errorResponse('Session does not belong to this user', 403);
    }

    // Verify payment status
    if (session.payment_status !== 'paid') {
      return errorResponse(`Payment not completed. Status: ${session.payment_status}`, 400);
    }

    // Extract metadata
    const productKey = session.metadata?.product_key;
    if (!productKey) {
      return errorResponse('Invalid session metadata: missing product_key', 400);
    }

    // Use payment_intent or subscription ID as transaction ID
    const transactionId = (session.payment_intent || session.subscription) as string;
    if (!transactionId) {
      return errorResponse('No transaction ID found in session', 400);
    }

    // Fulfill purchase using shared logic
    const result = await fulfillPurchase(admin, {
      userId: user.id,
      productKey,
      transactionId,
      platform: 'web',
      receiptData: sessionId,
      verificationResponse: session,
      pricePaidUsd: (session.amount_total || 0) / 100,
      currencyCode: session.currency?.toUpperCase() || 'USD',
    });

    if (result.alreadyFulfilled) {
      console.log('Purchase already fulfilled (idempotent):', {
        sessionId,
        receiptId: result.receiptId,
      });
      return jsonResponse({
        success: true,
        message: 'Purchase already fulfilled',
        receipt_id: result.receiptId,
      });
    }

    console.log('Purchase verified and fulfilled:', {
      sessionId,
      userId: user.id,
      productKey,
      receiptId: result.receiptId,
    });

    return jsonResponse({
      success: true,
      receipt_id: result.receiptId,
    });
  } catch (error) {
    console.error('verify-web-purchase error:', error);
    const message = error instanceof Error ? error.message : 'Verification failed';
    return errorResponse(message, 500);
  }
});
