import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { Card, GameType } from '../_shared/types.ts';

interface StartGameRequest {
  room_id: string;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: StartGameRequest = await req.json();
    if (!body.room_id) return errorResponse('room_id is required', 400);

    // ── Fetch room ────────────────────────────────────────────────────────
    const { data: room, error: roomErr } = await admin
      .from('game_rooms')
      .select('*')
      .eq('id', body.room_id)
      .single();

    if (roomErr || !room) return errorResponse('Room not found', 404);

    // Only host can start
    if (room.created_by !== user.id) {
      return errorResponse('Only the host can start the game', 403, 'NOT_HOST');
    }
    if (room.status !== 'waiting') {
      return errorResponse('Game already started', 400, 'ALREADY_STARTED');
    }

    // ── Fetch human players ────────────────────────────────────────────────
    const { data: players } = await admin
      .from('room_players')
      .select('*')
      .eq('room_id', room.id)
      .eq('is_spectator', false)
      .order('seat_index', { ascending: true });

    // ── Merge with bots from room config ────────────────────────────────
    const bots: { id: string; difficulty: string; seat_index: number }[] =
      room.config?.bots ?? [];
    const humanIds = (players ?? []).map((p: { user_id: string }) => p.user_id);
    const botIds = bots.map((b) => b.id);
    const playerIds = [...humanIds, ...botIds];

    if (playerIds.length < 2) {
      return errorResponse('Not enough players', 400, 'NOT_ENOUGH_PLAYERS');
    }

    // ── Build initial game state ──────────────────────────────────────────
    const dealerIndex = Math.floor(Math.random() * playerIds.length);
    const stateData = buildInitialState(
      room.game_type as GameType,
      playerIds,
      dealerIndex,
      room.social_mode,
    );

    // Determine initial DB phase
    const dbPhase = stateData.phase === 'bidding' ? 'bidding' : 'playing';

    // ── Update room status ────────────────────────────────────────────────
    const { error: roomUpdateErr } = await admin
      .from('game_rooms')
      .update({ status: 'playing' })
      .eq('id', room.id);

    if (roomUpdateErr) throw roomUpdateErr;

    // ── Update game state ─────────────────────────────────────────────────
    const { data: updatedState, error: stateErr } = await admin
      .from('game_states')
      .update({
        phase: dbPhase,
        state_data: stateData,
        round: 1,
      })
      .eq('room_id', room.id)
      .select();

    if (stateErr) throw stateErr;

    if (!updatedState || updatedState.length === 0) {
      return errorResponse('Game state not found for room', 404, 'STATE_NOT_FOUND');
    }

    // ── Update player activities ──────────────────────────────────────────
    for (const pid of playerIds) {
      await admin
        .from('profiles')
        .update({
          current_activity: {
            type: 'in_game',
            game_type: room.game_type,
            room_id: room.id,
            room_code: room.code,
            spectatable: true,
            joinable: false,
          },
        })
        .eq('id', pid);
    }

    return jsonResponse({
      game_type: room.game_type,
      state: stateData,
      phase: dbPhase,
      round: 1,
    });
  } catch (error) {
    console.error('Start game error:', error);
    return errorResponse('Internal server error', 500);
  }
});

// ─── State Builders ──────────────────────────────────────────────────────────

function buildInitialState(
  gameType: GameType,
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  switch (gameType) {
    case 'twenty_nine':
      return buildTwentyNineState(playerIds, dealerIndex, socialMode);
    case 'oh_hell':
      return buildOhHellState(playerIds, dealerIndex, socialMode);
    case 'hearts':
      return buildHeartsState(playerIds, dealerIndex, socialMode);
    case 'spades':
      return buildSpadesState(playerIds, dealerIndex, socialMode);
    case 'bridge':
      return buildBridgeState(playerIds, dealerIndex, socialMode);
    default:
      return buildGenericState(gameType, playerIds, dealerIndex, socialMode);
  }
}

function buildTwentyNineState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const deck = createStandard32Deck();
  shuffleDeck(deck);
  const hands = dealHands(deck, playerIds, 8);
  const firstBidder = playerIds[(dealerIndex + 1) % 4];

  return {
    phase: 'bidding',
    currentPlayerId: firstBidder,
    playerOrder: playerIds,
    dealerIndex,
    hands,
    currentTrick: [],
    trumpSuit: null,
    trumpRevealed: false,
    trumpSelector: null,
    currentBid: null,
    bidderId: null,
    passCount: 0,
    allPlayersPassed: false,
    tricksWon: { 0: 0, 1: 0 },
    teamPoints: { 0: 0, 1: 0 },
    sessionScores: { 0: 0, 1: 0 },
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
  };
}

