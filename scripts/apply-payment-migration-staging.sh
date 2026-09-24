#!/bin/bash
set -e

echo "Applying payment system migration to staging..."

# Read the SQL file and execute it
cat supabase/migrations/20260901000000_payment_system.sql | \
  supabase db remote execute --linked

echo "Migration applied! Verifying..."

# Verify products were created
supabase db remote execute "SELECT product_key, price_usd FROM products ORDER BY price_usd;" --linked

echo "Done!"
