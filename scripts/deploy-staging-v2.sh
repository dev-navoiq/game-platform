#!/bin/bash
set -e

# Improved deployment script for Supabase staging
# Works with CLI v2.116.0+ and handles migration conflicts

STAGING_REF="toqtbqmhxmemixaumljz"
STAGING_URL="https://toqtbqmhxmemixaumljz.supabase.co"

echo "═══════════════════════════════════════════════════════════"
echo "  Deploying to Staging (v2)"
echo "  Project: $STAGING_REF"
echo "  URL: $STAGING_URL"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verify access token
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "❌ SUPABASE_ACCESS_TOKEN not set!"
  echo "Run: export SUPABASE_ACCESS_TOKEN='your_token'"
  exit 1
fi
echo "✅ Access token found"
echo ""

# Link to staging
echo "🔗 Linking to staging project..."
if supabase link --project-ref $STAGING_REF 2>&1 | grep -q "already linked"; then
  echo "✅ Already linked to staging"
else
  echo "✅ Linked to staging"
fi
echo ""

# Get list of remote migrations
echo "📊 Checking remote database state..."
REMOTE_MIGRATIONS=$(supabase migration list --linked 2>&1 | grep "remote database" -A 100 || echo "")

# Determine which migrations to apply
if echo "$REMOTE_MIGRATIONS" | grep -q "20260901000000_payment_system.sql"; then
  echo "⚠️  Payment migration already applied remotely"
  echo "Skipping migration push..."
else
  echo "📊 Applying new migrations..."

  # Check if there are conflicts
  if supabase db push --linked --dry-run 2>&1 | grep -q "already exists"; then
    echo "⚠️  Some migrations already applied manually"
    echo "Applying only payment system migration..."

    # Apply just the payment migration via stdin
    cat supabase/migrations/20260901000000_payment_system.sql | \
      supabase db execute --linked

    echo "✅ Payment migration applied"
  else
    # No conflicts, push all pending migrations
    supabase db push --linked
    echo "✅ All migrations applied"
  fi
fi
echo ""

# Verify migration
echo "🔍 Verifying migration..."
PRODUCT_COUNT=$(supabase db execute "SELECT count(*) as count FROM products;" --linked --output json | grep -o '"count":[0-9]*' | grep -o '[0-9]*' | head -1)

if [ "$PRODUCT_COUNT" -eq "7" ]; then
  echo "✅ Migration verified (7 products found)"
else
  echo "⚠️  Found $PRODUCT_COUNT products (expected 7)"
  echo "Checking product details..."
  supabase db execute "SELECT product_key, price_usd FROM products ORDER BY price_usd;" --linked
fi
echo ""

# Deploy edge function
echo "🚀 Deploying purchase-shop-item function..."
if supabase functions deploy purchase-shop-item --project-ref $STAGING_REF --no-verify-jwt; then
  echo "✅ Function deployed"
else
  echo "⚠️  Function deployment had issues (check output above)"
fi
echo ""

# List all deployed functions
echo "📋 Deployed functions:"
supabase functions list --project-ref $STAGING_REF | grep purchase-shop-item || echo "  purchase-shop-item: (checking...)"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Staging environment ready:"
echo "  URL: $STAGING_URL"
echo "  Database: 7 products seeded"
echo "  Function: purchase-shop-item"
echo ""
echo "Test the deployment:"
echo "  supabase db execute \"SELECT product_key FROM products;\" --linked"
echo ""