function buildOhHellState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const n = playerIds.length;
  const maxCards = Math.floor(52 / n);
  // Round sequence: descend from max to 1, then ascend back to max (matches Dart)
  const sequence: number[] = [];
  for (let i = maxCards; i >= 1; i--) sequence.push(i);
  for (let i = 2; i <= maxCards; i++) sequence.push(i);

  const cardsThisRound = sequence[0];
  const deck = createStandard52Deck();
  shuffleDeck(deck);
  const hands = dealHands(deck, playerIds, cardsThisRound);
  const firstBidder = playerIds[(dealerIndex + 1) % n];

  return {
    phase: 'bidding',
    currentPlayerId: firstBidder,
    playerOrder: playerIds,
    dealerIndex,
    hands,
    currentTrick: [],
    cardsThisRound,
    roundSequenceIndex: 0,
    totalRounds: sequence.length,
    bids: {},
    tricksWon: Object.fromEntries(playerIds.map((pid) => [pid, 0])),
    scores: Object.fromEntries(playerIds.map((pid) => [pid, 0])),
    roundHistory: [],
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
  };
}

function buildHeartsState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const deck = createStandard52Deck();
  shuffleDeck(deck);
  const hands = dealHands(deck, playerIds, 13);
  const firstPlayer = playerIds[(dealerIndex + 1) % 4];

  return {
    phase: 'playing',
    currentPlayerId: firstPlayer,
    playerOrder: playerIds,
    dealerIndex,
    hands,
    currentTrick: [],
    heartsBroken: false,
    tricksWon: Object.fromEntries(playerIds.map((pid) => [pid, 0])),
    scores: Object.fromEntries(playerIds.map((pid) => [pid, 0])),
    roundScores: Object.fromEntries(playerIds.map((pid) => [pid, 0])),
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
  };
}

function buildSpadesState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const deck = createStandard52Deck();
  shuffleDeck(deck);
  const hands = dealHands(deck, playerIds, 13);
  const firstBidder = playerIds[(dealerIndex + 1) % 4];

  return {
    phase: 'bidding',
    currentPlayerId: firstBidder,
    playerOrder: playerIds,
    dealerIndex,
    hands,
    currentTrick: [],
    spadesBroken: false,
    bids: {},
    tricksWon: { 0: 0, 1: 0 },
    teamScores: { 0: 0, 1: 0 },
    teamBags: { 0: 0, 1: 0 },
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
  };
}

function buildBridgeState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  if (playerIds.length !== 4) {
    throw new Error('Bridge requires exactly 4 players');
  }
  const deck = createStandard52Deck();
  shuffleDeck(deck);
  const hands = dealHands(deck, playerIds, 13);
  // Bridge: dealer makes the first auction call.
  const firstBidder = playerIds[dealerIndex];
  const dealNumber = 1;

  return {
    phase: 'bidding',
    currentPlayerId: firstBidder,
    playerOrder: playerIds,
    dealerIndex,
    hands,
    dealNumber,
    vulnerability: vulnerabilityForDeal(dealNumber),
    auctionHistory: [],
    contract: null,
    dummyId: null,
    dummyRevealed: false,
    currentTrick: [],
    tricksWon: { NS: 0, EW: 0 },
    trickNumber: 0,
    scores: { NS: 0, EW: 0 },
    dealHistory: [],
    totalDeals: 4,
    turnNumber: 0,
    roundNumber: dealNumber,
    socialMode,
  };
}

function vulnerabilityForDeal(dealNumber: number): string {
  const mod = ((dealNumber - 1) % 4) + 1;
  if (mod === 1) return 'none';
  if (mod === 2) return 'ns';
  if (mod === 3) return 'ew';
  return 'both';
}

function buildGenericState(
  gameType: string,
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  return {
    phase: 'playing',
    game_type: gameType,
    currentPlayerId: playerIds[0],
    playerOrder: playerIds,
    dealerIndex,
    initialized: true,
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
  };
}

// ─── Card Utilities ──────────────────────────────────────────────────────────

const SUITS = ['hearts', 'diamonds', 'clubs', 'spades'];
const RANKS_52 = [
  'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'jack', 'queen', 'king', 'ace',
];
const RANKS_32 = ['seven', 'eight', 'nine', 'ten', 'jack', 'queen', 'king', 'ace'];

function createStandard52Deck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS_52) {
      deck.push({ suit, rank });
    }
  }
  return deck;
}

function createStandard32Deck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS_32) {
      deck.push({ suit, rank });
    }
  }
  return deck;
}

function shuffleDeck(deck: Card[]): void {
  // Fisher-Yates shuffle with crypto random
  const randomValues = crypto.getRandomValues(new Uint32Array(deck.length));
  for (let i = deck.length - 1; i > 0; i--) {
    const j = randomValues[i] % (i + 1);
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
}

function dealHands(
  deck: Card[],
  playerIds: string[],
  cardsPerPlayer: number,
): Record<string, Card[]> {
  const hands: Record<string, Card[]> = {};
  let cardIndex = 0;
  for (const pid of playerIds) {
    hands[pid] = deck.slice(cardIndex, cardIndex + cardsPerPlayer);
    cardIndex += cardsPerPlayer;
  }
  return hands;
}
