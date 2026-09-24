# Payment System Test Cases

**Commit**: `6103467` - Payment system Phase 1
**Scope**: Coin-based purchases (skins/themes) + Web Stripe checkout (gem packs)
**Platforms**: Web (full), iOS/Android (coin-based only)

---

## Prerequisites

### Local Environment Setup

1. **Start Docker Desktop**
2. **Start Supabase**:
   ```bash
   cd /path/to/game-platform-navoiq
   supabase start
   supabase functions serve
   ```

3. **Verify migration applied**:
   ```bash
   supabase db execute "SELECT count(*) FROM products;" --linked
   # Should return: 7 (5 gem packs + 2 subscriptions)
   ```

4. **Launch Flutter app**:
   ```bash
   cd apps/flutter_app
   flutter run -d macos --dart-define=ENV=development
   # Or for web:
   flutter run -d chrome --dart-define=ENV=development
   ```

---

## Test Accounts

Create test accounts with different coin balances:

```sql
-- Via Supabase Studio or psql
UPDATE profiles
SET coins = 10000, gems = 5000
WHERE id = 'your-test-user-id';
```

**Recommended test accounts**:
- **Rich user**: 10,000 coins, 5,000 gems
- **Poor user**: 100 coins, 0 gems
- **New user**: 0 coins, 0 gems (test insufficient funds)

---

## 1. Coin-Based Purchases (Card Skins)

### Test Case 1.1: Successful Purchase with Coins

**Platform**: All (iOS, Android, Web, macOS)

**Steps**:
1. Log in with test account (ensure 2000+ coins)
2. Navigate to Shop → Card Skins tab
3. Note current coin balance in header
4. Find a locked skin that costs coins (e.g., "Modern" - 2000 coins)
5. Click "Buy" button on the skin card

**Expected Results**:
- ✅ Loading indicator appears immediately
- ✅ Loading dismisses after ~1-2 seconds
- ✅ Green success snackbar: "✅ Purchased Modern for 2000 coins"
- ✅ Coin balance in header decreases by 2000
- ✅ Skin card shows green checkmark (owned)
- ✅ "Buy" button no longer visible on that skin
- ✅ Skin is now selectable and can be equipped

**Database Verification**:
```sql
-- Check currency transaction logged
SELECT * FROM currency_transactions
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC LIMIT 1;
-- Should show: amount = -2000, reason = 'shop_item_purchase'

-- Check ownership granted
SELECT * FROM user_skins
WHERE user_id = 'your-user-id';
-- Should include the purchased skin_id
```

---

### Test Case 1.2: Purchase with Insufficient Coins

**Steps**:
1. Log in with account that has < 500 coins
2. Navigate to Shop → Card Skins
3. Try to buy "Royal Red" skin (costs 500 coins)

**Expected Results**:
- ✅ Loading indicator appears
- ✅ Red error snackbar: "❌ Insufficient funds"
- ✅ Coin balance unchanged
- ✅ Skin remains locked
- ✅ No database transaction created

---

### Test Case 1.3: Duplicate Purchase Prevention

**Steps**:
1. Purchase a skin successfully (e.g., "Modern")
2. Note the skin shows as owned (checkmark)
3. Refresh the page/restart app
4. Skin should still show as owned
5. Try to purchase the same skin again

**Expected Results**:
- ✅ "Buy" button not visible on owned skins
- ✅ Owned skins persist across app restarts
- ✅ No way to accidentally buy the same skin twice

**Note**: If backend allows duplicate purchase attempt:
- ✅ Should return error: "⚠️ You already own this skin"
- ✅ No charge occurs

---

### Test Case 1.4: Network Failure Handling

**Steps**:
1. Start purchase process
2. Immediately disconnect WiFi/network (within 1 second of clicking Buy)
3. Wait for timeout

**Expected Results**:
- ✅ Loading indicator eventually dismisses
- ✅ Red error snackbar with network error message
- ✅ No charge occurs (idempotency protection)
- ✅ Can retry purchase when network restored

**Recovery Test**:
1. Reconnect network
2. Retry same purchase
3. Should complete successfully
4. Verify only charged once (check `currency_transactions` table)

---

## 2. Coin-Based Purchases (Room Themes)

### Test Case 2.1: Successful Theme Purchase with Gems

**Platform**: All

**Steps**:
1. Log in with account that has 1500+ gems
2. Navigate to Shop → Themes tab
3. Find "Neon Nights" theme (costs 1500 gems)
4. Note current gem balance
5. Click "Buy"

