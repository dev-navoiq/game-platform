#!/bin/bash
# Creates all Stripe products and prices for Gathr
# Usage: STRIPE_SECRET_KEY=sk_test_xxx ./scripts/create-stripe-products.sh

set -e

if [ -z "$STRIPE_SECRET_KEY" ]; then
  echo "Error: STRIPE_SECRET_KEY environment variable not set"
  echo "Usage: STRIPE_SECRET_KEY=sk_test_xxx ./scripts/create-stripe-products.sh"
  exit 1
fi

API="https://api.stripe.com/v1"
AUTH="Authorization: Bearer $STRIPE_SECRET_KEY"

echo "Creating Stripe products for Gathr..."
echo ""

# Function to create a one-time product with price
create_gem_pack() {
  local name=$1
  local price_cents=$2
  local product_key=$3
  local gems=$4
  local bonus=$5

  echo "Creating $name ($product_key)..."

  # Create product
  PRODUCT=$(curl -s -X POST "$API/products" \
    -H "$AUTH" \
    -d "name=$name" \
    -d "description=$gems gems + $bonus bonus gems" \
    -d "metadata[product_key]=$product_key" \
    -d "metadata[gems]=$gems" \
    -d "metadata[bonus_gems]=$bonus")

  PRODUCT_ID=$(echo $PRODUCT | grep -o '"id":"prod_[^"]*"' | head -1 | cut -d'"' -f4)

  # Create price
  PRICE=$(curl -s -X POST "$API/prices" \
    -H "$AUTH" \
    -d "product=$PRODUCT_ID" \
    -d "unit_amount=$price_cents" \
    -d "currency=usd")

  PRICE_ID=$(echo $PRICE | grep -o '"id":"price_[^"]*"' | head -1 | cut -d'"' -f4)

  echo "  Product: $PRODUCT_ID"
  echo "  Price: $PRICE_ID"
  echo ""

  # Output SQL
  echo "UPDATE products SET stripe_price_id = '$PRICE_ID' WHERE product_key = '$product_key';" >> /tmp/stripe_sql.txt
}

# Function to create a subscription product with recurring price
create_subscription() {
  local name=$1
  local price_cents=$2
  local product_key=$3
  local tier=$4

  echo "Creating $name ($product_key)..."

  # Create product
  PRODUCT=$(curl -s -X POST "$API/products" \
    -H "$AUTH" \
    -d "name=$name" \
    -d "description=Gathr $tier membership - monthly subscription" \
    -d "metadata[product_key]=$product_key" \
    -d "metadata[tier]=$tier")

  PRODUCT_ID=$(echo $PRODUCT | grep -o '"id":"prod_[^"]*"' | head -1 | cut -d'"' -f4)

  # Create recurring price
  PRICE=$(curl -s -X POST "$API/prices" \
    -H "$AUTH" \
    -d "product=$PRODUCT_ID" \
    -d "unit_amount=$price_cents" \
    -d "currency=usd" \
    -d "recurring[interval]=month")

  PRICE_ID=$(echo $PRICE | grep -o '"id":"price_[^"]*"' | head -1 | cut -d'"' -f4)

  echo "  Product: $PRODUCT_ID"
  echo "  Price: $PRICE_ID"
  echo ""

  # Output SQL
  echo "UPDATE products SET stripe_price_id = '$PRICE_ID' WHERE product_key = '$product_key';" >> /tmp/stripe_sql.txt
}

# Clear previous SQL output
> /tmp/stripe_sql.txt

echo "=== GEM PACKS ==="
echo ""

# Create gem packs (price in cents)
create_gem_pack "Starter Pack" 99 "gem_starter" 100 0
create_gem_pack "Popular Pack" 399 "gem_popular" 500 125
create_gem_pack "Value Pack" 799 "gem_value" 1200 600
create_gem_pack "Premium Pack" 1999 "gem_premium" 3000 2250
create_gem_pack "Ultimate Pack" 4999 "gem_ultimate" 7500 7500

echo "=== SUBSCRIPTIONS ==="
echo ""

# Create subscriptions
create_subscription "Pro Membership" 399 "sub_pro" "pro"
create_subscription "Max Membership" 799 "sub_max" "max"

echo "=== DONE ==="
echo ""
echo "SQL to update your database:"
echo "----------------------------"
cat /tmp/stripe_sql.txt
echo ""
echo "Run these SQL statements in Supabase SQL Editor to link products."
