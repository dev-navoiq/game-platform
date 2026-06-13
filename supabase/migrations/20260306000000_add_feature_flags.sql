-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Add feature_flags table for dynamic feature toggling & A/B testing
-- Session 15: OTA Updates & Feature Flags
-- ─────────────────────────────────────────────────────────────────────────────

set search_path = public, extensions;

create table feature_flags (
  id                       uuid primary key default uuid_generate_v4(),
  flag_key                 text unique not null,
  display_name             text not null,
  description              text,

  -- Status
  enabled                  boolean not null default false,
  rollout_percentage       integer not null default 0
                           check (rollout_percentage >= 0 and rollout_percentage <= 100),

  -- A/B Testing
  variants                 jsonb,
  default_variant          text,

  -- Targeting
  target_user_ids          text[],
  exclude_user_ids         text[],
  target_subscription_tiers text[],
  target_platforms         text[],  -- 'ios', 'android', 'web'

  -- Scheduling
  start_at                 timestamptz,
  end_at                   timestamptz,

  -- Metadata
  is_active                boolean not null default true,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  created_by               uuid references profiles(id)
);

create index idx_feature_flags_key on feature_flags(flag_key);
create index idx_feature_flags_active on feature_flags(is_active) where is_active = true;

-- RLS
alter table feature_flags enable row level security;

create policy "Feature flags readable by all authenticated"
  on feature_flags for select
  to authenticated
  using (is_active = true);

-- Seed default flags
insert into feature_flags (flag_key, display_name, description, enabled, rollout_percentage) values
  ('voice_chat_enabled',            'Voice Chat',            'Enable voice chat feature',                    true,  100),
  ('animations_v2',                 'Animations V2',         'Enhanced animations system',                   true,  100),
  ('quick_matchmaking',             'Quick Matchmaking',     'Fast matchmaking queue',                       true,  100),
  ('social_features',               'Social Features',       'Chat, friends, reactions',                     true,  100),
  ('brand_skins',                   'Brand Skins',           'Show sponsored skins',                         true,  100),
  ('floating_chat_bubbles_enabled', 'Floating Chat Bubbles', 'Speech bubbles above player avatars',          true,  100),
  ('season_pass_enabled',           'Season Pass',           'Season pass feature (gradual rollout)',         false, 0),
  ('silent_rooms_enabled',          'Silent Rooms',          'Silent room social mode (gradual rollout)',     false, 0),
  ('referral_system_enabled',       'Referral System',       'Referral code viral loop',                     true,  100);

-- A/B test flag
insert into feature_flags (flag_key, display_name, description, enabled, rollout_percentage, variants, default_variant) values
  ('bid_timer_duration', 'Bid Timer Duration', 'A/B test for bid timer seconds', true, 100,
   '{"short": 20, "default": 30, "long": 45}', 'default');
