import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
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
    const productKey = body.product_key as string;
    const successUrl = body.success_url as string;
    const cancelUrl = body.cancel_url as string;

    if (!productKey || !successUrl || !cancelUrl) {
      return errorResponse('Missing required fields: product_key, success_url, cancel_url', 400);
    }

    // Fetch product from database
    const { data: product, error: productErr } = await admin
      .from('products')
      .select('*')
      .eq('product_key', productKey)
      .eq('is_active', true)
      .single();

    if (productErr || !product) {
      return errorResponse('Product not found or inactive', 404);
    }

    if (!product.stripe_price_id) {
      return errorResponse('Product not available for web purchase (no Stripe price ID)', 400);
    }

    // Determine mode (payment vs subscription)
    const mode = product.product_type === 'subscription' ? 'subscription' : 'payment';

    // Create Stripe Checkout session
    const session = await stripe.checkout.sessions.create({
      mode,
      line_items: [
        {
          price: product.stripe_price_id,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: user.id,
      metadata: {
        product_key: productKey,
        user_id: user.id,
      },
      // Disable managed payments (tax code not required)
      managed_payments: { enabled: false },
      // Allow promo codes for subscriptions
      ...(mode === 'subscription' && { allow_promotion_codes: true }),
    });

    console.log('Stripe checkout session created:', {
      sessionId: session.id,
      userId: user.id,
      productKey,
      mode,
    });

    return jsonResponse({
      session_id: session.id,
      url: session.url,
    });
  } catch (error) {
    console.error('create-stripe-checkout error:', error);
    return errorResponse('Failed to create checkout session', 500);
  }
});
