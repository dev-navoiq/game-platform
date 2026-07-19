import { Card, GameType } from './types.ts';

// Initial game-state builders + card utilities. Factored out of start-game so
// both the manual start-game flow and tournament match orchestration build
// identical initial states from one source of truth.

export function buildInitialState(
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
    case 'ludo':
      return buildLudoState(playerIds, dealerIndex, socialMode);
    default:
      return buildGenericState(gameType, playerIds, dealerIndex, socialMode);
  }
}

/** DB phase ('bidding' | 'playing') for a freshly built state. */
export function initialDbPhase(state: Record<string, unknown>): string {
  return state.phase === 'bidding' ? 'bidding' : 'playing';
}

function buildTwentyNineState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const deck = createStandard32Deck();
  shuffleDeck(deck);
  // Classic 29: deal 4 first; hold the remaining 16 in pendingDeck until
  // trump is declared, then the engine deals the second 4 per seat.
  const hands = dealHands(deck, playerIds, 4);
  const pendingDeck = deck.slice(playerIds.length * 4, playerIds.length * 4 + 16);
  // % length, not % 4: tournament matches are 1v1, and %4 made firstBidder
  // undefined for 2 players whenever dealerIndex+1 exceeded the roster.
  const firstBidder = playerIds[(dealerIndex + 1) % playerIds.length];

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
    tricksWon: { 0: 0, 1: 0 },
    teamPoints: { 0: 0, 1: 0 },
    sessionScores: { 0: 0, 1: 0 },
    turnNumber: 0,
    roundNumber: 1,
    socialMode,
    pendingDeck,
    bidAdjustment: 0,
    royalWeddingClaimedByTeam: [],
    redPips: { 0: 0, 1: 0 },
    blackPips: { 0: 0, 1: 0 },
  };
}

function buildOhHellState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  const n = playerIds.length;
  const maxCards = Math.floor(52 / n);
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
  const firstPlayer = playerIds[(dealerIndex + 1) % playerIds.length];

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
  const firstBidder = playerIds[(dealerIndex + 1) % playerIds.length];

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

function buildLudoState(
  playerIds: string[],
  dealerIndex: number,
  socialMode: string,
): Record<string, unknown> {
  if (playerIds.length < 2 || playerIds.length > 4) {
    throw new Error('Ludo requires 2-4 players');
  }
  const orderedIds = [
    ...playerIds.slice(dealerIndex),
    ...playerIds.slice(0, dealerIndex),
  ];
  const colors = ['red', 'blue', 'green', 'yellow'];
  const tokensPerPlayer = 4;

  const playerColors: Record<string, string> = {};
  const tokens: Array<Record<string, unknown>> = [];
  for (let i = 0; i < orderedIds.length; i++) {
    const playerId = orderedIds[i];
    const color = colors[i];
    playerColors[playerId] = color;
    for (let j = 0; j < tokensPerPlayer; j++) {
      tokens.push({
        id: `${playerId}_${j}`,
        color,
        position: { zone: 'home', index: j, color },
      });
    }
  }

  return {
    playerIds: orderedIds,
    tokens,
    playerColors,
    currentPlayerIndex: 0,
    consecutiveSixes: 0,
    canRollAgain: false,
    finishedPlayers: [],
    phase: 'playing',
    currentPlayerId: orderedIds[0],
    turnNumber: 1,
    roundNumber: 1,
    socialMode,
  };
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
    for (const rank of RANKS_52) deck.push({ suit, rank });
  }
  return deck;
}

function createStandard32Deck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS_32) deck.push({ suit, rank });
  }
  return deck;
}

function shuffleDeck(deck: Card[]): void {
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