**Expected Results**:
- ✅ Loading indicator appears
- ✅ Success snackbar: "✅ Purchased Neon Nights for 1500 gems"
- ✅ Gem balance decreases by 1500
- ✅ Theme shows as owned
- ✅ Theme can be equipped immediately

**Database Verification**:
```sql
SELECT * FROM currency_transactions
WHERE user_id = 'your-user-id'
  AND currency_type = 'gems'
ORDER BY created_at DESC LIMIT 1;
-- Should show: amount = -1500, reason = 'shop_item_purchase'
```

---

### Test Case 2.2: Mixed Purchases (Coins + Gems)

**Steps**:
1. Buy 1 card skin with coins (e.g., 2000 coins)
2. Buy 1 theme with gems (e.g., 1500 gems)
3. Refresh app
4. Navigate back to Shop

**Expected Results**:
- ✅ Both purchases persist
- ✅ Coin balance decreased by 2000
- ✅ Gem balance decreased by 1500
- ✅ Both items show as owned
- ✅ Both items can be equipped

---

## 3. Web Gem Pack Purchases (Stripe Checkout)

**Platform**: Web only

**Prerequisites**:
- Stripe account configured in development mode
- Test API keys set in Supabase secrets
- `create-stripe-checkout` function deployed

### Test Case 3.1: Successful Gem Pack Purchase (Web)

**Steps**:
1. Open app in web browser (Chrome/Safari)
2. Log in with test account
3. Navigate to Shop → Gem Packs tab
4. Note current gem balance
5. Click "Buy" on "Popular Pack" (500 gems + 125 bonus = 625 total, $3.99)

**Expected Results**:
- ✅ Loading indicator appears
- ✅ Browser redirects to Stripe Checkout page
- ✅ Product shows: "Popular Gem Pack - $3.99"
- ✅ Can see 625 gems listed

**Checkout Flow**:
1. On Stripe page, enter test card:
   - Card: `4242 4242 4242 4242`
   - Expiry: Any future date (e.g., 12/30)
   - CVC: Any 3 digits (e.g., 123)
   - ZIP: Any 5 digits (e.g., 12345)
2. Click "Pay"

**Expected Results**:
- ✅ Payment processes successfully
- ✅ Redirects back to app with `?payment_success=true&session_id=...`
- ✅ App shows success message
- ✅ Gem balance increases by 625 (500 + 125 bonus)
- ✅ Gems available immediately for purchases

**Database Verification**:
```sql
-- Check purchase receipt created
SELECT * FROM purchase_receipts
WHERE user_id = 'your-user-id'
  AND status = 'verified'
ORDER BY created_at DESC LIMIT 1;
-- Should show: product_id for 'gem_popular', platform = 'web'

-- Check currency credited
SELECT * FROM currency_transactions
WHERE user_id = 'your-user-id'
  AND reason = 'gem_purchase'
ORDER BY created_at DESC LIMIT 1;
-- Should show: amount = 625, currency_type = 'gems'
```

---

### Test Case 3.2: Cancelled Checkout

**Steps**:
1. Click "Buy" on any gem pack
2. Redirected to Stripe Checkout
3. Click browser back button OR click "← Back" on Stripe page
4. Should return to app

**Expected Results**:
- ✅ Returns to Shop screen
- ✅ No charge occurs
- ✅ Gem balance unchanged
- ✅ Can retry purchase if desired

---

### Test Case 3.3: Declined Payment

**Steps**:
1. Click "Buy" on gem pack
2. On Stripe Checkout, use declined test card:
   - Card: `4000 0000 0000 0002` (generic decline)
3. Click "Pay"

**Expected Results**:
- ✅ Stripe shows "Your card was declined" error
- ✅ No redirect back to app
- ✅ User can enter different card
- ✅ No gems credited
- ✅ No purchase receipt created

---

### Test Case 3.4: Payment Already Completed (Idempotency)

**Setup**: This tests duplicate payment prevention.

**Steps**:
1. Complete a gem pack purchase successfully
2. Note the `session_id` from success URL
3. Manually navigate to: `https://yourapp.com/?payment_success=true&session_id=SAME_SESSION_ID`

**Expected Results**:
- ✅ App detects session already processed
- ✅ Shows "Payment already processed" or similar message
- ✅ No duplicate gem credit
- ✅ Only one `purchase_receipts` entry exists

---

## 3b. Native Purchases — iOS / Android (RevenueCat)

