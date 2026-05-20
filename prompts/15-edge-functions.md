# 14 - Edge Functions

> Create Supabase Edge Functions for server-side validation, matchmaking, and secure operations.

## Task

Build Edge Functions for:
- Room creation with validation
- Server-side move validation (anti-cheat)
- Matchmaking queue
- Voice chat token generation
- Subscription verification
- Game state reconciliation

---

## Function Structure

```
supabase/functions/
├── _shared/
│   ├── cors.ts
│   ├── supabase.ts
│   ├── types.ts
│   ├── validation.ts
│   └── game_rules/
│       ├── twenty_nine.ts
│       ├── oh_hell.ts
│       └── index.ts
├── create-room/
│   └── index.ts
├── validate-move/
│   └── index.ts
├── matchmaking/
│   └── index.ts
├── voice-token/
│   └── index.ts
├── verify-subscription/
│   └── index.ts
└── reconcile-state/
    └── index.ts
```

---

## Shared Utilities

### CORS Handler

```typescript
// supabase/functions/_shared/cors.ts

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
```

### Supabase Client

```typescript
// supabase/functions/_shared/supabase.ts

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export function getSupabaseClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: {
        headers: { Authorization: req.headers.get('Authorization')! },
      },
    }
  );
}

export function getSupabaseAdmin(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );
}
```

### Types

```typescript
// supabase/functions/_shared/types.ts

export type GameType = 'twenty_nine' | 'oh_hell' | 'hearts' | 'spades' | 'chess' | 'ludo';
export type RoomStatus = 'waiting' | 'starting' | 'in_game' | 'finished' | 'cancelled';
export type GamePhase = 'setup' | 'dealing' | 'bidding' | 'trump_selection' | 'playing' | 'scoring' | 'game_end';

export interface GameRoom {
  id: string;
  game_type: GameType;
  room_code: string | null;
  is_private: boolean;
  max_players: number;
  current_player_count: number;
  host_id: string;
  status: RoomStatus;
  settings: Record<string, any>;
  created_at: string;
}

export interface RoomPlayer {
  id: string;
  room_id: string;
  user_id: string | null;
  is_bot: boolean;
  bot_difficulty: string | null;
  seat_position: number;
  team: number | null;
  is_ready: boolean;
}

export interface GameState {
  id: string;
  room_id: string;
  state_json: Record<string, any>;
  phase: GamePhase;
  current_turn_player_id: string | null;
  turn_number: number;
  round_number: number;
  version: number;
}

export interface GameMove {
  player_id: string;
  type: string;
  data: Record<string, any>;
  turn_number: number;
  round_number: number;
}

export interface ValidationResult {
  valid: boolean;
  error?: string;
  error_code?: string;
}
```

---

## Create Room Function

```typescript
// supabase/functions/create-room/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseClient } from '../_shared/supabase.ts';
import { GameType } from '../_shared/types.ts';

interface CreateRoomRequest {
  game_type: GameType;
  max_players: number;
  is_private: boolean;
  settings?: Record<string, any>;
  room_skin?: string;
  card_skin?: string;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body: CreateRoomRequest = await req.json();

    // Validate request
    const validationError = validateCreateRoomRequest(body);
    if (validationError) {
      return new Response(
        JSON.stringify({ error: validationError }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check user's subscription for private rooms
    if (body.is_private) {
      const canCreate = await checkPrivateRoomLimit(supabase, user.id);
      if (!canCreate) {
        return new Response(
          JSON.stringify({ error: 'Private room limit reached', code: 'ROOM_LIMIT' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Generate room code for private rooms
    const roomCode = body.is_private ? generateRoomCode() : null;

    // Create room
    const { data: room, error: roomError } = await supabase
      .from('game_rooms')
      .insert({
        game_type: body.game_type,
        game_category: getGameCategory(body.game_type),
        max_players: body.max_players,
        is_private: body.is_private,
        host_id: user.id,
        room_code: roomCode,
        settings: body.settings || {},
        room_skin: body.room_skin || 'classic',
        card_skin: body.card_skin || 'classic',
        status: 'waiting',
      })
      .select()
      .single();

    if (roomError) {
      throw roomError;
    }

    // Add host as first player
    const { error: playerError } = await supabase
      .from('room_players')
      .insert({
        room_id: room.id,
        user_id: user.id,
        seat_position: 0,
        team: 0,
        is_ready: false,
      });

    if (playerError) {
      // Cleanup room if player insert fails
      await supabase.from('game_rooms').delete().eq('id', room.id);
      throw playerError;
    }

    // Initialize game state placeholder
    const initialState = getInitialStateForGame(body.game_type);
    const { error: stateError } = await supabase
      .from('game_states')
      .insert({
        room_id: room.id,
        state_json: initialState,
        phase: 'setup',
        turn_number: 0,
        round_number: 0,
      });

    if (stateError) {
      console.error('State creation error:', stateError);
      // Non-critical, continue
    }

    return new Response(
      JSON.stringify({
        room_id: room.id,
        room_code: roomCode,
        invite_link: roomCode ? `gameplatform://room/${room.id}?code=${roomCode}` : null,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error creating room:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

