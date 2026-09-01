#!/bin/bash
set -e

# Production deployment script
# USE WITH CAUTION - deploys to production database

PROD_REF="obtgysfcyenbfouvfixs"
PROD_URL="https://obtgysfcyenbfouvfixs.supabase.co"

echo "═══════════════════════════════════════════════════════════"
echo "  ⚠️  PRODUCTION DEPLOYMENT"
echo "  Project: $PROD_REF"
echo "  URL: $PROD_URL"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Safety confirmation
read -p "Are you sure you want to deploy to PRODUCTION? (type 'yes' to continue): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Deployment cancelled"
  exit 1
fi
echo ""

# Verify access token
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "❌ SUPABASE_ACCESS_TOKEN not set!"
  exit 1
fi
echo "✅ Access token found"
echo ""

# Link to production
echo "🔗 Linking to production project..."
supabase link --project-ref $PROD_REF
echo ""

# Show what will be deployed
echo "📊 Changes to be deployed:"
supabase db push --linked --dry-run
echo ""

read -p "Proceed with deployment? (type 'yes' to continue): " CONFIRM2
if [ "$CONFIRM2" != "yes" ]; then
  echo "❌ Deployment cancelled"
  exit 1
fi
echo ""

# Apply migrations
echo "📊 Applying migrations..."
supabase db push --linked
echo "✅ Migrations applied"
echo ""

# Verify
echo "🔍 Verifying..."
supabase db execute "SELECT count(*) FROM products;" --linked
echo ""

# Deploy function
echo "🚀 Deploying edge function..."
supabase functions deploy purchase-shop-item --project-ref $PROD_REF --no-verify-jwt
echo "✅ Function deployed"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Production Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