**Platform**: iOS and Android devices (not simulators for real purchases)

**Prerequisites** (see `.claude/REVENUECAT-SETUP-GUIDE.md`):
- Products created in App Store Connect / Play Console with the exact IDs
- RevenueCat project configured, entitlements `pro` and `max`
- Supabase secrets `REVENUECAT_SECRET_KEY` + `REVENUECAT_WEBHOOK_SECRET` set
- `verify-native-purchase` and `verify-subscription` deployed
- App built with `--dart-define=REVENUECAT_IOS_KEY=… --dart-define=REVENUECAT_ANDROID_KEY=…`
- iOS: sandbox tester signed in (Settings → App Store → Sandbox Account)
- Android: tester Gmail added under Play Console → License testing

### Test Case 3b.1: Identity Sync

**Steps**:
1. Fresh install, sign in with a test account
2. Open RevenueCat dashboard → Customers

**Expected Results**:
- ✅ A customer exists whose App User ID equals the Supabase user uuid
- ✅ Signing out and in as another user shows a second customer (not an alias)

---

### Test Case 3b.2: Successful Gem Pack Purchase (Native)

**Steps**:
1. Shop → Gem Packs → "Buy" on Starter Pack ($0.99)
2. Store sheet appears (sandbox) → confirm

**Expected Results**:
- ✅ Loading indicator while the store sheet is up
- ✅ Snackbar "Gems added to your wallet"
- ✅ Gem balance +100 without leaving the screen
- ✅ RevenueCat customer → Non-subscription purchases lists the product

**Database Verification**:
```sql
SELECT platform, transaction_id, status, fulfilled_at, price_paid_usd
FROM purchase_receipts WHERE user_id = 'your-user-id'
ORDER BY created_at DESC LIMIT 1;
-- platform = 'ios' | 'android', status = 'verified', fulfilled_at set

SELECT amount, reason FROM currency_transactions
WHERE user_id = 'your-user-id' AND reason = 'gem_purchase'
ORDER BY created_at DESC LIMIT 1;
-- amount = 100
```

---

### Test Case 3b.3: Cancelled Store Sheet

**Steps**:
1. "Buy" on any gem pack → dismiss the store sheet

**Expected Results**:
- ✅ Loading indicator disappears, **no** error snackbar
- ✅ Balance unchanged, no `purchase_receipts` row

---

### Test Case 3b.4: Webhook + Client Verify Don't Double-Credit

**Steps**:
1. Complete 3b.2
2. RevenueCat → Integrations → Webhooks → Recent deliveries → open the
   `NON_RENEWING_PURCHASE` event for that purchase

**Expected Results**:
- ✅ Delivery status 200
- ✅ Still exactly **one** `purchase_receipts` row for that `transaction_id`
- ✅ Exactly one `gem_purchase` currency transaction

**Replay check**: click "Resend" on the delivery → still one row, response 200.

---

### Test Case 3b.5: Subscribe to Pro

**Steps**:
1. Shop → "Upgrade to Pro" banner → Pro → Subscribe → confirm store sheet

**Expected Results**:
- ✅ Snackbar "Welcome to Pro!"
- ✅ Pro card shows CURRENT, Subscribe button hidden
- ✅ Ads stop between games
- ✅ +800 coins, +80 gems

**Database Verification**:
```sql
SELECT subscription_tier, subscription_expires_at FROM profiles WHERE id = 'your-user-id';
-- 'pro', expires ≈ now + sandbox period

SELECT tier, provider, is_active, auto_renew_enabled FROM subscription_history
WHERE user_id = 'your-user-id' ORDER BY started_at DESC LIMIT 1;
-- 'pro', 'apple' | 'google', true, true
```

---

### Test Case 3b.6: Sandbox Renewal

Sandbox subscriptions renew every ~5 minutes (iOS) / configurable (Android).

**Steps**:
1. After 3b.5, wait for one renewal
2. RevenueCat → webhook deliveries → `RENEWAL`

**Expected Results**:
- ✅ New `purchase_receipts` row (different `transaction_id`, same
  `original_transaction_id`)
- ✅ `profiles.subscription_expires_at` moved forward
- ✅ Another +800 coins / +80 gems (`subscription_monthly_grant`)

---

### Test Case 3b.7: Cancel, then Expire

**Steps**:
1. Cancel the sandbox subscription in the store (iOS: Settings → App Store →
   Sandbox Account → Manage; Android: Play Store → Subscriptions)
