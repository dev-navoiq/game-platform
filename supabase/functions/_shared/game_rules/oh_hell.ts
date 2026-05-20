import { Card, MovePayload, ValidationResult } from '../types.ts';

// ─── Standard rank ordering (Oh Hell uses standard 52-card rank order) ──────

const RANK_ORDER: Record<string, number> = {
  two: 0, three: 1, four: 2, five: 3, six: 4, seven: 5, eight: 6,
  nine: 7, ten: 8, jack: 9, queen: 10, king: 11, ace: 12,
};

// ─── Interfaces ──────────────────────────────────────────────────────────────

interface OhHellState {
  phase: string;
  currentPlayerId: string;
  playerOrder: string[];
  dealerIndex: number;
  hands: Record<string, Card[]>;
  currentTrick: Array<{ playerId: string; card: Card; seatIndex: number }>;
  cardsThisRound: number;
  roundSequenceIndex: number;
  totalRounds: number;
  bids: Record<string, number>;
  tricksWon: Record<string, number>;
  scores: Record<string, number>;
  turnNumber: number;
  roundNumber: number;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getNextPlayerId(state: OhHellState): string {
  const idx = state.playerOrder.indexOf(state.currentPlayerId);
  return state.playerOrder[(idx + 1) % state.playerOrder.length];
}

function handHasSuit(hand: Card[], suit: string): boolean {
  return hand.some((c) => c.suit === suit);
}

function handContainsCard(hand: Card[], card: Card): boolean {
  return hand.some((c) => c.suit === card.suit && c.rank === card.rank);
}

function rankIndex(rank: string): number {
  return RANK_ORDER[rank] ?? 0;
}

/**
 * Compute the forbidden bid for the dealer.
 * The total of all bids cannot equal cardsThisRound.
 * Returns -1 if the current player is not the dealer.
 */
function getForbiddenBid(state: OhHellState): number {
  const dealerPid = state.playerOrder[state.dealerIndex];
  if (state.currentPlayerId !== dealerPid) return -1;

  // Dealer is the last to bid
  if (Object.keys(state.bids).length !== state.playerOrder.length - 1) return -1;

  const sumOthers = Object.values(state.bids).reduce((a, b) => a + b, 0);
  const forbidden = state.cardsThisRound - sumOthers;
  return forbidden >= 0 && forbidden <= state.cardsThisRound ? forbidden : -1;
}

// ─── Validation ──────────────────────────────────────────────────────────────

export function validateOhHellMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): ValidationResult {
  const state = stateJson as unknown as OhHellState;

  if (state.currentPlayerId !== move.player_id) {
    return { valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' };
  }

  switch (move.type) {
    case 'bid':
      return validateBid(state, move.data);
    case 'playCard':
      return validatePlayCard(state, move);
    default:
      return { valid: false, error: 'Unknown move type', error_code: 'UNKNOWN_MOVE' };
  }
}

function validateBid(
  state: OhHellState,
  data: Record<string, unknown>,
): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  const bid = data.bid as number;
  if (bid < 0) {
    return { valid: false, error: 'Bid too low', error_code: 'BID_TOO_LOW' };
  }
  if (bid > state.cardsThisRound) {
    return { valid: false, error: 'Bid too high', error_code: 'BID_TOO_HIGH' };
  }

  const forbidden = getForbiddenBid(state);
  if (forbidden >= 0 && bid === forbidden) {
    return { valid: false, error: 'Forbidden bid (dealer constraint)', error_code: 'FORBIDDEN_BID' };
  }

  return { valid: true };
}

function validatePlayCard(
  state: OhHellState,
  move: MovePayload,
): ValidationResult {
  if (state.phase !== 'playing') {
    return { valid: false, error: 'Not playing phase', error_code: 'WRONG_PHASE' };
  }
  const card = move.data.card as Card;
  const hand = state.hands[move.player_id];
  if (!hand) {
    return { valid: false, error: 'No hand found', error_code: 'NO_HAND' };
  }
  if (!handContainsCard(hand, card)) {
    return { valid: false, error: 'Card not in hand', error_code: 'CARD_NOT_IN_HAND' };
  }
  // Must follow lead suit when possible
  if (state.currentTrick.length > 0) {
    const leadSuit = state.currentTrick[0].card.suit;
    if (handHasSuit(hand, leadSuit) && card.suit !== leadSuit) {
      return { valid: false, error: 'Must follow suit', error_code: 'MUST_FOLLOW_SUIT' };
    }
  }
  return { valid: true };
}

// ─── Apply Move ──────────────────────────────────────────────────────────────

