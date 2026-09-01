# Supabase Deployment Guide

Complete guide for deploying database migrations and edge functions via terminal.

## Quick Reference

```bash
# One-time setup (upgrade CLI + verify token)
./scripts/setup-deployment.sh

# Deploy to staging
./scripts/deploy-staging-v2.sh

# Deploy to production (requires confirmation)
./scripts/deploy-production.sh
```

---

## Prerequisites

### 1. Supabase CLI

**Check version:**
```bash
supabase --version
```

**Required:** v2.116.0 or later

**Upgrade:**
```bash
brew upgrade supabase
```

### 2. Access Token

**Get token:**
1. Visit: https://supabase.com/dashboard/account/tokens
2. Click "Generate new token"
3. Name it: `cli-deployment`
4. Copy token (starts with `sbp_`)

**Set token (temporary):**
```bash
export SUPABASE_ACCESS_TOKEN="sbp_your_token_here"
```

**Set token (permanent):**
```bash
echo 'export SUPABASE_ACCESS_TOKEN="sbp_your_token"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Verify Setup

```bash
supabase projects list
```

Should show:
- `gameplatform-staging` (toqtbqmhxmemixaumljz)
- `gameplatform-prod` (obtgysfcyenbfouvfixs)

---

## Deployment Workflows

### Staging Deployment (Safe)

Full automated deployment to staging:

```bash
./scripts/deploy-staging-v2.sh
```

**What it does:**
1. Links to staging project
2. Applies database migrations
3. Verifies products table (expects 7 products)
4. Deploys `purchase-shop-item` edge function
5. Lists deployed functions

**Expected output:**
```
✅ Access token found
✅ Linked to staging
✅ Migrations applied
✅ Migration verified (7 products found)
✅ Function deployed
```

### Production Deployment (Requires Confirmation)

```bash
./scripts/deploy-production.sh
```

**Safety features:**
- Requires typing "yes" twice
- Shows dry-run of changes before applying
- Confirms before deploying

---

## Manual Deployment Steps

If scripts fail, run commands individually:

### Staging

```bash
# 1. Link to project
supabase link --project-ref toqtbqmhxmemixaumljz

# 2. Apply migrations
supabase db push --linked

# 3. Verify
supabase db execute "SELECT product_key FROM products;" --linked

# 4. Deploy function
supabase functions deploy purchase-shop-item --project-ref toqtbqmhxmemixaumljz
```

### Production

```bash
# 1. Link to project
supabase link --project-ref obtgysfcyenbfouvfixs

# 2. Dry run first!
supabase db push --linked --dry-run

# 3. Apply migrations
supabase db push --linked

# 4. Deploy function
supabase functions deploy purchase-shop-item --project-ref obtgysfcyenbfouvfixs
```

---

## Troubleshooting

### "Access token not provided"

```bash
# Check if token is set
echo $SUPABASE_ACCESS_TOKEN | head -c 20

# If empty, set it:
export SUPABASE_ACCESS_TOKEN="sbp_your_token"

# Verify it works:
supabase projects list
```

### "Migration already exists" error

This happens when migrations were manually applied. Two solutions:

**Option 1: Apply only new migration**
```bash
cat supabase/migrations/20260901000000_payment_system.sql | \
  supabase db execute --linked
```

**Option 2: Use dashboard**
1. Go to: https://supabase.com/dashboard/project/toqtbqmhxmemixaumljz/sql/new
2. Copy migration file contents
3. Paste and run

### "Cannot find project ref"

This is normal before linking. Run:
```bash
supabase link --project-ref toqtbqmhxmemixaumljz
```

### CLI version too old

```bash
# Check version
supabase --version

# Should be v2.116.0+
# If older, upgrade:
brew upgrade supabase
```

### Function deployment fails

```bash
# Check function exists
ls -la supabase/functions/purchase-shop-item/

# Try with debug output
supabase functions deploy purchase-shop-item --project-ref toqtbqmhxmemixaumljz --debug

# Verify in dashboard
# https://supabase.com/dashboard/project/toqtbqmhxmemixaumljz/functions
```

---

## Verification Commands

### Check products table

```bash
supabase db execute "SELECT product_key, price_usd FROM products ORDER BY price_usd;" --linked
```

**Expected:** 7 rows (5 gem packs + 2 subscriptions)

### List deployed functions

```bash
supabase functions list --linked
```

**Should include:** `purchase-shop-item`

### Check migration history

```bash
supabase migration list --linked
```

**Should include:** `20260901000000_payment_system.sql`

---

## Project References

**Staging:**
- Project Ref: `toqtbqmhxmemixaumljz`
- URL: `https://toqtbqmhxmemixaumljz.supabase.co`
- Dashboard: https://supabase.com/dashboard/project/toqtbqmhxmemixaumljz

**Production:**
- Project Ref: `obtgysfcyenbfouvfixs`
- URL: `https://obtgysfcyenbfouvfixs.supabase.co`
- Dashboard: https://supabase.com/dashboard/project/obtgysfcyenbfouvfixs

---

## What Gets Deployed

### Database Migration: `20260901000000_payment_system.sql`

**New tables:**
- `products` - Product catalog (gem packs + subscriptions)
- `purchase_receipts` - Transaction audit trail

**Seed data:**
- 5 gem packs: starter ($0.99) → ultimate ($49.99)
- 2 subscriptions: pro ($3.99), max ($7.99)

**Enhancements:**
- `subscription_history` - Added platform, product_id columns

### Edge Function: `purchase-shop-item`

**Purpose:** Coin-based purchases for skins/themes

**Location:** `supabase/functions/purchase-shop-item/index.ts`

**Endpoint:** `https://{project-ref}.supabase.co/functions/v1/purchase-shop-item`

---

## Best Practices

1. **Always deploy to staging first**
2. **Test thoroughly on staging before production**
3. **Keep CLI updated** (`brew upgrade supabase`)
4. **Use dry-run before production** (`supabase db push --dry-run`)
5. **Verify after every deployment**

---

## Support

- CLI Docs: https://supabase.com/docs/guides/cli
- Discord: https://discord.supabase.com
- GitHub Issues: https://github.com/supabase/cli/issues
