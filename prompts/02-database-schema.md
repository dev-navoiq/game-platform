# 02 - Database Schema

> Create the complete Supabase database schema with tables, RLS policies, triggers, and seed data.

## Task

Create all database migrations for the game platform including:
- User profiles and authentication
- Game rooms and matchmaking
- Game state and move history
- Social features (chat, voice, moderation)
- Monetization (subscriptions, purchases, skins)
- Leaderboards and statistics

---

## Migration 001: Core Schema

Create `supabase/migrations/001_core_schema.sql`:

```sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE game_category AS ENUM ('card', 'board', 'dice');

CREATE TYPE game_type AS ENUM (
  -- Card games
  'twenty_nine', 'oh_hell', 'hearts', 'spades', 'bridge', 'rummy',
  -- Board games
  'chess', 'ludo', 'sequence',
  -- Future
  'custom'
);

CREATE TYPE room_status AS ENUM (
  'waiting',      -- Waiting for players
  'starting',     -- Game about to start
  'in_game',      -- Game in progress
  'paused',       -- Game paused (player disconnected)
  'finished',     -- Game completed
  'cancelled'     -- Room cancelled
);

CREATE TYPE game_phase AS ENUM (
  'setup',
  'dealing',
  'bidding',
  'trump_selection',
  'card_passing',
  'playing',
  'scoring',
  'round_end',
  'game_end'
);

CREATE TYPE bot_difficulty AS ENUM ('easy', 'medium', 'hard', 'expert');

CREATE TYPE subscription_tier AS ENUM ('free', 'pro', 'max');

CREATE TYPE skin_type AS ENUM ('card', 'room', 'board', 'avatar_frame', 'emote_pack');

CREATE TYPE ad_placement AS ENUM (
  'lobby_banner',
  'game_end_interstitial',
  'room_background',
  'card_back',
  'rewarded_coins'
);

CREATE TYPE moderation_action AS ENUM (
  'warn',
  'mute',
  'kick',
  'ban',
  'unmute',
  'unban'
);

CREATE TYPE voice_status AS ENUM ('connected', 'muted', 'deafened', 'disconnected');

-- ============================================
-- CORE TABLES
-- ============================================

-- User profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  country_code CHAR(2),

  -- Subscription
  subscription_tier subscription_tier DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,

  -- Currency
  coins INT DEFAULT 0 CHECK (coins >= 0),
  gems INT DEFAULT 0 CHECK (gems >= 0),

  -- Stats
  total_games_played INT DEFAULT 0,
  total_games_won INT DEFAULT 0,
  total_play_time_minutes INT DEFAULT 0,

  -- Settings
  sound_enabled BOOLEAN DEFAULT TRUE,
  music_enabled BOOLEAN DEFAULT TRUE,
  notifications_enabled BOOLEAN DEFAULT TRUE,

  -- Equipped cosmetics
  equipped_card_skin TEXT DEFAULT 'classic',
  equipped_room_skin TEXT DEFAULT 'classic',
  equipped_avatar_frame TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_online_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game rooms
CREATE TABLE game_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Game info
  game_type game_type NOT NULL,
  game_category game_category NOT NULL,

  -- Room settings
  room_code TEXT UNIQUE,
  is_private BOOLEAN DEFAULT FALSE,
  max_players INT NOT NULL CHECK (max_players >= 2 AND max_players <= 8),
  current_player_count INT DEFAULT 0,

  -- Host
  host_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

  -- Status
  status room_status DEFAULT 'waiting',

  -- Game settings (JSON for flexibility)
  settings JSONB DEFAULT '{}',

  -- Cosmetics (brand skin for room)
  room_skin TEXT DEFAULT 'classic',
  card_skin TEXT DEFAULT 'classic',

  -- Voice chat
  voice_enabled BOOLEAN DEFAULT FALSE,
  voice_room_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,

  -- Expiry (auto-delete old rooms)
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '2 hours'
);

-- Room players
CREATE TABLE room_players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,

  -- Player info (either user or bot)
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  is_bot BOOLEAN DEFAULT FALSE,
  bot_difficulty bot_difficulty,
  bot_name TEXT,

  -- Seating
  seat_position INT NOT NULL CHECK (seat_position >= 0),
  team INT,

  -- Status
  is_ready BOOLEAN DEFAULT FALSE,
  is_connected BOOLEAN DEFAULT TRUE,

  -- Voice
  voice_status voice_status DEFAULT 'disconnected',
  is_voice_muted_by_vote BOOLEAN DEFAULT FALSE,

  -- Timestamps
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(room_id, seat_position),
  UNIQUE(room_id, user_id),
  CHECK (
    (is_bot = TRUE AND user_id IS NULL AND bot_difficulty IS NOT NULL) OR
    (is_bot = FALSE AND user_id IS NOT NULL AND bot_difficulty IS NULL)
  )
);

-- Game states (authoritative server state)
CREATE TABLE game_states (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID UNIQUE NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,

  -- State data (game-specific JSON)
  state_json JSONB NOT NULL,

  -- Current status
  phase game_phase NOT NULL DEFAULT 'setup',
  current_turn_player_id UUID,
  turn_number INT DEFAULT 0,
  round_number INT DEFAULT 1,

  -- Timing
  turn_started_at TIMESTAMPTZ,
  turn_timeout_seconds INT DEFAULT 30,

  -- Version for optimistic locking
  version INT DEFAULT 1,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game moves (complete history for replay/anti-cheat)
CREATE TABLE game_moves (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
  player_id UUID NOT NULL,

  -- Move data
  move_type TEXT NOT NULL,
  move_data JSONB NOT NULL,

  -- Context
  turn_number INT NOT NULL,
  round_number INT NOT NULL,
  sequence_number INT NOT NULL,

  -- Validation
  is_valid BOOLEAN DEFAULT TRUE,
  validation_error TEXT,
  validated_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game configs (server-side tunables)
CREATE TABLE game_configs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_type game_type NOT NULL,

  -- Config data
  config_key TEXT NOT NULL,
  config_value JSONB NOT NULL,
  description TEXT,

  -- Versioning
  version INT DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(game_type, config_key, version)
);

-- ============================================
-- LEADERBOARDS & STATS
-- ============================================

CREATE TABLE leaderboards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  game_type game_type NOT NULL,

  -- ELO rating
  elo_rating INT DEFAULT 1000,
  peak_elo INT DEFAULT 1000,

  -- Stats
  games_played INT DEFAULT 0,
  games_won INT DEFAULT 0,
  games_lost INT DEFAULT 0,
  games_drawn INT DEFAULT 0,

  -- Streaks
  current_win_streak INT DEFAULT 0,
  best_win_streak INT DEFAULT 0,
  current_loss_streak INT DEFAULT 0,

  -- Game-specific stats (JSON for flexibility)
  stats JSONB DEFAULT '{}',

  -- Timestamps
  last_played_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, game_type)
);

-- Game history (completed games)
CREATE TABLE game_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL,
  game_type game_type NOT NULL,

  -- Results
  winner_ids UUID[] NOT NULL,
  final_scores JSONB NOT NULL,

  -- Participants
  player_ids UUID[] NOT NULL,
  player_count INT NOT NULL,
  had_bots BOOLEAN DEFAULT FALSE,

  -- Stats
  total_rounds INT,
  total_moves INT,
  duration_seconds INT,

  -- Timestamps
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- SOCIAL FEATURES
-- ============================================

-- Chat messages
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Message
  content TEXT NOT NULL CHECK (char_length(content) <= 500),
  is_team_only BOOLEAN DEFAULT FALSE,

  -- Reactions
  reactions JSONB DEFAULT '{}',

  -- Moderation
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_by UUID REFERENCES profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Quick reactions (emoji bubbles)
CREATE TABLE quick_reactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Reaction
  reaction_type TEXT NOT NULL, -- 'emoji', 'phrase'
  reaction_value TEXT NOT NULL, -- emoji or phrase key

  -- Target (optional - for card/play reactions)
  target_player_id UUID REFERENCES profiles(id),
  target_move_id UUID REFERENCES game_moves(id),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mute votes
CREATE TABLE mute_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
  target_player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  voter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Vote
  vote BOOLEAN NOT NULL, -- true = mute, false = don't mute

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 seconds',

  UNIQUE(room_id, target_player_id, voter_id)
);

-- Moderation log
CREATE TABLE moderation_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Target
  target_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Action
  action moderation_action NOT NULL,
  reason TEXT,

  -- Context
  room_id UUID REFERENCES game_rooms(id) ON DELETE SET NULL,
  moderator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  is_system_action BOOLEAN DEFAULT FALSE,

  -- Duration (for temp bans/mutes)
  expires_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User blocks (personal block list)
CREATE TABLE user_blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

-- Friends
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Status
  is_accepted BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,

  UNIQUE(user_id, friend_id),
  CHECK (user_id != friend_id)
);

-- ============================================
-- MONETIZATION
-- ============================================

-- Purchasable skins
CREATE TABLE skins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Identity
  skin_id TEXT UNIQUE NOT NULL,
  skin_type skin_type NOT NULL,
  display_name TEXT NOT NULL,
  description TEXT,

  -- Assets
  preview_image_url TEXT,
  asset_bundle_url TEXT,

  -- Pricing
  price_coins INT,
  price_gems INT,
  price_usd DECIMAL(10, 2),

  -- Availability
  is_premium BOOLEAN DEFAULT FALSE,
  is_limited BOOLEAN DEFAULT FALSE,
  available_from TIMESTAMPTZ,
  available_until TIMESTAMPTZ,

  -- Brand (for sponsored skins)
  brand_name TEXT,
  brand_logo_url TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User owned skins
CREATE TABLE user_skins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  skin_id TEXT NOT NULL REFERENCES skins(skin_id) ON DELETE CASCADE,

  -- Acquisition
  acquired_via TEXT NOT NULL, -- 'purchase', 'reward', 'gift', 'subscription', 'ad_watch'

  -- Timestamps
  acquired_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, skin_id)
);

-- Subscription history
CREATE TABLE subscription_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Subscription
  tier subscription_tier NOT NULL,

  -- Revenue tracking
  revenue_cat_transaction_id TEXT,
  price_usd DECIMAL(10, 2),

  -- Period
  started_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Coin/Gem transactions
CREATE TABLE currency_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Transaction
  currency_type TEXT NOT NULL CHECK (currency_type IN ('coins', 'gems')),
  amount INT NOT NULL,
  balance_after INT NOT NULL,

  -- Context
  transaction_type TEXT NOT NULL, -- 'purchase', 'spend', 'reward', 'ad_watch', 'gift'
  description TEXT,
  reference_id TEXT, -- related purchase, skin, etc.

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ad impressions (for analytics and rewards)
CREATE TABLE ad_impressions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

  -- Ad info
  ad_placement ad_placement NOT NULL,
  ad_unit_id TEXT NOT NULL,

  -- Sponsor (for branded content)
  sponsor_name TEXT,
  campaign_id TEXT,

  -- Context
  room_id UUID REFERENCES game_rooms(id) ON DELETE SET NULL,
  game_type game_type,

  -- Reward (for rewarded ads)
  reward_type TEXT,
  reward_amount INT,

  -- Timestamps
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- ============================================
-- INDEXES
-- ============================================

-- Profiles
CREATE INDEX idx_profiles_username ON profiles(username);
CREATE INDEX idx_profiles_subscription ON profiles(subscription_tier);
CREATE INDEX idx_profiles_last_online ON profiles(last_online_at);

-- Game rooms
CREATE INDEX idx_rooms_status ON game_rooms(status);
CREATE INDEX idx_rooms_game_type ON game_rooms(game_type);
CREATE INDEX idx_rooms_code ON game_rooms(room_code) WHERE room_code IS NOT NULL;
CREATE INDEX idx_rooms_public_waiting ON game_rooms(game_type, status)
  WHERE is_private = FALSE AND status = 'waiting';

-- Room players
CREATE INDEX idx_room_players_room ON room_players(room_id);
CREATE INDEX idx_room_players_user ON room_players(user_id);

-- Game states
CREATE INDEX idx_game_states_room ON game_states(room_id);
CREATE INDEX idx_game_states_current_player ON game_states(current_turn_player_id);

-- Game moves
CREATE INDEX idx_game_moves_room ON game_moves(room_id);
CREATE INDEX idx_game_moves_player ON game_moves(player_id);
CREATE INDEX idx_game_moves_sequence ON game_moves(room_id, sequence_number);

-- Leaderboards
CREATE INDEX idx_leaderboards_game ON leaderboards(game_type);
CREATE INDEX idx_leaderboards_elo ON leaderboards(game_type, elo_rating DESC);
CREATE INDEX idx_leaderboards_user ON leaderboards(user_id);

-- Chat
CREATE INDEX idx_chat_room ON chat_messages(room_id, created_at DESC);
CREATE INDEX idx_chat_sender ON chat_messages(sender_id);

-- Skins
CREATE INDEX idx_skins_type ON skins(skin_type);
CREATE INDEX idx_skins_available ON skins(skin_type)
  WHERE (available_from IS NULL OR available_from <= NOW())
  AND (available_until IS NULL OR available_until > NOW());

-- User skins
CREATE INDEX idx_user_skins_user ON user_skins(user_id);

-- ============================================
-- TRIGGERS & FUNCTIONS
-- ============================================

-- Update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_game_states_updated_at
  BEFORE UPDATE ON game_states
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_game_configs_updated_at
  BEFORE UPDATE ON game_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_leaderboards_updated_at
  BEFORE UPDATE ON leaderboards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_skins_updated_at
  BEFORE UPDATE ON skins
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Room player count sync
CREATE OR REPLACE FUNCTION update_room_player_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE game_rooms
    SET current_player_count = (
      SELECT COUNT(*) FROM room_players WHERE room_id = NEW.room_id
    )
    WHERE id = NEW.room_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE game_rooms
    SET current_player_count = (
      SELECT COUNT(*) FROM room_players WHERE room_id = OLD.room_id
    )
    WHERE id = OLD.room_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_room_player_count
  AFTER INSERT OR DELETE ON room_players
  FOR EACH ROW EXECUTE FUNCTION update_room_player_count();

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  counter INT := 0;
BEGIN
  -- Extract base username from email
  base_username := SPLIT_PART(NEW.email, '@', 1);
  final_username := base_username;

  -- Find unique username
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
    counter := counter + 1;
    final_username := base_username || counter::TEXT;
  END LOOP;

  -- Insert profile
  INSERT INTO profiles (id, username, display_name)
  VALUES (NEW.id, final_username, COALESCE(NEW.raw_user_meta_data->>'name', final_username));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Check mute vote threshold
CREATE OR REPLACE FUNCTION check_mute_vote_threshold()
RETURNS TRIGGER AS $$
DECLARE
  total_players INT;
  yes_votes INT;
  threshold DECIMAL;
BEGIN
  -- Get player count in room
  SELECT COUNT(*) INTO total_players
  FROM room_players
  WHERE room_id = NEW.room_id AND is_bot = FALSE;

  -- Get yes votes (excluding target)
  SELECT COUNT(*) INTO yes_votes
  FROM mute_votes
  WHERE room_id = NEW.room_id
    AND target_player_id = NEW.target_player_id
    AND vote = TRUE
    AND expires_at > NOW();

  -- Calculate threshold (50%)
  threshold := (total_players - 1) * 0.5;

  -- If threshold met, mute the player
  IF yes_votes >= threshold THEN
    UPDATE room_players
    SET is_voice_muted_by_vote = TRUE
    WHERE room_id = NEW.room_id AND user_id = NEW.target_player_id;

    -- Log moderation action
    INSERT INTO moderation_log (target_user_id, action, reason, room_id, is_system_action)
    VALUES (NEW.target_player_id, 'mute', 'Voted mute by players', NEW.room_id, TRUE);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_mute_vote
  AFTER INSERT ON mute_votes
  FOR EACH ROW EXECUTE FUNCTION check_mute_vote_threshold();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_moves ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mute_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE skins ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skins ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE currency_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_impressions ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Game rooms policies
CREATE POLICY "Public rooms visible to all" ON game_rooms
  FOR SELECT USING (is_private = FALSE OR host_id = auth.uid());

CREATE POLICY "Authenticated users can create rooms" ON game_rooms
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Hosts can update their rooms" ON game_rooms
  FOR UPDATE USING (host_id = auth.uid());

-- Room players policies
CREATE POLICY "Room players visible to room members" ON room_players
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE user_id = auth.uid())
    OR room_id IN (SELECT id FROM game_rooms WHERE is_private = FALSE)
  );

CREATE POLICY "Users can join rooms" ON room_players
  FOR INSERT WITH CHECK (user_id = auth.uid() OR is_bot = TRUE);

CREATE POLICY "Users can update own status" ON room_players
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can leave rooms" ON room_players
  FOR DELETE USING (user_id = auth.uid());

-- Game states policies
CREATE POLICY "Game states visible to room members" ON game_states
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE user_id = auth.uid())
  );

-- Game moves policies
CREATE POLICY "Moves visible to room members" ON game_moves
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE user_id = auth.uid())
  );

CREATE POLICY "Players can insert moves" ON game_moves
  FOR INSERT WITH CHECK (player_id = auth.uid());

-- Game configs policies
CREATE POLICY "Configs readable by authenticated" ON game_configs
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Leaderboards policies
CREATE POLICY "Leaderboards are public" ON leaderboards
  FOR SELECT USING (true);

-- Game history policies
CREATE POLICY "History visible to participants" ON game_history
  FOR SELECT USING (auth.uid() = ANY(player_ids) OR had_bots = FALSE);

-- Chat policies
CREATE POLICY "Chat visible to room members" ON chat_messages
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE user_id = auth.uid())
  );

CREATE POLICY "Members can send messages" ON chat_messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Skins policies
CREATE POLICY "Skins are public" ON skins
  FOR SELECT USING (true);

-- User skins policies
CREATE POLICY "Users see own skins" ON user_skins
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can acquire skins" ON user_skins
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Friendships policies
CREATE POLICY "Users see own friendships" ON friendships
  FOR SELECT USING (user_id = auth.uid() OR friend_id = auth.uid());

CREATE POLICY "Users can add friends" ON friendships
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update friend requests" ON friendships
  FOR UPDATE USING (friend_id = auth.uid());

-- ============================================
-- SEED DATA
-- ============================================

-- Default game configs
INSERT INTO game_configs (game_type, config_key, config_value, description) VALUES
  ('twenty_nine', 'turn_timeout', '30', 'Seconds per turn'),
  ('twenty_nine', 'min_bid', '15', 'Minimum bid value'),
  ('twenty_nine', 'max_bid', '28', 'Maximum normal bid'),
  ('twenty_nine', 'special_bid', '29', 'Special 29 bid value'),
  ('twenty_nine', 'card_points', '{"J": 3, "9": 2, "A": 1, "10": 1}', 'Point values'),

  ('oh_hell', 'turn_timeout', '30', 'Seconds per turn'),
  ('oh_hell', 'trump_suit', 'hearts', 'Fixed trump suit'),
  ('oh_hell', 'bust_rule', 'true', 'Enable bust rule'),
  ('oh_hell', 'scoring', '{"exact": 10, "bonus_per_trick": 1}', 'Scoring rules'),

  ('hearts', 'turn_timeout', '30', 'Seconds per turn'),
  ('hearts', 'shooting_moon', 'true', 'Enable shooting the moon'),
  ('hearts', 'end_score', '100', 'Game end score'),

  ('chess', 'turn_timeout', '300', 'Seconds per turn'),
  ('chess', 'time_control', '{"initial": 600, "increment": 5}', 'Time control'),

  ('ludo', 'turn_timeout', '20', 'Seconds per turn'),
  ('ludo', 'dice_rolls', '1', 'Dice rolls per turn');

-- Default skins
INSERT INTO skins (skin_id, skin_type, display_name, description, is_premium) VALUES
  ('classic', 'card', 'Classic', 'Traditional playing card design', FALSE),
  ('modern', 'card', 'Modern', 'Clean, minimalist design', FALSE),
  ('neon', 'card', 'Neon Glow', 'Vibrant neon colors', TRUE),
  ('gold', 'card', 'Gold Edition', 'Premium gold finish', TRUE),

  ('classic', 'room', 'Classic Table', 'Traditional green felt', FALSE),
  ('casino', 'room', 'Casino Royale', 'Luxury casino theme', TRUE),
  ('nature', 'room', 'Garden', 'Peaceful nature background', FALSE),
  ('space', 'room', 'Cosmic', 'Space and stars theme', TRUE),

  ('wood', 'board', 'Wooden Board', 'Classic wood texture', FALSE),
  ('marble', 'board', 'Marble', 'Elegant marble surface', TRUE);
```

## Expected Output

- All tables created with proper relationships
- Indexes for query performance
- RLS policies for security
- Triggers for automation
- Seed data for configs and skins