2. Watch webhook deliveries

**Expected Results**:
- ✅ `CANCELLATION` → `subscription_history.auto_renew_enabled = false`,
  **tier still `pro`** (paid period continues)
- ✅ After the sandbox period ends: `EXPIRATION` → `profiles.subscription_tier
  = 'free'`, history row `is_active = false`, ads return

---

### Test Case 3b.8: Upgrade Pro → Max

**Steps**:
1. While on Pro, Subscription screen → Max → Subscribe

**Expected Results**:
- ✅ Store shows an upgrade/proration sheet
- ✅ Tier becomes `max`, Max card shows CURRENT
- ✅ `PRODUCT_CHANGE` webhook → 200, one new receipt row

---

### Test Case 3b.9: Restore Purchases

**Steps**:
1. With an active subscription, delete the app, reinstall, sign in
2. Subscription screen → "Restore Purchases"

**Expected Results**:
- ✅ Snackbar "Purchases restored"; correct tier shown as CURRENT
- ✅ No extra currency granted (fulfillment is idempotent)
- ✅ With no purchases: snackbar "No purchases to restore"

---

### Test Case 3b.10: Unconfigured Build

**Steps**:
1. Build **without** the `REVENUECAT_*_KEY` defines, open Shop → Buy

**Expected Results**:
- ✅ Snackbar "In-app purchases are not configured for this build."
- ✅ Subscription screen shows the "not enabled in this build" banner
- ✅ No store sheet, no network calls to RevenueCat

---

### Test Case 3b.11: Product Missing in Store

**Steps**:
1. Temporarily change `ios_product_id` for `gem_starter` in the staging DB
   to a non-existent id → Buy Starter Pack

**Expected Results**:
- ✅ Snackbar "This item is not available in the store yet (…)"
- ✅ Restore the id afterwards

---

## 4. Error Handling & Edge Cases

### Test Case 4.1: App Restart During Purchase

**Steps**:
1. Click "Buy" on a skin
2. While loading indicator is visible, force-quit app (Cmd+Q or swipe away)
3. Relaunch app
4. Check coin balance and owned skins

**Expected Results**:
- ✅ If purchase completed: Coins debited, skin owned
- ✅ If purchase didn't complete: Coins unchanged, skin locked
- ✅ No "stuck" loading states
- ✅ No partial purchases (charge without ownership or vice versa)

---

### Test Case 4.2: Backend Function Unavailable

**Setup**: Stop edge functions:
```bash
# Stop functions server
pkill -f "supabase functions serve"
```

**Steps**:
1. Try to purchase a skin
2. Observe error handling

**Expected Results**:
- ✅ Loading indicator appears and eventually dismisses
- ✅ Red error snackbar with clear message
- ✅ No coin/gem deduction
- ✅ App remains stable (no crash)

**Cleanup**: Restart functions:
```bash
supabase functions serve
```

---

### Test Case 4.3: Invalid Asset Key

**Setup**: Manually try to purchase non-existent skin (requires code modification or API testing).

**Steps**:
1. Call `purchaseShopItem(assetKey: 'nonexistent_skin')`

**Expected Results**:
- ✅ Returns error: "Skin not found" or similar
- ✅ No charge occurs
- ✅ No ownership granted

---

## 5. State Management & UI Updates

### Test Case 5.1: Multi-Tab Sync (Web)

**Platform**: Web only

**Steps**:
1. Open app in two browser tabs, same user
2. In Tab 1: Note coin balance (e.g., 5000 coins)
3. In Tab 2: Purchase a skin for 2000 coins
4. Return to Tab 1, refresh or navigate within app

**Expected Results**:
- ✅ Tab 1 eventually shows updated balance (3000 coins)
- ✅ Purchased skin shows as owned in Tab 1
- ✅ No "stale" data after refresh

---

### Test Case 5.2: Owned Skins Persist

**Steps**:
1. Purchase 3 skins with coins
2. Log out
3. Log back in
4. Navigate to Shop → Card Skins

**Expected Results**:
- ✅ All 3 skins show as owned (checkmarks)
- ✅ Can equip any owned skin
- ✅ "Buy" button not shown on owned skins

---

### Test Case 5.3: Currency Balance Updates Immediately

**Steps**:
1. Note current balance: 10,000 coins
2. Purchase skin for 2,000 coins
3. Observe header currency display during and after purchase

**Expected Results**:
- ✅ Balance updates from 10,000 → 8,000 immediately after success
- ✅ No need to refresh page
- ✅ Balance persists across navigation

