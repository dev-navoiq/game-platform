# RevenueCat Setup Guide (iOS + Android in-app purchases)

Web purchases go through Stripe (see `PAYMENT-MIGRATION-GUIDE.md`). iOS and
Android **must** use App Store / Play Store billing for digital goods — Apple
and Google reject apps that use Stripe for gems/subscriptions. RevenueCat wraps
both stores and validates receipts for us.

## How the pieces fit

```
Device                         RevenueCat                Supabase
──────                         ──────────                ────────
Purchases.logIn(supabaseUid)
Purchases.purchaseStoreProduct ─▶ validates with Apple/Google
        │                             │
        │  transaction id             ├─ webhook ─────▶ verify-subscription
        ▼                             │                 (fulfillPurchase)
verify-native-purchase ──────────────▶ GET /v1/subscribers/{uid}
        (fulfillPurchase)             (confirms purchase belongs to user)
```

Both server paths call the same `fulfillPurchase` keyed on the **store
transaction id**, so whichever arrives first credits the wallet and the other
is a no-op. The client path gives instant UX; the webhook is the safety net
(and the only path for renewals, cancellations, expirations).

Code:
- `apps/flutter_app/lib/core/services/real_revenue_cat.dart` — SDK wrapper
- `apps/flutter_app/lib/core/services/native_purchase_service.dart` — flow
- `supabase/functions/verify-native-purchase/` — client verification
- `supabase/functions/verify-subscription/` — RevenueCat webhook
- `supabase/functions/_shared/revenuecat.ts` — REST helpers

## Product IDs (must match exactly everywhere)

These are already seeded in the `products` table (`ios_product_id` /
`android_product_id`). Create them with **these exact IDs** in both stores.

| product_key       | Store product ID                  | Type           | Price  |
|-------------------|-----------------------------------|----------------|--------|
| `gem_starter`     | `com.navoiq.gathr.gems_100`       | Consumable     | $0.99  |
| `gem_popular`     | `com.navoiq.gathr.gems_500`       | Consumable     | $3.99  |
| `gem_value`       | `com.navoiq.gathr.gems_1200`      | Consumable     | $7.99  |
| `gem_premium`     | `com.navoiq.gathr.gems_3000`      | Consumable     | $19.99 |
| `gem_ultimate`    | `com.navoiq.gathr.gems_7500`      | Consumable     | $49.99 |
| `sub_pro_monthly` | `com.navoiq.gathr.pro_monthly`    | Auto-renewing  | $3.99/mo |
| `sub_max_monthly` | `com.navoiq.gathr.max_monthly`    | Auto-renewing  | $7.99/mo |

Bundle / application id: `app.navoiq.gameplatform`.

## 1. App Store Connect (iOS) — ✅ DONE (2026-09-20)

All 7 products exist under `app.navoiq.gameplatform` (app id `6773972441`),
created via `scripts/asc/create_iap_products.py` using an App Store Connect
API key (App Manager role, key id `8MDL92J6J5`, referenced from
`apps/flutter_app/ios/fastlane/Fastfile`). Each has localization, USA pricing
(auto-equalized to all 175 territories), and full availability. State shows
`MISSING_METADATA` — that's expected; it only means a review screenshot is
missing, which is **not required for sandbox/TestFlight testing**, only for
submitting to App Review. Before that submission, add one review screenshot
per product (App Store Connect → the product → App Review Information).

The script is idempotent — re-run it any time (e.g. after adding more
products to the `products` table) and it only creates what's missing:
```bash
python3 scripts/asc/create_iap_products.py
```

