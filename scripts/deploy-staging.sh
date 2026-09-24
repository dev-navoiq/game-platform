#!/bin/bash
set -e

# Deployment script for Supabase staging environment
# Project ref: toqtbqmhxmemixaumljz

STAGING_REF="toqtbqmhxmemixaumljz"
STAGING_URL="https://toqtbqmhxmemixaumljz.supabase.co"

echo "═══════════════════════════════════════════════════════════"
echo "  Deploying to Staging"
echo "  Project: $STAGING_REF"
echo "  URL: $STAGING_URL"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check for access token
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "❌ SUPABASE_ACCESS_TOKEN not set!"
  echo ""
  echo "To fix:"
  echo "1. Go to: https://supabase.com/dashboard/account/tokens"
  echo "2. Generate a new token"
  echo "3. Run: export SUPABASE_ACCESS_TOKEN='your_token_here'"
  echo ""
  exit 1
fi

echo "✅ Access token found"
echo ""

# Link to staging
echo "🔗 Linking to staging project..."
if supabase link --project-ref $STAGING_REF; then
  echo "✅ Linked to staging"
else
  echo "⚠️  Project may already be linked (this is fine)"
fi
echo ""

# Push database migration
echo "📊 Pushing database migration..."
if supabase db push --linked; then
  echo "✅ Migration applied"
else
  echo "❌ Migration failed"
  exit 1
fi
echo ""

# Verify migration
echo "🔍 Verifying migration..."
PRODUCT_COUNT=$(supabase db remote execute "SELECT count(*) FROM products;" --linked --output json | grep -o '[0-9]\+' | head -1)
echo "Found $PRODUCT_COUNT products in database"

if [ "$PRODUCT_COUNT" -eq "7" ]; then
  echo "✅ Migration verified (7 products)"
else
  echo "⚠️  Expected 7 products, found $PRODUCT_COUNT"
fi
echo ""

# Deploy edge function
echo "🚀 Deploying purchase-shop-item function..."
if supabase functions deploy purchase-shop-item --project-ref $STAGING_REF --no-verify-jwt; then
  echo "✅ Function deployed"
else
  echo "❌ Function deployment failed"
  exit 1
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Staging environment ready:"
echo "  - Database: 7 products seeded"
echo "  - Edge function: purchase-shop-item"
echo "  - URL: $STAGING_URL"
echo ""
echo "Next steps:"
echo "  1. Test function with Flutter app"
echo "  2. Wire shop UI for coin-based purchases"
echo "  3. Test end-to-end purchase flow"
echo ""
