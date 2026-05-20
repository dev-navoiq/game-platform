// ─── Enums (matching actual DB schema) ─────────────────────────────────────

export type GameType =
  | 'twenty_nine'
  | 'oh_hell'
  | 'hearts'
  | 'spades'
  | 'bridge'
  | 'rummy'
  | 'chess'
  | 'ludo'
  | 'sequence';

export type RoomStatus = 'waiting' | 'playing' | 'finished' | 'abandoned';

export type GamePhaseDb =
  | 'waiting'
  | 'bidding'
  | 'playing'
  | 'scoring'
  | 'complete';

export type SubscriptionTier = 'free' | 'pro' | 'max';

export type RoomSocialMode = 'full' | 'chat_only' | 'silent' | 'focus';

// ─── Table Interfaces ──────────────────────────────────────────────────────

export interface GameRoom {
  id: string;
  code: string;
  game_type: GameType;
  status: RoomStatus;
  social_mode: RoomSocialMode;
  created_by: string;
  max_players: number;
  current_players: number;
  is_private: boolean;
  password_hash: string | null;
  config: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface RoomPlayer {
  id: string;
  room_id: string;
  user_id: string;
  seat_index: number;
  team: number | null;
  is_ready: boolean;
  is_spectator: boolean;
  joined_at: string;
}

export interface GameState {
  id: string;
  room_id: string;
  phase: GamePhaseDb;
  state_data: Record<string, unknown>;
  round: number;
  created_at: string;
  updated_at: string;
}

export interface Profile {
  id: string;
  username: string;
  display_name: string | null;
  coins: number;
  gems: number;
  subscription_tier: SubscriptionTier;
  subscription_expires_at: string | null;
  xp: number;
  level: number;
  xp_to_next_level: number;
  preferred_social_mode: RoomSocialMode;
  referral_code: string;
  referred_by: string | null;
  current_activity: Record<string, unknown> | null;
}

// ─── Move / Validation ─────────────────────────────────────────────────────

export interface MovePayload {
  player_id: string;
  type: string;
  data: Record<string, unknown>;
}

export interface ValidationResult {
  valid: boolean;
  error?: string;
  error_code?: string;
}

// ─── Card primitives ───────────────────────────────────────────────────────

export interface Card {
  suit: string; // hearts, diamonds, clubs, spades
  rank: string; // two..ace (matches Dart Rank enum names)
}

export interface TrickCard {
  playerId: string;
  card: Card;
  seatIndex: number;
}

// ─── Game-specific player count constraints ────────────────────────────────

export const GAME_PLAYER_LIMITS: Record<GameType, { min: number; max: number }> = {
  twenty_nine: { min: 4, max: 4 },
  oh_hell: { min: 4, max: 8 },
  hearts: { min: 4, max: 4 },
  spades: { min: 4, max: 4 },
  bridge: { min: 4, max: 4 },
  rummy: { min: 2, max: 6 },
  chess: { min: 2, max: 2 },
  ludo: { min: 2, max: 4 },
  sequence: { min: 2, max: 3 },
};

// ─── Dart GamePhase → DB game_phase mapping ────────────────────────────────

export function mapDartPhaseToDb(dartPhase: string): GamePhaseDb {
  switch (dartPhase) {
    case 'setup':
    case 'dealing':
    case 'waiting':
    case 'trumpSelection':
    case 'cardPassing':
      return dartPhase === 'waiting' ? 'waiting' : 'bidding';
    case 'bidding':
      return 'bidding';
    case 'playing':
      return 'playing';
    case 'scoring':
    case 'roundEnd':
      return 'scoring';
    case 'gameEnd':
    case 'complete':
      return 'complete';
    default:
      return 'playing';
  }
}