Remaining manual steps (no ASC API for these):
1. **Agreements, Tax, and Banking** → confirm the *Paid Apps* agreement is
   Active (purchases won't work at all otherwise, even in sandbox).
2. **Users and Access → Sandbox → Testers** → add a sandbox Apple ID for
   testing. On the device: Settings → App Store → Sandbox Account.
3. Copy the **App-Specific Shared Secret** (App → General → App
   Information → Manage) — RevenueCat needs it for receipt validation.
   (The `.p8` API key above is App Manager scope for *managing* products;
   RevenueCat separately wants this shared secret for *validating* receipts.)

## 2. Google Play Console (Android)

1. Upload at least one build to the **Internal testing** track — Play Billing
   products can't be tested until the app exists on a track.
2. **Monetize → Products → In-app products** → create the 5 consumables.
3. **Monetize → Products → Subscriptions** → create `pro_monthly` and
   `max_monthly` with product IDs from the table, one base plan each
   (monthly, auto-renewing). Base plan id suggestion: `monthly`.
4. **Setup → API access** → link a Google Cloud project and create a service
   account with *Finance* + *View app information* permissions. Download its
   JSON key — RevenueCat needs it.
5. **Setup → License testing** → add tester Gmail accounts so purchases are
   free/sandboxed for them.

## 3. RevenueCat dashboard

Create **one project per environment** (e.g. `Gathr Staging`, `Gathr Prod`)
so sandbox and live data never mix.

1. **Project settings → Apps** → add an *App Store* app (bundle id, shared
   secret, App Store Connect API key) and a *Play Store* app (package name,
   service-account JSON).
2. **Products** → import from the stores (or add manually) — all 7 IDs.
3. **Entitlements** → create exactly two, with these identifiers:
   - `pro` → attach `com.navoiq.gathr.pro_monthly` (iOS + Android)
   - `max` → attach `com.navoiq.gathr.max_monthly` (iOS + Android)
   The app maps entitlement id → tier (`SubscriptionService.tierForEntitlements`).
   Gem packs are consumables and don't get entitlements.
4. **Offerings** → optional for now; the app fetches products by id directly.
5. **API keys** → copy the two *public* SDK keys (`appl_…`, `goog_…`) and one
   *secret* key (`sk_…`, v1 API access). The secret key is server-only.
6. **Integrations → Webhooks** → add:
   - URL: `https://toqtbqmhxmemixaumljz.supabase.co/functions/v1/verify-subscription`
     (prod: `https://obtgysfcyenbfouvfixs.supabase.co/functions/v1/verify-subscription`)
   - Authorization header value: `Bearer <long random string>` — generate with
     `openssl rand -hex 32`. Keep the string; it's the webhook secret below.
   - Events: leave all enabled. Use the *Send test event* button after deploy.

## 4. Supabase secrets

```bash
supabase secrets set \
  REVENUECAT_SECRET_KEY='sk_...' \
  REVENUECAT_WEBHOOK_SECRET='<the random string, WITHOUT the "Bearer " prefix>' \
  --project-ref toqtbqmhxmemixaumljz
```

Then (re)deploy so the functions see them:

```bash
supabase functions deploy verify-native-purchase --project-ref toqtbqmhxmemixaumljz --no-verify-jwt
supabase functions deploy verify-subscription   --project-ref toqtbqmhxmemixaumljz --no-verify-jwt
```

`--no-verify-jwt` is required: the webhook carries RevenueCat's secret, not a
Supabase JWT, and `verify-native-purchase` authenticates the user itself via
`requireAuth()`.

## 5. Build the app with the public keys

The SDK keys are passed at build time (no key → `MockRevenueCat`, purchases
show "not configured"):

```bash
fvm flutter run --release -d <device> \
  --dart-define=ENV=staging \
  --dart-define=REVENUECAT_IOS_KEY=appl_xxx \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
```

Add the same two defines to the release scripts / CI for staging and prod
(different keys per RevenueCat project).

## 6. Sandbox test checklist

1. Sign in to the app → RevenueCat *Customers* should show a customer whose
   id is the Supabase user uuid (identity sync runs on auth change).
2. Shop → buy Starter Pack with a sandbox account → gems +100 within a second
   (client path). RevenueCat → customer → *Non-subscription purchases* lists it.
3. `select * from purchase_receipts order by created_at desc limit 5;` →
   one row, `platform = ios|android`, `status = verified`, `fulfilled_at` set.
4. Webhook delivery for the same purchase (RevenueCat → Integrations →
   Webhooks → *Recent deliveries*) → 200, and **no second receipt row**
   (same `transaction_id`).
5. Subscribe to Pro → `profiles.subscription_tier = 'pro'`, +800 coins
   +80 gems, `subscription_history` row with `auto_renew_enabled = true`.
   Sandbox renewals fire every ~5 min (iOS) / ~5 min (Android test) → each
   `RENEWAL` webhook adds a new receipt + monthly grant.
6. Cancel in the store's sandbox UI → `CANCELLATION` webhook →
   `auto_renew_enabled = false`, tier unchanged; after the sandbox period ends
   → `EXPIRATION` → tier back to `free`.
7. Delete + reinstall the app, sign in, *Restore Purchases* → tier restored.

## Gotchas

- Consumables on iOS: StoreKit needs the purchase *finished* — RevenueCat does
  this automatically; don't set `purchasesAreCompletedBy: myApp`.
- Google subscription ids arrive as `product:basePlan`; the server strips the
  suffix (`baseStoreProductId`) before catalog lookup.
- Apple sets `original_transaction_id == transaction_id` on the first
  purchase; renewal detection compares the two (fixed in `purchase_fulfillment.ts`).
- RevenueCat retries non-2xx webhooks for hours. The receiver returns 200 for
  events it deliberately ignores (unknown product, unattributable user) and
  500 only for transient failures.
