# Implementation Plan: Stripe Integration (Phase 2)

**Goal**: Enable web users to purchase gems and subscriptions with real money via Stripe

**Estimated Time**: 1 week

**What Users Get**:
- Buy gem packs on web ($0.99 - $49.99)
- Subscribe to Pro/Max on web ($3.99, $7.99/month)
- Automatic subscription renewals with monthly coin/gem grants

---

## Prerequisites

- ✅ Phase 1 complete (database schema deployed)
- ✅ Stripe account created
- ✅ Test mode enabled

---

## Architecture Overview

```
Flutter Web App
    ↓
1. User clicks "Buy Gems"
    ↓
2. Call: create-stripe-checkout (edge function)
    ↓
3. Redirect to Stripe Checkout
    ↓
4. User pays on Stripe
    ↓
5. Stripe redirects back to app
    ↓
6. Call: verify-web-purchase (edge function)
    ↓
7. Backend verifies with Stripe API
    ↓
8. Credit gems using purchase_fulfillment.ts
    ↓
9. Show success message
```

---

## Step 1: Stripe Setup (15 minutes)

### 1.1 Create Stripe Account

1. Go to: https://dashboard.stripe.com/register
2. Complete signup (use staging email)
3. Enable test mode (toggle in dashboard)

### 1.2 Create Products in Stripe

**In Stripe Dashboard → Products:**

Create 5 gem pack products:

| Name | Price | Product ID | Price ID |
|------|-------|------------|----------|
| Starter Pack | $0.99 | prod_xxx | price_gem_starter |
| Popular Pack | $3.99 | prod_xxx | price_gem_popular |
| Value Pack | $7.99 | prod_xxx | price_gem_value |
| Premium Pack | $19.99 | prod_xxx | price_gem_premium |
| Ultimate Pack | $49.99 | prod_xxx | price_gem_ultimate |

Create 2 subscription products:

| Name | Price | Billing | Price ID |
|------|-------|---------|----------|
| Pro Membership | $3.99/month | Recurring | price_pro_monthly |
| Max Membership | $7.99/month | Recurring | price_max_monthly |

### 1.3 Get API Keys

**Dashboard → Developers → API Keys:**

Copy:
- **Publishable key** (pk_test_...) - For Flutter app
- **Secret key** (sk_test_...) - For backend
- **Webhook signing secret** (whsec_...) - For webhook verification

### 1.4 Update Database with Stripe Price IDs

```sql
-- Update products table with real Stripe price IDs
UPDATE products SET stripe_price_id = 'price_xxx_from_dashboard_xxx'
WHERE product_key = 'gem_starter';

-- Repeat for all 7 products
```

---

## Step 2: Backend - Create Stripe Checkout Session (1 hour)

### 2.1 Install Stripe SDK

**File**: `supabase/functions/create-stripe-checkout/index.ts`

```typescript
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
      return errorResponse('Missing required fields', 400);
    }

    // Fetch product from database
    const { data: product, error: productErr } = await admin
      .from('products')
      .select('*')
      .eq('product_key', productKey)
      .eq('is_active', true)
      .single();

    if (productErr || !product) {
      return errorResponse('Product not found', 404);
    }

    if (!product.stripe_price_id) {
      return errorResponse('Product not available for web purchase', 400);
    }

    // Determine mode (payment vs subscription)
    const mode = product.product_type === 'subscription'
      ? 'subscription'
      : 'payment';

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
      client_reference_id: user.id, // Track who's purchasing
      metadata: {
        product_key: productKey,
        user_id: user.id,
      },
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
```

### 2.2 Configure Environment Variables

**In Supabase Dashboard → Settings → Edge Functions → Secrets:**

Add:
```
STRIPE_SECRET_KEY=sk_test_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
```

---

## Step 3: Backend - Verify Purchase (2 hours)

### 3.1 Create Verification Endpoint

**File**: `supabase/functions/verify-web-purchase/index.ts`

