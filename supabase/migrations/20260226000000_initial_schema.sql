-- =============================================================================
-- Game Platform — Initial Schema
-- Migration: 20260226000000_initial_schema.sql
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────────────────────
create type game_type as enum (
  'twenty_nine', 'oh_hell', 'hearts', 'spades', 'bridge', 'rummy',
  'chess', 'ludo', 'sequence'
);

create type room_status as enum ('waiting', 'playing', 'finished', 'abandoned');

create type game_phase as enum ('waiting', 'bidding', 'playing', 'scoring', 'complete');

create type difficulty as enum ('easy', 'medium', 'hard', 'expert');

create type subscription_tier as enum ('free', 'pro', 'max');

create type skin_type as enum ('card_deck', 'room_background', 'avatar_frame', 'emote_pack');

-- Social mode enum (from product strategy Part 14)
create type room_social_mode as enum ('full', 'chat_only', 'silent', 'focus');

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER FUNCTION: updated_at trigger
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function update_updated_at_column()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: profiles
-- Extends auth.users. Auto-created via trigger on new user signup.
-- Includes product-strategy additions: xp, level, referral_code, etc.
-- ─────────────────────────────────────────────────────────────────────────────
create table profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  username             text unique not null,
  display_name         text,
  avatar_url           text,
  bio                  text,
  coins                integer not null default 0 check (coins >= 0),
  gems                 integer not null default 0 check (gems >= 0),
  subscription_tier    subscription_tier not null default 'free',
  subscription_expires_at timestamptz,
  -- XP & leveling (product strategy Part 9)
  xp                   integer not null default 0 check (xp >= 0),
  level                integer not null default 1 check (level >= 1),
  xp_to_next_level     integer not null default 100 check (xp_to_next_level > 0),
  -- Social mode preference (product strategy Part 14)
  preferred_social_mode room_social_mode not null default 'full',
  -- Referral (product strategy Part 10)
  referral_code        text unique,
  referred_by          uuid references profiles(id),
  -- Real-time presence (product strategy Part 4)
  current_activity     jsonb,
  -- Timestamps
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: game_rooms
-- ─────────────────────────────────────────────────────────────────────────────
create table game_rooms (
  id              uuid primary key default uuid_generate_v4(),
  code            text unique not null,
  game_type       game_type not null,
  status          room_status not null default 'waiting',
  -- Social mode (product strategy Part 14)
  social_mode     room_social_mode not null default 'full',
  created_by      uuid not null references profiles(id),
  max_players     integer not null check (max_players between 2 and 8),
  current_players integer not null default 0 check (current_players >= 0),
  is_private      boolean not null default false,
  password_hash   text,
  config          jsonb not null default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger game_rooms_updated_at
  before update on game_rooms
  for each row execute function update_updated_at_column();

create index idx_game_rooms_status   on game_rooms(status);
create index idx_game_rooms_type     on game_rooms(game_type);
create index idx_game_rooms_creator  on game_rooms(created_by);
create index idx_game_rooms_code     on game_rooms(code);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: room_players
-- ─────────────────────────────────────────────────────────────────────────────
create table room_players (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references game_rooms(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  seat_index  integer not null check (seat_index between 0 and 7),
  team        integer check (team in (0, 1)),
  is_ready    boolean not null default false,
  is_spectator boolean not null default false,
  joined_at   timestamptz not null default now(),
  unique (room_id, user_id),
  unique (room_id, seat_index)
);

create index idx_room_players_room on room_players(room_id);
create index idx_room_players_user on room_players(user_id);

-- Trigger: keep game_rooms.current_players in sync
create or replace function sync_room_player_count()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' and not new.is_spectator then
    update game_rooms set current_players = current_players + 1 where id = new.room_id;
  elsif tg_op = 'DELETE' and not old.is_spectator then
    update game_rooms set current_players = greatest(current_players - 1, 0) where id = old.room_id;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger room_players_count_sync
  after insert or delete on room_players
  for each row execute function sync_room_player_count();

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: game_states
-- ─────────────────────────────────────────────────────────────────────────────
create table game_states (
  id         uuid primary key default uuid_generate_v4(),
  room_id    uuid not null references game_rooms(id) on delete cascade,
  phase      game_phase not null default 'waiting',
  state_data jsonb not null default '{}',
  round      integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger game_states_updated_at
  before update on game_states
  for each row execute function update_updated_at_column();

create index idx_game_states_room on game_states(room_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: game_moves
-- ─────────────────────────────────────────────────────────────────────────────
create table game_moves (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references game_rooms(id) on delete cascade,
  player_id   uuid not null references profiles(id),
  move_type   text not null,
  move_data   jsonb not null default '{}',
  round       integer not null,
  sequence_no integer not null,
  created_at  timestamptz not null default now()
);

create index idx_game_moves_room_time on game_moves(room_id, created_at);
create index idx_game_moves_player    on game_moves(player_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: game_configs
-- Server-side tunables for hot-patching via Shorebird.
-- ─────────────────────────────────────────────────────────────────────────────
create table game_configs (
  id          uuid primary key default uuid_generate_v4(),
  game_type   game_type not null,
  config_key  text not null,
  config_value jsonb not null,
  description text,
  updated_at  timestamptz not null default now(),
  unique (game_type, config_key)
);

-- Seed: default configs
insert into game_configs (game_type, config_key, config_value, description) values
  ('oh_hell', 'max_cards', '7', 'Maximum cards dealt per round'),
  ('oh_hell', 'turn_timeout_seconds', '30', 'Seconds before auto-play'),
  ('twenty_nine', 'turn_timeout_seconds', '30', 'Seconds before auto-play'),
  ('chess', 'turn_timeout_seconds', '60', 'Seconds per move'),
  ('ludo', 'dice_count', '1', 'Number of dice per turn'),
  ('hearts', 'shoot_the_moon_enabled', 'true', 'Allow shoot the moon'),
  ('spades', 'nil_bid_enabled', 'true', 'Allow nil bidding');

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: leaderboards
-- ─────────────────────────────────────────────────────────────────────────────
create table leaderboards (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references profiles(id) on delete cascade,
  game_type     game_type not null,
  rating        integer not null default 1000,
  wins          integer not null default 0 check (wins >= 0),
  losses        integer not null default 0 check (losses >= 0),
  draws         integer not null default 0 check (draws >= 0),
  total_games   integer not null default 0 check (total_games >= 0),
  win_streak    integer not null default 0,
  best_streak   integer not null default 0,
  updated_at    timestamptz not null default now(),
  unique (user_id, game_type)
);

create index idx_leaderboards_user      on leaderboards(user_id, game_type);
create index idx_leaderboards_rating    on leaderboards(rating desc);
create index idx_leaderboards_game_type on leaderboards(game_type, rating desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: game_history
-- ─────────────────────────────────────────────────────────────────────────────
create table game_history (
  id           uuid primary key default uuid_generate_v4(),
  room_id      uuid references game_rooms(id),
  game_type    game_type not null,
  players      jsonb not null default '[]',
  winner_ids   uuid[] not null default '{}',
  final_scores jsonb not null default '{}',
  duration_seconds integer,
  replay_data  jsonb,
  played_at    timestamptz not null default now()
);

create index idx_game_history_played_at on game_history(played_at desc);
create index idx_game_history_game_type on game_history(game_type);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: chat_messages
-- ─────────────────────────────────────────────────────────────────────────────
create table chat_messages (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references game_rooms(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  content     text not null check (char_length(content) between 1 and 500),
  is_spectator_chat boolean not null default false,
  created_at  timestamptz not null default now()
);

create index idx_chat_messages_room_time on chat_messages(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: quick_reactions
-- ─────────────────────────────────────────────────────────────────────────────
create table quick_reactions (
  id         uuid primary key default uuid_generate_v4(),
  room_id    uuid not null references game_rooms(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  reaction   text not null,
  created_at timestamptz not null default now()
);

create index idx_quick_reactions_room on quick_reactions(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: mute_votes
-- Democratic muting — auto-mutes player when threshold is reached.
-- ─────────────────────────────────────────────────────────────────────────────
create table mute_votes (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references game_rooms(id) on delete cascade,
  voter_id    uuid not null references profiles(id) on delete cascade,
  target_id   uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (room_id, voter_id, target_id)
);

create index idx_mute_votes_room_target on mute_votes(room_id, target_id);

-- Trigger: auto-mute when >= 50% of players vote
create or replace function check_mute_threshold()
returns trigger language plpgsql as $$
declare
  v_vote_count integer;
  v_player_count integer;
begin
  select count(*) into v_vote_count
    from mute_votes
    where room_id = new.room_id and target_id = new.target_id;

  select current_players into v_player_count
    from game_rooms
    where id = new.room_id;

  if v_player_count > 0 and v_vote_count >= ceil(v_player_count::numeric / 2) then
    insert into moderation_log (room_id, moderator_id, target_id, action, reason)
    values (new.room_id, new.voter_id, new.target_id, 'mute', 'democratic_vote')
    on conflict do nothing;
  end if;

  return new;
end;
$$;

create trigger mute_votes_threshold_check
  after insert on mute_votes
  for each row execute function check_mute_threshold();

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: moderation_log
-- ─────────────────────────────────────────────────────────────────────────────
create table moderation_log (
  id           uuid primary key default uuid_generate_v4(),
  room_id      uuid references game_rooms(id) on delete cascade,
  moderator_id uuid references profiles(id),
  target_id    uuid not null references profiles(id) on delete cascade,
  action       text not null check (action in ('mute', 'unmute', 'kick', 'ban', 'warn')),
  reason       text,
  expires_at   timestamptz,
  created_at   timestamptz not null default now()
);

create index idx_moderation_log_target on moderation_log(target_id, created_at desc);
create index idx_moderation_log_room   on moderation_log(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: user_blocks
-- ─────────────────────────────────────────────────────────────────────────────
create table user_blocks (
  id          uuid primary key default uuid_generate_v4(),
  blocker_id  uuid not null references profiles(id) on delete cascade,
  blocked_id  uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id)
);

create index idx_user_blocks_blocker on user_blocks(blocker_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: friendships
-- ─────────────────────────────────────────────────────────────────────────────
create table friendships (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references profiles(id) on delete cascade,
  friend_id   uuid not null references profiles(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, friend_id)
);

create trigger friendships_updated_at
  before update on friendships
  for each row execute function update_updated_at_column();

create index idx_friendships_user   on friendships(user_id, status);
create index idx_friendships_friend on friendships(friend_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: skins
-- ─────────────────────────────────────────────────────────────────────────────
create table skins (
  id           uuid primary key default uuid_generate_v4(),
  name         text not null,
  skin_type    skin_type not null,
  price_coins  integer not null default 0 check (price_coins >= 0),
  price_gems   integer not null default 0 check (price_gems >= 0),
  preview_url  text,
  asset_key    text not null,
  is_premium   boolean not null default false,
  is_default   boolean not null default false,
  metadata     jsonb not null default '{}',
  created_at   timestamptz not null default now()
);

create index idx_skins_type on skins(skin_type);

-- Seed: default skins
insert into skins (name, skin_type, price_coins, price_gems, asset_key, is_default) values
  ('Classic', 'card_deck', 0, 0, 'cards/classic', true),
  ('Modern', 'card_deck', 500, 0, 'cards/modern', false),
  ('Minimal', 'card_deck', 500, 0, 'cards/minimal', false),
  ('Neon', 'card_deck', 0, 50, 'cards/neon', false),
  ('Casino', 'room_background', 0, 75, 'rooms/casino', false),
  ('Nature', 'room_background', 800, 0, 'rooms/nature', false),
  ('Space', 'room_background', 0, 100, 'rooms/space', false),
  ('Classic Table', 'room_background', 0, 0, 'rooms/classic', true),
  ('Gold Frame', 'avatar_frame', 0, 30, 'frames/gold', false);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: user_skins
-- ─────────────────────────────────────────────────────────────────────────────
create table user_skins (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references profiles(id) on delete cascade,
  skin_id     uuid not null references skins(id) on delete cascade,
  is_equipped boolean not null default false,
  acquired_at timestamptz not null default now(),
  unique (user_id, skin_id)
);

create index idx_user_skins_user on user_skins(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: subscription_history
-- ─────────────────────────────────────────────────────────────────────────────
create table subscription_history (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references profiles(id) on delete cascade,
  tier             subscription_tier not null,
  provider         text not null check (provider in ('apple', 'google', 'stripe')),
  transaction_id   text not null,
  started_at       timestamptz not null default now(),
  expires_at       timestamptz not null,
  is_active        boolean not null default true,
  price_usd        numeric(8, 2),
  created_at       timestamptz not null default now()
);

create index idx_subscription_history_user on subscription_history(user_id, started_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: currency_transactions
-- ─────────────────────────────────────────────────────────────────────────────
create table currency_transactions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references profiles(id) on delete cascade,
  currency     text not null check (currency in ('coins', 'gems')),
  amount       integer not null,
  balance_after integer not null,
  reason       text not null,
  reference_id uuid,
  created_at   timestamptz not null default now()
);

create index idx_currency_transactions_user on currency_transactions(user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: ad_impressions
-- ─────────────────────────────────────────────────────────────────────────────
create table ad_impressions (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references profiles(id) on delete set null,
  ad_type     text not null check (ad_type in ('banner', 'interstitial', 'rewarded', 'native', 'brand_skin')),
  placement   text not null,
  rewarded    boolean not null default false,
  reward_claimed boolean not null default false,
  created_at  timestamptz not null default now()
);

create index idx_ad_impressions_user_time on ad_impressions(user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: challenges (product strategy Part 7)
-- Daily & weekly challenge definitions.
-- ─────────────────────────────────────────────────────────────────────────────
create table challenges (
  id            uuid primary key default uuid_generate_v4(),
  title         text not null,
  description   text not null,
  challenge_type text not null check (challenge_type in ('daily', 'weekly')),
  game_type     game_type,
  target_value  integer not null check (target_value > 0),
  reward_coins  integer not null default 0 check (reward_coins >= 0),
  reward_xp     integer not null default 0 check (reward_xp >= 0),
  reward_gems   integer not null default 0 check (reward_gems >= 0),
  is_active     boolean not null default true,
  expires_at    timestamptz not null,
  created_at    timestamptz not null default now()
);

create index idx_challenges_type_expires on challenges(challenge_type, expires_at);
create index idx_challenges_active       on challenges(is_active, expires_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: user_challenges (product strategy Part 7)
-- ─────────────────────────────────────────────────────────────────────────────
create table user_challenges (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references profiles(id) on delete cascade,
  challenge_id    uuid not null references challenges(id) on delete cascade,
  progress        integer not null default 0 check (progress >= 0),
  completed_at    timestamptz,
  reward_claimed  boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, challenge_id)
);

create trigger user_challenges_updated_at
  before update on user_challenges
  for each row execute function update_updated_at_column();

create index idx_user_challenges_user     on user_challenges(user_id, challenge_id);
create index idx_user_challenges_unclaimed on user_challenges(user_id, reward_claimed) where completed_at is not null;

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: seasons (product strategy Part 6)
-- 30-day seasons with free and premium pass tracks.
-- ─────────────────────────────────────────────────────────────────────────────
create table seasons (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  start_date      timestamptz not null,
  end_date        timestamptz not null,
  pass_price_gems integer not null default 500 check (pass_price_gems >= 0),
  max_level       integer not null default 30,
  is_active       boolean not null default false,
  metadata        jsonb not null default '{}',
  created_at      timestamptz not null default now(),
  check (end_date > start_date)
);

create index idx_seasons_active on seasons(is_active);
create index idx_seasons_dates  on seasons(start_date, end_date);

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: user_season_progress (product strategy Part 6)
-- ─────────────────────────────────────────────────────────────────────────────
create table user_season_progress (
  id                    uuid primary key default uuid_generate_v4(),
  user_id               uuid not null references profiles(id) on delete cascade,
  season_id             uuid not null references seasons(id) on delete cascade,
  xp                    integer not null default 0 check (xp >= 0),
  level                 integer not null default 0 check (level >= 0),
  premium_purchased_at  timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (user_id, season_id)
);

create trigger user_season_progress_updated_at
  before update on user_season_progress
  for each row execute function update_updated_at_column();

create index idx_user_season_progress_user   on user_season_progress(user_id, season_id);
create index idx_user_season_progress_season on user_season_progress(season_id, level desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: referrals (product strategy Part 10)
-- Tracks referral chain and tier-based reward milestones.
-- ─────────────────────────────────────────────────────────────────────────────
create table referrals (
  id           uuid primary key default uuid_generate_v4(),
  referrer_id  uuid not null references profiles(id) on delete cascade,
  referee_id   uuid not null references profiles(id) on delete cascade,
  code_used    text not null,
  -- tier_reached: 1=install, 2=played 3 games, 3=reached level 5, 4=subscribed
  tier_reached integer not null default 1 check (tier_reached between 1 and 4),
  rewarded_at  timestamptz[],
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (referee_id)
);

create trigger referrals_updated_at
  before update on referrals
  for each row execute function update_updated_at_column();

create index idx_referrals_referrer on referrals(referrer_id);
create index idx_referrals_code     on referrals(code_used);

-- ─────────────────────────────────────────────────────────────────────────────
-- NEW TABLE: notification_preferences (product strategy Part 11)
-- 9 notification categories per user.
-- ─────────────────────────────────────────────────────────────────────────────
create table notification_preferences (
  user_id               uuid primary key references profiles(id) on delete cascade,
  -- 9 categories
  game_invites          boolean not null default true,
  friend_activity       boolean not null default true,
  turn_reminders        boolean not null default true,
  tournament_updates    boolean not null default true,
  challenge_reminders   boolean not null default true,
  season_events         boolean not null default true,
  daily_bonus           boolean not null default true,
  promotional           boolean not null default false,
  system_updates        boolean not null default true,
  -- Quiet hours (local time)
  quiet_hours_enabled   boolean not null default true,
  quiet_hours_start     time not null default '22:00',
  quiet_hours_end       time not null default '08:00',
  updated_at            timestamptz not null default now()
);

create trigger notification_preferences_updated_at
  before update on notification_preferences
  for each row execute function update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGER: auto-create profile + notification_preferences on new user signup
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public, extensions
as $$
declare
  v_username text;
  v_referral_code text;
begin
  -- Generate unique username from email (or 'guest' for anonymous users)
  v_username := coalesce(split_part(nullif(new.email, ''), '@', 1), 'guest') || '_' || substr(new.id::text, 1, 6);

  -- Generate unique 6-character referral code (alphanumeric uppercase)
  loop
    v_referral_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (select 1 from public.profiles where referral_code = v_referral_code);
  end loop;

  insert into public.profiles (id, username, display_name, referral_code)
  values (new.id, v_username, coalesce(new.raw_user_meta_data->>'full_name', v_username), v_referral_code);

  insert into public.notification_preferences (user_id)
  values (new.id);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────
alter table profiles                 enable row level security;
alter table game_rooms               enable row level security;
alter table room_players             enable row level security;
alter table game_states              enable row level security;
alter table game_moves               enable row level security;
alter table game_configs             enable row level security;
alter table leaderboards             enable row level security;
alter table game_history             enable row level security;
alter table chat_messages            enable row level security;
alter table quick_reactions          enable row level security;
alter table mute_votes               enable row level security;
alter table moderation_log           enable row level security;
alter table user_blocks              enable row level security;
alter table friendships              enable row level security;
alter table skins                    enable row level security;
alter table user_skins               enable row level security;
alter table subscription_history     enable row level security;
alter table currency_transactions    enable row level security;
alter table ad_impressions           enable row level security;
alter table challenges               enable row level security;
alter table user_challenges          enable row level security;
alter table seasons                  enable row level security;
alter table user_season_progress     enable row level security;
alter table referrals                enable row level security;
alter table notification_preferences enable row level security;

-- profiles
create policy "profiles_select_all" on profiles for select to authenticated using (true);
create policy "profiles_update_own" on profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- game_rooms
create policy "game_rooms_select_all" on game_rooms for select to authenticated using (true);
create policy "game_rooms_insert_own" on game_rooms for insert to authenticated with check (auth.uid() = created_by);
create policy "game_rooms_update_own" on game_rooms for update to authenticated using (auth.uid() = created_by);
create policy "game_rooms_delete_own" on game_rooms for delete to authenticated using (auth.uid() = created_by);

-- room_players
create policy "room_players_select_room_members" on room_players for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = room_players.room_id and rp.user_id = auth.uid()));
create policy "room_players_insert_own" on room_players for insert to authenticated with check (auth.uid() = user_id);
create policy "room_players_update_own" on room_players for update to authenticated using (auth.uid() = user_id);
create policy "room_players_delete_own" on room_players for delete to authenticated using (auth.uid() = user_id);

-- game_states — room members read, service role writes
create policy "game_states_select_room_members" on game_states for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = game_states.room_id and rp.user_id = auth.uid()));

-- game_moves — room members read
create policy "game_moves_select_room_members" on game_moves for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = game_moves.room_id and rp.user_id = auth.uid()));

-- game_configs — all authenticated users can read
create policy "game_configs_select_all" on game_configs for select to authenticated using (true);

-- leaderboards — all can read, own row managed
create policy "leaderboards_select_all" on leaderboards for select to authenticated using (true);
create policy "leaderboards_upsert_own" on leaderboards for insert to authenticated with check (auth.uid() = user_id);
create policy "leaderboards_update_own" on leaderboards for update to authenticated using (auth.uid() = user_id);

-- game_history — all authenticated can read
create policy "game_history_select_all" on game_history for select to authenticated using (true);

-- chat_messages — room members read, own insert
create policy "chat_messages_select_room" on chat_messages for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = chat_messages.room_id and rp.user_id = auth.uid()));
create policy "chat_messages_insert_own" on chat_messages for insert to authenticated with check (auth.uid() = user_id);

-- quick_reactions — room members read/insert
create policy "quick_reactions_select_room" on quick_reactions for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = quick_reactions.room_id and rp.user_id = auth.uid()));
create policy "quick_reactions_insert_own" on quick_reactions for insert to authenticated with check (auth.uid() = user_id);

-- mute_votes — room members
create policy "mute_votes_select_room" on mute_votes for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = mute_votes.room_id and rp.user_id = auth.uid()));
create policy "mute_votes_insert_own" on mute_votes for insert to authenticated with check (auth.uid() = voter_id);
create policy "mute_votes_delete_own" on mute_votes for delete to authenticated using (auth.uid() = voter_id);

-- moderation_log — room members read
create policy "moderation_log_select_room" on moderation_log for select to authenticated
  using (exists (select 1 from room_players rp where rp.room_id = moderation_log.room_id and rp.user_id = auth.uid())
         or auth.uid() = target_id);

-- user_blocks — own data only
create policy "user_blocks_select_own" on user_blocks for select to authenticated using (auth.uid() = blocker_id);
create policy "user_blocks_insert_own" on user_blocks for insert to authenticated with check (auth.uid() = blocker_id);
create policy "user_blocks_delete_own" on user_blocks for delete to authenticated using (auth.uid() = blocker_id);

-- friendships — own rows
create policy "friendships_select_own" on friendships for select to authenticated using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friendships_insert_own" on friendships for insert to authenticated with check (auth.uid() = user_id);
create policy "friendships_update_own" on friendships for update to authenticated using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friendships_delete_own" on friendships for delete to authenticated using (auth.uid() = user_id);

-- skins — all can read
create policy "skins_select_all" on skins for select to authenticated using (true);

-- user_skins — own data
create policy "user_skins_select_own" on user_skins for select to authenticated using (auth.uid() = user_id);
create policy "user_skins_insert_own" on user_skins for insert to authenticated with check (auth.uid() = user_id);
create policy "user_skins_update_own" on user_skins for update to authenticated using (auth.uid() = user_id);

-- subscription_history — own data
create policy "subscription_history_select_own" on subscription_history for select to authenticated using (auth.uid() = user_id);

-- currency_transactions — own data
create policy "currency_transactions_select_own" on currency_transactions for select to authenticated using (auth.uid() = user_id);

-- ad_impressions — own data
create policy "ad_impressions_select_own" on ad_impressions for select to authenticated using (auth.uid() = user_id);
create policy "ad_impressions_insert_own" on ad_impressions for insert to authenticated with check (auth.uid() = user_id);

-- challenges — all authenticated can read active challenges
create policy "challenges_select_active" on challenges for select to authenticated using (is_active = true);

-- user_challenges — own data
create policy "user_challenges_select_own" on user_challenges for select to authenticated using (auth.uid() = user_id);
create policy "user_challenges_upsert_own" on user_challenges for insert to authenticated with check (auth.uid() = user_id);
create policy "user_challenges_update_own" on user_challenges for update to authenticated using (auth.uid() = user_id);

-- seasons — all authenticated can read
create policy "seasons_select_all" on seasons for select to authenticated using (true);

-- user_season_progress — own data
create policy "user_season_progress_select_own" on user_season_progress for select to authenticated using (auth.uid() = user_id);
create policy "user_season_progress_upsert_own" on user_season_progress for insert to authenticated with check (auth.uid() = user_id);
create policy "user_season_progress_update_own" on user_season_progress for update to authenticated using (auth.uid() = user_id);

-- referrals — referrer reads own, referee reads own
create policy "referrals_select_own" on referrals for select to authenticated using (auth.uid() = referrer_id or auth.uid() = referee_id);
create policy "referrals_insert_own" on referrals for insert to authenticated with check (auth.uid() = referee_id);

-- notification_preferences — own data
create policy "notification_preferences_select_own" on notification_preferences for select to authenticated using (auth.uid() = user_id);
create policy "notification_preferences_update_own" on notification_preferences for update to authenticated using (auth.uid() = user_id);
