# Payment System Migration Guide

## Status Summary

### ✅ What's Built (Phase 1)
- **Database schema**: Products, purchase receipts, idempotency
- **Backend**: Purchase fulfillment helper, coin-based shop purchases
- **Ready**: Users can spend existing coins/gems on skins/themes

### ❌ What's Missing (Phases 2-4)
- **iOS payment verification**: No StoreKit integration yet
- **Android payment verification**: No Play Billing integration yet
- **Web payment verification**: No Stripe integration yet
- **Result**: Users CANNOT buy gems with real money yet
- **Result**: Users CANNOT subscribe to Pro/Max yet

## Local Migration (Apply Now)

### Method 1: Supabase Studio UI (Recommended)
1. Open: http://127.0.0.1:54323/project/default/sql/new
2. Copy contents of: `supabase/migrations/20260901000000_payment_system.sql`
3. Paste into SQL Editor
4. Click "Run" (or Cmd+Enter)

### Method 2: Update CLI and Reset (Alternative)
```bash
# Update Supabase CLI
brew upgrade supabase

# Reset database with all migrations (including new one)
supabase db reset
```

## Staging Migration

### Option A: Supabase Dashboard
1. Go to your staging project dashboard
2. Navigate to SQL Editor
3. Copy `supabase/migrations/20260901000000_payment_system.sql`
4. Paste and execute

### Option B: CLI Push (After linking project)
```bash
# Link to staging project (one-time)
supabase link --project-ref YOUR_STAGING_REF

# Push migrations
supabase db push
```

## Verification After Migration

Run this query in SQL Editor to verify:

```sql
-- Check new tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('products', 'purchase_receipts');

-- Check seed data
SELECT product_key, product_type, price_usd FROM products;
```

Expected output:
- 7 products total (5 gem packs + 2 subscriptions)
- gem_starter ($0.99), gem_popular ($3.99), etc.
- sub_pro_monthly ($3.99), sub_max_monthly ($7.99)

## Next Steps After Migration

### Immediate (Phase 1 Completion)
- [ ] Deploy `purchase-shop-item` edge function
- [ ] Wire Flutter shop UI for coin-based purchases
- [ ] Test buying skins with coins

### Future (Phases 2-4)
- [ ] Stripe integration (Web gem purchases)
- [ ] StoreKit 2 integration (iOS purchases)
- [ ] Play Billing integration (Android purchases)
- [ ] Subscription renewal webhooks

## Edge Function Deployment

After migration, deploy the shop purchase function:

```bash
# Deploy to local
supabase functions deploy purchase-shop-item --local

# Deploy to staging (after linking)
supabase functions deploy purchase-shop-item
```

## Troubleshooting

### Migration fails with "type already exists"
This is normal if re-running. The types are idempotent.

### Old CLI version errors
Update CLI: `brew upgrade supabase`

### Docker not running
```bash
open -a Docker
sleep 10
supabase start
```
