#!/bin/bash
set -e

echo "═══════════════════════════════════════════════════════════"
echo "  Supabase Deployment Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Step 1: Upgrade CLI
echo "📦 Step 1: Upgrading Supabase CLI..."
echo "Current version: $(supabase --version 2>&1 | head -1)"
echo ""

if command -v brew &> /dev/null; then
  echo "Upgrading via Homebrew..."
  brew upgrade supabase
  echo "✅ CLI upgraded to: $(supabase --version 2>&1 | head -1)"
else
  echo "⚠️  Homebrew not found. Please install manually:"
  echo "   Visit: https://supabase.com/docs/guides/cli/getting-started"
  exit 1
fi
echo ""

# Step 2: Verify access token
echo "🔑 Step 2: Verifying access token..."
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

if supabase projects list > /dev/null 2>&1; then
  echo "✅ Access token is valid"
else
  echo "❌ Access token is invalid or expired"
  exit 1
fi
echo ""

# Step 3: Verify projects
echo "📊 Step 3: Available projects..."
supabase projects list
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "You can now deploy with:"
echo "  ./scripts/deploy-staging-v2.sh"
echo "  ./scripts/deploy-production.sh"
echo ""