function validateCreateRoomRequest(body: CreateRoomRequest): string | null {
  if (!body.game_type) return 'game_type is required';
  if (!body.max_players || body.max_players < 2 || body.max_players > 8) {
    return 'max_players must be between 2 and 8';
  }

  // Game-specific validation
  switch (body.game_type) {
    case 'twenty_nine':
      if (body.max_players !== 4) return 'Twenty-Nine requires exactly 4 players';
      break;
    case 'oh_hell':
      if (body.max_players < 4 || body.max_players > 8) {
        return 'Oh Hell requires 4-8 players';
      }
      break;
    case 'chess':
      if (body.max_players !== 2) return 'Chess requires exactly 2 players';
      break;
  }

  return null;
}

function generateRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

function getGameCategory(gameType: GameType): string {
  switch (gameType) {
    case 'twenty_nine':
    case 'oh_hell':
    case 'hearts':
    case 'spades':
      return 'card';
    case 'chess':
    case 'ludo':
      return 'board';
    default:
      return 'card';
  }
}

function getInitialStateForGame(gameType: GameType): Record<string, any> {
  return {
    game_type: gameType,
    initialized: false,
    players: [],
  };
}

async function checkPrivateRoomLimit(supabase: any, userId: string): Promise<boolean> {
  // Get user's subscription tier
  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_tier')
    .eq('id', userId)
    .single();

  const tier = profile?.subscription_tier || 'free';

  if (tier === 'pro' || tier === 'max') {
    return true; // Unlimited
  }

  // Free tier: 1 per day
  const today = new Date().toISOString().split('T')[0];
  const { count } = await supabase
    .from('game_rooms')
    .select('*', { count: 'exact', head: true })
    .eq('host_id', userId)
    .eq('is_private', true)
    .gte('created_at', `${today}T00:00:00`);

  return (count || 0) < 1;
}
```

---

## Validate Move Function

```typescript
// supabase/functions/validate-move/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { GameMove, GameState, ValidationResult } from '../_shared/types.ts';
import { validateTwentyNineMove } from '../_shared/game_rules/twenty_nine.ts';
import { validateOhHellMove } from '../_shared/game_rules/oh_hell.ts';

interface ValidateMoveRequest {
  room_id: string;
  move: GameMove;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseAdmin();
    const body: ValidateMoveRequest = await req.json();

    // Get current game state
    const { data: gameState, error: stateError } = await supabase
      .from('game_states')
      .select('*')
      .eq('room_id', body.room_id)
      .single();