---

## 6. Performance & Reliability

### Test Case 6.1: Rapid Repeated Clicks

**Steps**:
1. Find a locked skin
2. Rapidly click "Buy" button 5 times in quick succession

**Expected Results**:
- ✅ Only one purchase occurs
- ✅ Only one loading dialog appears
- ✅ Button becomes unresponsive after first click (disabled or hidden)
- ✅ Only charged once (check `currency_transactions`)

---

### Test Case 6.2: Large Balance Purchase

**Setup**:
```sql
UPDATE profiles SET coins = 1000000 WHERE id = 'your-user-id';
```

**Steps**:
1. Purchase multiple skins in sequence (5-10 skins)
2. Observe UI performance and balance updates

**Expected Results**:
- ✅ All purchases complete successfully
- ✅ Balance updates correctly for each purchase
- ✅ No overflow errors or display issues
- ✅ Transaction log accurate

---

## 7. Database Integrity

### Test Case 7.1: Transaction Audit Trail

**Steps**:
1. Start with 10,000 coins
2. Purchase 3 skins: 2000, 1500, 500 coins
3. Query transaction log

**SQL**:
```sql
SELECT
  created_at,
  amount,
  reason,
  coins_after,
  reference_id
FROM currency_transactions
WHERE user_id = 'your-user-id'
  AND currency_type = 'coins'
ORDER BY created_at DESC;
```

**Expected Results**:
- ✅ 3 debit transactions: -2000, -1500, -500
- ✅ Timestamps in correct order
- ✅ `coins_after` values: 8000, 6500, 6000
- ✅ Each has `reason = 'shop_item_purchase'`
- ✅ Each has valid `reference_id` (points to `user_skins` record)

---

### Test Case 7.2: Ownership Records

**Steps**:
1. Purchase 2 card skins, 1 room theme
2. Query ownership table

**SQL**:
```sql
SELECT
  us.created_at,
  s.asset_key,
  s.skin_type
FROM user_skins us
JOIN skins s ON s.id = us.skin_id
WHERE us.user_id = 'your-user-id'
ORDER BY us.created_at DESC;
```

**Expected Results**:
- ✅ 3 records total
- ✅ Correct `asset_key` values
- ✅ Correct `skin_type` ('card_deck' or 'room_theme')
- ✅ Timestamps match purchase times

---

## 8. Staging Environment Tests

**Prerequisites**:
- Staging migration applied
- Edge functions deployed to staging
- App running with `--dart-define=ENV=staging`

### Test Case 8.1: Staging Coin Purchase

Repeat Test Case 1.1 on staging environment.

**Differences**:
- Uses staging Supabase project (`toqtbqmhxmemixaumljz`)
- Uses staging database
- Edge function URL: `https://toqtbqmhxmemixaumljz.supabase.co/functions/v1/purchase-shop-item`

**Verification**:
```bash
# Check staging database
supabase db execute "SELECT count(*) FROM user_skins;" --project-ref toqtbqmhxmemixaumljz
```

---

### Test Case 8.2: Staging Stripe Checkout

**Prerequisites**:
- Stripe test mode keys configured in staging Supabase secrets
- Webhook endpoint configured: `https://toqtbqmhxmemixaumljz.supabase.co/functions/v1/stripe-webhook`

Repeat Test Case 3.1 on staging.

**Expected Results**:
- ✅ Redirects to Stripe Checkout (test mode)
- ✅ Shows staging URL in browser
- ✅ Completes payment with test card
- ✅ Gems credited to staging database

---

## Test Summary Checklist

Use this checklist to track testing progress:

### Coin-Based Purchases
- [ ] 1.1 - Successful purchase with coins
- [ ] 1.2 - Insufficient funds error
- [ ] 1.3 - Duplicate purchase prevention
- [ ] 1.4 - Network failure handling
- [ ] 2.1 - Theme purchase with gems
- [ ] 2.2 - Mixed purchases (coins + gems)

### Web Stripe Checkout
- [ ] 3.1 - Successful gem pack purchase
- [ ] 3.2 - Cancelled checkout
- [ ] 3.3 - Declined payment
- [ ] 3.4 - Idempotency (duplicate session)

