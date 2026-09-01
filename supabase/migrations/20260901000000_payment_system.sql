-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Payment System (Gem packs, Subscriptions, Coin-based Shop)
--
-- Implements server-side payment verification infrastructure for:
-- - iOS (StoreKit 2 with App Store Server API validation)
-- - Android (Google Play Billing v5+ with Play Developer API)
-- - Web (Stripe Checkout + webhooks)
-- - Coin-based soft currency purchases (skins, themes)
--
-- Security:
-- - Receipt validation happens server-side (edge functions)
-- - Idempotency enforced via unique transaction_id constraint
-- - All currency credits use existing credit_currency_atomic RPC
-- - Purchase receipts inserted BEFORE crediting to prevent race conditions
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

-- ── Enum Types ───────────────────────────────────────────────────────────────

create type product_type as enum ('gem_pack', 'subscription');
create type platform_type as enum ('ios', 'android', 'web', 'all');
create type receipt_status as enum ('pending', 'verified', 'failed', 'refunded');

-- ── Products Table ───────────────────────────────────────────────────────────
-- Central product catalog for all IAP products (gem packs + subscriptions)
-- Maps platform-specific product IDs to our internal product_key
-- ─────────────────────────────────────────────────────────────────────────────

create table products (
  id uuid primary key default uuid_generate_v4(),
  product_key text unique not null, -- Internal key: 'gem_starter', 'sub_pro_monthly'
  product_type product_type not null,
  platform platform_type not null,

  -- Platform-specific product IDs (stores require these for purchases)
  ios_product_id text, -- e.g. 'com.navoiq.gathr.gems_100'
  android_product_id text, -- typically same as iOS
  stripe_price_id text, -- e.g. 'price_xxx' from Stripe dashboard

  -- Display metadata
  display_name text not null,
  description text,

  -- Pricing (display only; actual price comes from stores)
  price_usd numeric(10,2) not null,

  -- Rewards (for gem packs only)
  gems_granted integer default 0 check (gems_granted >= 0),
  bonus_gems integer default 0 check (bonus_gems >= 0),

  -- Subscription metadata (for subscriptions only)
  subscription_tier subscription_tier,
  billing_period interval, -- e.g. '1 month'::interval

  -- Availability
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for fast product lookups during purchase flows
create index idx_products_key on products(product_key) where is_active = true;
create index idx_products_active on products(product_type, is_active) where is_active = true;
create index idx_products_ios on products(ios_product_id) where ios_product_id is not null and is_active = true;
create index idx_products_android on products(android_product_id) where android_product_id is not null and is_active = true;
create index idx_products_stripe on products(stripe_price_id) where stripe_price_id is not null and is_active = true;

-- ── Purchase Receipts Table ──────────────────────────────────────────────────
-- Audit trail and idempotency guard for ALL purchases
-- Each verified purchase gets exactly one receipt record
-- CRITICAL: unique(transaction_id) prevents duplicate credits
-- ─────────────────────────────────────────────────────────────────────────────

create table purchase_receipts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  product_id uuid not null references products(id),

  -- Platform and transaction tracking
  platform platform_type not null,
  transaction_id text not null, -- Store transaction ID (globally unique across all platforms)
  original_transaction_id text, -- For subscription renewals (links to original purchase)

  -- Receipt data (store-specific verification payload)
  receipt_data text, -- Base64 receipt (iOS), purchase token (Android), session_id (Stripe)

  -- Verification state
  status receipt_status not null default 'pending',
  verified_at timestamptz,
  verification_response jsonb, -- Store API response (for debugging)

  -- Fulfillment tracking
  fulfilled_at timestamptz,
  fulfillment_error text,

  -- Payment amounts
  price_paid_usd numeric(10,2),
  currency_code text default 'USD', -- ISO 4217 currency code

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- CRITICAL: Prevent duplicate credits for same transaction
-- If same transaction_id is submitted twice (network retry, user double-tap),
-- unique violation prevents second insert → edge function returns early
create unique index uq_purchase_transaction on purchase_receipts(transaction_id);

-- Indexes for user purchase history and subscription renewal tracking
create index idx_purchase_user on purchase_receipts(user_id, created_at desc);
create index idx_purchase_status on purchase_receipts(status) where status in ('pending', 'failed');
create index idx_purchase_original_txn on purchase_receipts(original_transaction_id)
  where original_transaction_id is not null;

-- ── Enhance Subscription History ────────────────────────────────────────────
-- Add optional columns for better subscription management
-- (safe to run multiple times via 'add column if not exists')
-- ─────────────────────────────────────────────────────────────────────────────

alter table subscription_history
  add column if not exists platform platform_type,
  add column if not exists product_id uuid references products(id),
  add column if not exists auto_renew_enabled boolean default true,
  add column if not exists grace_period_expires_at timestamptz,
  add column if not exists billing_issue_detected_at timestamptz;

-- ── Seed Data: Gem Packs ─────────────────────────────────────────────────────
-- Five gem pack tiers matching existing shop UI
-- Product IDs use reverse domain notation for iOS/Android consistency
-- ─────────────────────────────────────────────────────────────────────────────

insert into products (
  product_key, product_type, platform,
  ios_product_id, android_product_id, stripe_price_id,
  display_name, description, price_usd,
  gems_granted, bonus_gems, is_active
) values
  (
    'gem_starter', 'gem_pack', 'all',
    'com.navoiq.gathr.gems_100', 'com.navoiq.gathr.gems_100', 'price_gem_starter',
    'Starter Pack', '100 gems', 0.99,
    100, 0, true
  ),
  (
    'gem_popular', 'gem_pack', 'all',
    'com.navoiq.gathr.gems_500', 'com.navoiq.gathr.gems_500', 'price_gem_popular',
    'Popular Pack', '500 gems + 25% bonus', 3.99,
    500, 125, true
  ),
  (
    'gem_value', 'gem_pack', 'all',
    'com.navoiq.gathr.gems_1200', 'com.navoiq.gathr.gems_1200', 'price_gem_value',
    'Value Pack', '1200 gems + 50% bonus', 7.99,
    1200, 600, true
  ),
  (
    'gem_premium', 'gem_pack', 'all',
    'com.navoiq.gathr.gems_3000', 'com.navoiq.gathr.gems_3000', 'price_gem_premium',
    'Premium Pack', '3000 gems + 75% bonus', 19.99,
    3000, 2250, true
  ),
  (
    'gem_ultimate', 'gem_pack', 'all',
    'com.navoiq.gathr.gems_7500', 'com.navoiq.gathr.gems_7500', 'price_gem_ultimate',
    'Ultimate Pack', '7500 gems + 100% bonus', 49.99,
    7500, 7500, true
  );

-- ── Seed Data: Subscriptions ─────────────────────────────────────────────────
-- Pro and Max subscription tiers (monthly billing)
-- Monthly coin/gem grants handled by edge functions on renewal
-- ─────────────────────────────────────────────────────────────────────────────

insert into products (
  product_key, product_type, platform,
  ios_product_id, android_product_id, stripe_price_id,
  display_name, description, price_usd,
  subscription_tier, billing_period, is_active
) values
  (
    'sub_pro_monthly', 'subscription', 'all',
    'com.navoiq.gathr.pro_monthly', 'com.navoiq.gathr.pro_monthly', 'price_pro_monthly',
    'Pro Membership', 'No ads + 800 daily coins + priority support', 3.99,
    'pro', '1 month'::interval, true
  ),
  (
    'sub_max_monthly', 'subscription', 'all',
    'com.navoiq.gathr.max_monthly', 'com.navoiq.gathr.max_monthly', 'price_max_monthly',
    'Max Membership', 'Everything in Pro + 2500 daily coins + premium perks', 7.99,
    'max', '1 month'::interval, true
  );

-- ── RLS Policies ─────────────────────────────────────────────────────────────

-- Products: readable by all authenticated users (needed for shop UI)
alter table products enable row level security;

create policy "Products are readable by authenticated users"
  on products for select
  using (auth.role() = 'authenticated' and is_active = true);

-- Purchase receipts: users can only view their own receipts
alter table purchase_receipts enable row level security;

create policy "Users can view their own purchase receipts"
  on purchase_receipts for select
  using (auth.uid() = user_id);

-- Insert/update blocked for clients (edge functions use service role)
create policy "Purchase receipts are server-only for insert/update"
  on purchase_receipts for insert
  with check (false);

create policy "Purchase receipts are server-only for update"
  on purchase_receipts for update
  using (false);