export function applyOhHellMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  const state = stateJson as unknown as OhHellState;

  switch (move.type) {
    case 'bid':
      return applyBid(state, move.data) as unknown as Record<string, unknown>;
    case 'playCard':
      return applyPlayCard(state, move) as unknown as Record<string, unknown>;
    default:
      return stateJson;
  }
}

function applyBid(
  state: OhHellState,
  data: Record<string, unknown>,
): OhHellState {
  const bid = data.bid as number;
  const newBids = { ...state.bids, [state.currentPlayerId]: bid };

  // All players have bid → transition to playing
  if (Object.keys(newBids).length === state.playerOrder.length) {
    const firstLeader =
      state.playerOrder[(state.dealerIndex + 1) % state.playerOrder.length];
    return {
      ...state,
      phase: 'playing',
      bids: newBids,
      currentPlayerId: firstLeader,
      turnNumber: state.turnNumber + 1,
    };
  }

  return {
    ...state,
    bids: newBids,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyPlayCard(
  state: OhHellState,
  move: MovePayload,
): OhHellState {
  const card = move.data.card as Card;

  const newHands = { ...state.hands };
  newHands[move.player_id] = state.hands[move.player_id].filter(
    (c) => !(c.suit === card.suit && c.rank === card.rank),
  );

  const seatIndex = state.playerOrder.indexOf(move.player_id);
  const newTrick = [
    ...state.currentTrick,
    { playerId: move.player_id, card, seatIndex },
  ];

  // Trick complete when all players have played
  if (newTrick.length === state.playerOrder.length) {
    return completeTrick(state, newTrick, newHands);
  }

  return {
    ...state,
    hands: newHands,
    currentTrick: newTrick,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

// ─── Trick / Round Completion ────────────────────────────────────────────────

function completeTrick(
  state: OhHellState,
  trick: Array<{ playerId: string; card: Card; seatIndex: number }>,
  hands: Record<string, Card[]>,
): OhHellState {
  const leadSuit = trick[0].card.suit;
  const trumpSuit = 'hearts'; // Hearts are always trump in Oh Hell
  const winnerId = determineTrickWinner(trick, leadSuit, trumpSuit);

  const newTricksWon = { ...state.tricksWon };
  newTricksWon[winnerId] = (newTricksWon[winnerId] ?? 0) + 1;

  const totalTricksPlayed = Object.values(newTricksWon).reduce((a, b) => a + b, 0);

  if (totalTricksPlayed === state.cardsThisRound) {
    return completeRound(state, hands, newTricksWon);
  }

  return {
    ...state,
    hands,
    currentTrick: [],
    tricksWon: newTricksWon,
    currentPlayerId: winnerId,
    turnNumber: state.turnNumber + 1,
  };
}

function completeRound(
  state: OhHellState,
  hands: Record<string, Card[]>,
  tricksWon: Record<string, number>,
): OhHellState {
  // Score: exact bid = 10 + bid, else 0
  const newScores = { ...state.scores };
  for (const pid of state.playerOrder) {
    const bid = state.bids[pid] ?? 0;
    const won = tricksWon[pid] ?? 0;
    if (won === bid) {
      newScores[pid] = (newScores[pid] ?? 0) + 10 + bid;
    }
    // else no points added
  }

  const nextIndex = state.roundSequenceIndex + 1;
  const gameOver = nextIndex >= state.totalRounds;

  return {
    ...state,
    phase: gameOver ? 'gameEnd' : 'roundEnd',
    hands,
    currentTrick: [],
    tricksWon,
    scores: newScores,
    roundNumber: state.roundNumber + 1,
    turnNumber: state.turnNumber + 1,
    roundSequenceIndex: nextIndex,
  };
}

function determineTrickWinner(
  trick: Array<{ playerId: string; card: Card }>,
  leadSuit: string,
  trumpSuit: string,
): string {
  let winner = trick[0];

  for (let i = 1; i < trick.length; i++) {
    const tc = trick[i];
    const cur = tc.card;
    const win = winner.card;

    const curTrump = cur.suit === trumpSuit;
    const winTrump = win.suit === trumpSuit;

    if (curTrump && !winTrump) { winner = tc; continue; }
    if (!curTrump && winTrump) continue;
    if (curTrump && winTrump) {
      if (rankIndex(cur.rank) > rankIndex(win.rank)) winner = tc;
      continue;
    }

    // Neither trump: only lead-suit can win
    if (cur.suit === leadSuit) {
      if (win.suit !== leadSuit || rankIndex(cur.rank) > rankIndex(win.rank)) {
        winner = tc;
      }
    }
  }

  return winner.playerId;
}