    if (stateError || !gameState) {
      return new Response(
        JSON.stringify({ valid: false, error: 'Game not found', error_code: 'GAME_NOT_FOUND' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify it's the player's turn
    if (gameState.current_turn_player_id !== body.move.player_id) {
      return new Response(
        JSON.stringify({ valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get game type
    const { data: room } = await supabase
      .from('game_rooms')
      .select('game_type')
      .eq('id', body.room_id)
      .single();

    if (!room) {
      return new Response(
        JSON.stringify({ valid: false, error: 'Room not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate move based on game type
    const validationResult = validateMove(room.game_type, gameState, body.move);

    if (!validationResult.valid) {
      // Log invalid move attempt (potential cheating)
      await supabase.from('game_moves').insert({
        room_id: body.room_id,
        player_id: body.move.player_id,
        move_type: body.move.type,
        move_data: body.move.data,
        turn_number: body.move.turn_number,
        round_number: body.move.round_number,
        sequence_number: await getNextSequenceNumber(supabase, body.room_id),
        is_valid: false,
        validation_error: validationResult.error_code,
        validated_at: new Date().toISOString(),
      });

      return new Response(
        JSON.stringify(validationResult),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Apply move and update state
    const newState = applyMove(room.game_type, gameState, body.move);

    // Update game state with optimistic locking
    const { error: updateError } = await supabase
      .from('game_states')
      .update({
        state_json: newState.state_json,
        phase: newState.phase,
        current_turn_player_id: newState.current_turn_player_id,
        turn_number: newState.turn_number,
        round_number: newState.round_number,
        version: gameState.version + 1,
        turn_started_at: new Date().toISOString(),
      })
      .eq('room_id', body.room_id)
      .eq('version', gameState.version);

    if (updateError) {
      return new Response(
        JSON.stringify({ valid: false, error: 'State conflict', error_code: 'VERSION_CONFLICT' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Record valid move
    await supabase.from('game_moves').insert({
      room_id: body.room_id,
      player_id: body.move.player_id,
      move_type: body.move.type,
      move_data: body.move.data,
      turn_number: body.move.turn_number,
      round_number: body.move.round_number,
      sequence_number: await getNextSequenceNumber(supabase, body.room_id),
      is_valid: true,
      validated_at: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        valid: true,
        new_state: newState,
        events: newState.events || [],
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error validating move:', error);
    return new Response(
      JSON.stringify({ valid: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

function validateMove(gameType: string, state: GameState, move: GameMove): ValidationResult {
  switch (gameType) {
    case 'twenty_nine':
      return validateTwentyNineMove(state.state_json, move);
    case 'oh_hell':
      return validateOhHellMove(state.state_json, move);
    default:
      return { valid: false, error: 'Unknown game type', error_code: 'UNKNOWN_GAME' };
  }
}

function applyMove(gameType: string, state: GameState, move: GameMove): any {
  // Apply move logic per game type
  // Returns new state
  const stateJson = { ...state.state_json };

  switch (gameType) {
    case 'twenty_nine':
      return applyTwentyNineMove(state, move);
    case 'oh_hell':
      return applyOhHellMove(state, move);
    default:
      return state;
  }
}

async function getNextSequenceNumber(supabase: any, roomId: string): Promise<number> {
  const { data } = await supabase
    .from('game_moves')
    .select('sequence_number')
    .eq('room_id', roomId)
    .order('sequence_number', { ascending: false })
    .limit(1);

  return (data?.[0]?.sequence_number || 0) + 1;
}
```

---

## Matchmaking Function

```typescript
// supabase/functions/matchmaking/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';

interface MatchmakingRequest {
  game_type: string;
  player_count?: number;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const adminClient = getSupabaseAdmin();

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body: MatchmakingRequest = await req.json();

    // Get user's ELO rating for this game
    const { data: leaderboard } = await supabase
      .from('leaderboards')
      .select('elo_rating')
      .eq('user_id', user.id)
      .eq('game_type', body.game_type)
      .single();

    const userElo = leaderboard?.elo_rating || 1000;

    // Check if user has priority matchmaking
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier')
      .eq('id', user.id)
      .single();

    const hasPriority = profile?.subscription_tier === 'pro' || profile?.subscription_tier === 'max';

    // Find available room matching criteria
    const eloRange = hasPriority ? 100 : 200; // Tighter matching for priority

    // First try to find existing room
    const { data: existingRooms } = await adminClient
      .from('game_rooms')
      .select(`
        *,
        room_players!inner(user_id),
        host:profiles!host_id(username, elo:leaderboards(elo_rating))
      `)
      .eq('game_type', body.game_type)
      .eq('status', 'waiting')
      .eq('is_private', false)
      .lt('current_player_count', body.player_count || 4);

    // Filter by ELO range
    const matchingRooms = existingRooms?.filter(room => {
      const hostElo = room.host?.elo?.[0]?.elo_rating || 1000;
      return Math.abs(hostElo - userElo) <= eloRange;
    }) || [];

    if (matchingRooms.length > 0) {
      // Join existing room
      const room = hasPriority ? matchingRooms[0] : matchingRooms[Math.floor(Math.random() * matchingRooms.length)];

      // Find available seat
      const occupiedSeats = room.room_players.map((p: any) => p.seat_position);
      let availableSeat = 0;
      while (occupiedSeats.includes(availableSeat)) {
        availableSeat++;
      }

      // Add player to room
      const { error: joinError } = await adminClient
        .from('room_players')
        .insert({
          room_id: room.id,
          user_id: user.id,
          seat_position: availableSeat,
          team: availableSeat % 2, // Alternate teams
          is_ready: false,
        });

      if (joinError) {
        throw joinError;
      }

      return new Response(
        JSON.stringify({
          action: 'joined',
          room_id: room.id,
          seat_position: availableSeat,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // No matching room found, create new one
    const { data: newRoom, error: createError } = await adminClient
      .from('game_rooms')
      .insert({
        game_type: body.game_type,
        game_category: 'card',
        max_players: body.player_count || 4,
        is_private: false,
        host_id: user.id,
        status: 'waiting',
        settings: { matchmaking: true },
      })
      .select()
      .single();

    if (createError) {
      throw createError;
    }

    // Add user as host
    await adminClient.from('room_players').insert({
      room_id: newRoom.id,
      user_id: user.id,
      seat_position: 0,
      team: 0,
      is_ready: false,
    });

    return new Response(
      JSON.stringify({
        action: 'created',
        room_id: newRoom.id,
        seat_position: 0,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Matchmaking error:', error);
    return new Response(
      JSON.stringify({ error: 'Matchmaking failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

---

## Voice Token Function

```typescript
// supabase/functions/voice-token/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseClient } from '../_shared/supabase.ts';
import { AccessToken } from 'https://esm.sh/livekit-server-sdk@1.2.0';

interface VoiceTokenRequest {
  room_id: string;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body: VoiceTokenRequest = await req.json();

    // Check if user is in the room
    const { data: roomPlayer } = await supabase
      .from('room_players')
      .select('*, game_rooms!inner(*)')
      .eq('room_id', body.room_id)
      .eq('user_id', user.id)
      .single();

    if (!roomPlayer) {
      return new Response(
        JSON.stringify({ error: 'Not in room' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if room has voice enabled
    if (!roomPlayer.game_rooms.voice_enabled) {
      return new Response(
        JSON.stringify({ error: 'Voice not enabled for this room' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check subscription for voice access
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier, username')
      .eq('id', user.id)
      .single();

    if (profile?.subscription_tier === 'free') {
      return new Response(
        JSON.stringify({ error: 'Voice chat requires Pro or Max subscription', code: 'SUBSCRIPTION_REQUIRED' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Generate LiveKit token
    const apiKey = Deno.env.get('LIVEKIT_API_KEY');
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET');

    if (!apiKey || !apiSecret) {
      throw new Error('LiveKit credentials not configured');
    }

    const roomName = `game_${body.room_id}`;
    const participantName = profile?.username || user.id;

    const at = new AccessToken(apiKey, apiSecret, {
      identity: user.id,
      name: participantName,
    });

    at.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    });

    const token = at.toJwt();

    return new Response(
      JSON.stringify({
        token,
        room_name: roomName,
        server_url: Deno.env.get('LIVEKIT_URL'),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Voice token error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to generate voice token' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

---

## Twenty-Nine Rules (Server-Side)

```typescript
// supabase/functions/_shared/game_rules/twenty_nine.ts

import { GameMove, ValidationResult } from '../types.ts';

interface TwentyNineState {
  phase: string;
  currentPlayerId: string;
  hands: Record<string, Card[]>;
  currentTrick: TrickCard[];
  trumpSuit: string | null;
  trumpRevealed: boolean;
  currentBid: number | null;
  bidderId: string | null;
  leadSuit: string | null;
}

interface Card {
  suit: string;
  rank: string;
}

interface TrickCard {
  playerId: string;
  card: Card;
}

export function validateTwentyNineMove(
  stateJson: Record<string, any>,
  move: GameMove
): ValidationResult {
  const state = stateJson as TwentyNineState;

  // Verify it's the correct player
  if (state.currentPlayerId !== move.player_id) {
    return { valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' };
  }

  switch (move.type) {
    case 'bid':
      return validateBid(state, move.data);
    case 'pass':
      return validatePass(state);
    case 'declareTrump':
      return validateDeclareTrump(state, move);
    case 'playCard':
      return validatePlayCard(state, move);
    case 'revealTrump':
      return validateRevealTrump(state);
    default:
      return { valid: false, error: 'Unknown move type', error_code: 'UNKNOWN_MOVE' };
  }
}

function validateBid(state: TwentyNineState, data: Record<string, any>): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }

  const bidValue = data.bidValue as number;
  const minBid = (state.currentBid || 14) + 1;

  if (bidValue !== 29 && (bidValue < minBid || bidValue > 28)) {
    return { valid: false, error: 'Invalid bid value', error_code: 'INVALID_BID' };
  }

  return { valid: true };
}

function validatePass(state: TwentyNineState): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  return { valid: true };
}

function validateDeclareTrump(state: TwentyNineState, move: GameMove): ValidationResult {
  if (state.phase !== 'trump_selection') {
    return { valid: false, error: 'Not trump selection phase', error_code: 'WRONG_PHASE' };
  }

  const suit = move.data.suit as string;
  const hand = state.hands[move.player_id];

  if (!hand || !hand.some(c => c.suit === suit)) {
    return { valid: false, error: 'Must have cards of declared suit', error_code: 'NO_CARDS_OF_SUIT' };
  }

  return { valid: true };
}

function validatePlayCard(state: TwentyNineState, move: GameMove): ValidationResult {
  if (state.phase !== 'playing') {
    return { valid: false, error: 'Not playing phase', error_code: 'WRONG_PHASE' };
  }

  const card = move.data.card as Card;
  const hand = state.hands[move.player_id];

  if (!hand) {
    return { valid: false, error: 'No hand found', error_code: 'NO_HAND' };
  }

  // Check card is in hand
  const hasCard = hand.some(c => c.suit === card.suit && c.rank === card.rank);
  if (!hasCard) {
    return { valid: false, error: 'Card not in hand', error_code: 'CARD_NOT_IN_HAND' };
  }

  // Must follow lead suit if possible
  if (state.currentTrick.length > 0 && state.leadSuit) {
    const hasLeadSuit = hand.some(c => c.suit === state.leadSuit);
    if (hasLeadSuit && card.suit !== state.leadSuit) {
      return { valid: false, error: 'Must follow suit', error_code: 'MUST_FOLLOW_SUIT' };
    }
  }

  return { valid: true };
}

function validateRevealTrump(state: TwentyNineState): ValidationResult {
  if (state.phase !== 'playing') {
    return { valid: false, error: 'Not playing phase', error_code: 'WRONG_PHASE' };
  }

  if (state.trumpRevealed) {
    return { valid: false, error: 'Trump already revealed', error_code: 'TRUMP_REVEALED' };
  }

  return { valid: true };
}
```

---

## Expected Output

- Room creation with validation and rate limiting
- Server-side move validation (anti-cheat)
- Matchmaking with ELO-based pairing
- Voice chat token generation with subscription check
- Game rule validation for each game type
- Optimistic locking for state updates
- Audit logging for invalid move attempts