```typescript
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
      return errorResponse('session_id required', 400);
    }

    // Retrieve session from Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    // Verify session belongs to this user
    if (session.client_reference_id !== user.id) {
      return errorResponse('Session does not belong to user', 403);
    }

    // Verify payment status
    if (session.payment_status !== 'paid') {
      return errorResponse('Payment not completed', 400);
    }

    // Extract metadata
    const productKey = session.metadata?.product_key;
    if (!productKey) {
      return errorResponse('Invalid session metadata', 400);
    }

    // Use payment_intent as transaction ID
    const transactionId = session.payment_intent as string;

    // Fulfill purchase
    const result = await fulfillPurchase(admin, {
      userId: user.id,
      productKey,
      transactionId,
      platform: 'web',
      receiptData: sessionId,
      verificationResponse: session,
      pricePaidUsd: (session.amount_total || 0) / 100, // Convert cents to dollars
      currencyCode: session.currency?.toUpperCase() || 'USD',
    });

    if (result.alreadyFulfilled) {
      return jsonResponse({
        success: true,
        message: 'Purchase already fulfilled',
        receipt_id: result.receiptId,
      });
    }

    return jsonResponse({
      success: true,
      receipt_id: result.receiptId,
    });
  } catch (error) {
    console.error('verify-web-purchase error:', error);
    return errorResponse('Verification failed', 500);
  }
});
```

### 3.2 Create Webhook Handler

**File**: `supabase/functions/stripe-webhook/index.ts`

```typescript
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
  const signature = req.headers.get('stripe-signature');
  if (!signature) {
    return new Response('No signature', { status: 400 });
  }

  try {
    const body = await req.text();
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
    );

    const admin = getSupabaseAdmin();

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;

        // Extract metadata
        const userId = session.client_reference_id;
        const productKey = session.metadata?.product_key;
        const transactionId = session.payment_intent as string;

        if (!userId || !productKey || !transactionId) {
          console.error('Missing metadata in checkout session');
          break;
        }

        // Fulfill purchase
        await fulfillPurchase(admin, {
          userId,
          productKey,
          transactionId,
          platform: 'web',
          receiptData: session.id,
          verificationResponse: session,
          pricePaidUsd: (session.amount_total || 0) / 100,
          currencyCode: session.currency?.toUpperCase() || 'USD',
        });

        console.log('Purchase fulfilled via webhook:', transactionId);
        break;
      }

      case 'invoice.paid': {
        // Handle subscription renewals
        const invoice = event.data.object as Stripe.Invoice;
        const subscriptionId = invoice.subscription as string;

        // TODO: Implement monthly grant for subscription renewals
        console.log('Subscription renewed:', subscriptionId);
        break;
      }

      default:
        console.log('Unhandled event type:', event.type);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response('Webhook error', { status: 400 });
  }
});
```

---

## Step 4: Flutter Web Payment Service (3 hours)

### 4.1 Add Stripe Dependency

**File**: `apps/flutter_app/pubspec.yaml`

```yaml
dependencies:
  # ... existing dependencies
  url_launcher: ^6.3.1  # For redirecting to Stripe
```

### 4.2 Create Web Payment Service

**File**: `packages/monetization/lib/src/services/web_payment_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_service.dart';

class WebPaymentService implements PaymentService {
  final SupabaseClient _supabase;

  WebPaymentService(this._supabase);

  @override
  Future<void> initialize() async {
    // No initialization needed for web
  }

  @override
  Future<PurchaseResult> purchaseProduct(String productKey) async {
    return _createCheckoutSession(productKey);
  }

  @override
  Future<PurchaseResult> purchaseSubscription(String productKey) async {
    return _createCheckoutSession(productKey);
  }

  Future<PurchaseResult> _createCheckoutSession(String productKey) async {
    // Get current URL for success/cancel redirects
    final currentUrl = Uri.base.toString();
    final successUrl = '$currentUrl?payment_success=true&session_id={CHECKOUT_SESSION_ID}';
    final cancelUrl = '$currentUrl?payment_cancelled=true';

    // Create checkout session
    final response = await _supabase.functions.invoke(
      'create-stripe-checkout',
      body: {
        'product_key': productKey,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to create checkout session');
    }

    final data = response.data as Map<String, dynamic>;
    final checkoutUrl = data['url'] as String;
    final sessionId = data['session_id'] as String;

    // Redirect to Stripe Checkout
    final uri = Uri.parse(checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } else {
      throw Exception('Could not launch Stripe checkout');
    }

    return PurchaseResult(
      transactionId: sessionId,
      productId: productKey,
      status: PurchaseStatus.pending,
    );
  }

  /// Call this when user returns from Stripe
  Future<bool> verifyPurchase(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'verify-web-purchase',
      body: {'session_id': sessionId},
    );

    if (response.status != 200) {
      return false;
    }

    final data = response.data as Map<String, dynamic>;
    return data['success'] == true;
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    // Web doesn't support restore purchases
    return [];
  }

  @override
  Future<void> completePurchase(String transactionId) async {
    // Auto-completed by webhook
  }

  @override
  Future<List<StoreProduct>> getProducts(List<String> productIds) async {
    // Get from database instead of store
    final response = await _supabase
        .from('products')
        .select('*')
        .in_('product_key', productIds)
        .eq('is_active', true);

    return (response as List).map((p) => StoreProduct(
      id: p['product_key'],
      title: p['display_name'],
      description: p['description'] ?? '',
      price: '\$${p['price_usd']}',
      priceAmount: (p['price_usd'] as num).toDouble(),
      currencyCode: 'USD',
    )).toList();
  }
}
```