### Native iOS / Android (RevenueCat)
- [ ] 3b.1 - Identity sync (RevenueCat customer id = Supabase uuid)
- [ ] 3b.2 - Successful gem pack purchase
- [ ] 3b.3 - Cancelled store sheet
- [ ] 3b.4 - Webhook + client verify don't double-credit
- [ ] 3b.5 - Subscribe to Pro
- [ ] 3b.6 - Sandbox renewal
- [ ] 3b.7 - Cancel, then expire
- [ ] 3b.8 - Upgrade Pro → Max
- [ ] 3b.9 - Restore purchases
- [ ] 3b.10 - Unconfigured build
- [ ] 3b.11 - Product missing in store

### Error Handling
- [ ] 4.1 - App restart during purchase
- [ ] 4.2 - Backend unavailable
- [ ] 4.3 - Invalid asset key

### State Management
- [ ] 5.1 - Multi-tab sync (web)
- [ ] 5.2 - Owned skins persist
- [ ] 5.3 - Currency balance updates immediately

### Performance
- [ ] 6.1 - Rapid repeated clicks
- [ ] 6.2 - Large balance purchases

### Database
- [ ] 7.1 - Transaction audit trail
- [ ] 7.2 - Ownership records

### Staging
- [ ] 8.1 - Staging coin purchase
- [ ] 8.2 - Staging Stripe checkout

---

## Known Limitations (Current Phase)

Implemented but blocked on dashboard setup (see `REVENUECAT-SETUP-GUIDE.md`):

- ⏳ iOS / Android purchases — code complete, needs App Store Connect / Play
  Console products + RevenueCat project + secrets before 3b.x can run

NOT yet implemented:

- ❌ Refund handling (Stripe `charge.refunded`, RevenueCat `REFUND` events →
  claw back gems / mark receipt `refunded`)
- ❌ Stripe subscription management on web (customer portal / cancel)
- ❌ Localized store prices in the shop (currently shows USD from catalog)

---

## Reporting Issues

When reporting bugs, include:

1. **Platform**: iOS / Android / Web / macOS
2. **Environment**: Local / Staging / Production
3. **Test Case**: Which test case failed
4. **Steps to reproduce**
5. **Expected vs Actual behavior**
6. **Screenshots** (if UI-related)
7. **Database state** (query `currency_transactions`, `user_skins` if applicable)
8. **Console logs** (Flutter debug console or browser DevTools)

**Example Bug Report**:
```
Platform: Web
Environment: Local
Test Case: 1.1 - Successful coin purchase

Steps:
1. Logged in with 10,000 coins
2. Clicked Buy on "Modern" skin (2000 coins)
3. Loading appeared, then dismissed
4. No success message shown
5. Balance unchanged at 10,000 coins

Expected: Balance decreases to 8,000, skin becomes owned
Actual: No change occurred

Console Error:
Error: Failed to invoke function: 500 Internal Server Error

Database Query:
SELECT * FROM currency_transactions WHERE user_id = '...' ORDER BY created_at DESC LIMIT 1;
-- Returns no new transactions
```

---

## Useful Debug Commands

```bash
# Check Supabase status
supabase status

# Check if functions are running
ps aux | grep "supabase functions serve"

# Restart functions
pkill -f "supabase functions serve" && supabase functions serve

# View function logs (in separate terminal)
supabase functions serve

# Check products in database
supabase db execute "SELECT product_key, price_usd FROM products;" --linked

# Check user's currency balance
supabase db execute "SELECT coins, gems FROM profiles WHERE id = 'USER_ID';" --linked

# Check user's owned skins
supabase db execute "SELECT s.asset_key FROM user_skins us JOIN skins s ON s.id = us.skin_id WHERE us.user_id = 'USER_ID';" --linked

# View recent transactions
supabase db execute "SELECT * FROM currency_transactions WHERE user_id = 'USER_ID' ORDER BY created_at DESC LIMIT 10;" --linked
```

---

## Next Steps After Testing

Once all test cases pass:

1. **Deploy to staging** (already done via `scripts/deploy-staging-v2.sh`)
2. **Team UAT on staging**
3. **Fix any bugs discovered**
4. **Deploy to production** (use `scripts/deploy-production.sh`)
5. **Begin Phase 2**: Stripe production setup + iOS/Android integration

---

**Questions?** Contact the development team or check:
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Deployment guide
- [.claude/PLAN-FLUTTER-UI-WIRING.md](.claude/PLAN-FLUTTER-UI-WIRING.md) - Implementation details
- [.claude/PLAN-STRIPE-INTEGRATION.md](.claude/PLAN-STRIPE-INTEGRATION.md) - Stripe setup guide