---

## Step 5: Wire Shop UI for Web Payments (2 hours)

### 5.1 Update Gem Pack Purchase Flow

**File**: `apps/flutter_app/lib/features/shop/presentation/shop_screen.dart`

```dart
// In _GemPacksTab
Future<void> _handleGemPackPurchase(
  BuildContext context,
  WidgetRef ref,
  String productKey,
) async {
  final paymentService = ref.read(paymentServiceProvider);

  try {
    // Initiate purchase (redirects to Stripe)
    await paymentService.purchaseProduct(productKey);

    // User will be redirected to Stripe, then back to app
    // Handle return in main.dart
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    }
  }
}
```

### 5.2 Handle Return from Stripe

**File**: `apps/flutter_app/lib/app/app.dart`

```dart
class MyApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _handlePaymentReturn();
  }

  Future<void> _handlePaymentReturn() async {
    // Check URL params on web
    if (kIsWeb) {
      final uri = Uri.base;
      final sessionId = uri.queryParameters['session_id'];

      if (sessionId != null) {
        // Verify purchase
        final paymentService = ref.read(paymentServiceProvider) as WebPaymentService;
        final success = await paymentService.verifyPurchase(sessionId);

        if (success) {
          // Refresh balance
          ref.invalidate(currencyBalanceProvider);

          // Show success message
          // (use a global key or messenger)
        }

        // Clean URL (remove params)
        // window.history.replaceState({}, '', '/');
      }
    }
  }

  // ... rest of app
}
```

---

## Step 6: Deploy & Test (1 hour)

### 6.1 Deploy Edge Functions

```bash
# Deploy all three functions
supabase functions deploy create-stripe-checkout --project-ref toqtbqmhxmemixaumljz
supabase functions deploy verify-web-purchase --project-ref toqtbqmhxmemixaumljz
supabase functions deploy stripe-webhook --project-ref toqtbqmhxmemixaumljz
```

### 6.2 Configure Stripe Webhook

1. Go to: https://dashboard.stripe.com/test/webhooks
2. Click "Add endpoint"
3. Endpoint URL: `https://toqtbqmhxmemixaumljz.supabase.co/functions/v1/stripe-webhook`
4. Select events:
   - `checkout.session.completed`
   - `invoice.paid`
5. Save and copy webhook secret to Supabase secrets

### 6.3 Test Purchase Flow

1. Run Flutter web app: `flutter run -d chrome --dart-define=ENV=staging`
2. Go to Shop → Gem Packs
3. Click "Buy" on starter pack ($0.99)
4. Should redirect to Stripe Checkout
5. Use test card: `4242 4242 4242 4242`, any future date, any CVC
6. Complete payment
7. Should redirect back to app
8. Verify:
   - Gems added to balance
   - Purchase receipt in database
   - Webhook received (check Stripe dashboard)

---

## Success Criteria

- ✅ User can click "Buy Gems" on web
- ✅ Redirects to Stripe Checkout
- ✅ Can complete test payment
- ✅ Redirects back to app
- ✅ Gems credited to account
- ✅ Balance updates in UI
- ✅ Webhook processes successfully
- ✅ Subscription renewals work (test with accelerated billing)

---

## Files to Create

1. `supabase/functions/create-stripe-checkout/index.ts`
2. `supabase/functions/verify-web-purchase/index.ts`
3. `supabase/functions/stripe-webhook/index.ts`
4. `packages/monetization/lib/src/services/web_payment_service.dart`

## Files to Update

1. `apps/flutter_app/pubspec.yaml` - Add url_launcher
2. `apps/flutter_app/lib/features/shop/presentation/shop_screen.dart` - Wire purchases
3. `apps/flutter_app/lib/app/app.dart` - Handle return from Stripe

---

## Next Steps

After Phase 2 complete:
- **Phase 3**: iOS StoreKit integration
- **Phase 4**: Android Play Billing integration
- **Phase 5**: Production launch with monitoring
