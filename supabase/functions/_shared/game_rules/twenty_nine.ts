import { Card, MovePayload, ValidationResult } from '../types.ts';

// ─── Card Constants ──────────────────────────────────────────────────────────

const CARD_STRENGTH: Record<string, number> = {
  jack: 8, nine: 7, ace: 6, ten: 5, king: 4, queen: 3, eight: 2, seven: 1,
};

const CARD_POINTS: Record<string, number> = {
  jack: 3, nine: 2, ace: 1, ten: 1,
};

const MIN_BID = 15;
const MAX_BID = 28;
const SPECIAL_BID = 29;
const HIGH_BID_THRESHOLD = 20;

function baseGamePointsForBid(bid: number): number {
  if (bid === SPECIAL_BID) return 4;
  if (bid >= HIGH_BID_THRESHOLD) return 2;
  return 1;
}

// ─── Interfaces ──────────────────────────────────────────────────────────────

interface TwentyNineState {
  phase: string;
  currentPlayerId: string;
  playerOrder: string[];
  dealerIndex: number;
  hands: Record<string, Card[]>;
  currentTrick: Array<{ playerId: string; card: Card; seatIndex: number }>;
  trumpSuit: string | null;
  trumpRevealed: boolean;
  trumpSelector: string | null;
  currentBid: number | null;
  bidderId: string | null;
  passCount: number;
  allPlayersPassed: boolean;
  tricksWon: Record<number, number>;      // team → count
  teamPoints: Record<number, number>;     // team → card-points
  sessionScores: Record<number, number>;  // team → game-points
  turnNumber: number;
  roundNumber: number;
  doublingMultiplier?: number;
  doubledBy?: string | null;
  redoubledBy?: string | null;
  trumpRevealerThisTrick?: string | null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getNextPlayerId(state: TwentyNineState): string {
  const idx = state.playerOrder.indexOf(state.currentPlayerId);
  return state.playerOrder[(idx + 1) % 4];
}

function teamForPlayer(state: TwentyNineState, playerId: string): number {
  return state.playerOrder.indexOf(playerId) % 2;
}

function handHasSuit(hand: Card[], suit: string): boolean {
  return hand.some((c) => c.suit === suit);
}

function handContainsCard(hand: Card[], card: Card): boolean {
  return hand.some((c) => c.suit === card.suit && c.rank === card.rank);
}

function cardStrength(card: Card): number {
  return CARD_STRENGTH[card.rank] ?? 0;
}

function cardPoints(card: Card): number {
  return CARD_POINTS[card.rank] ?? 0;
}

// ─── Validation ──────────────────────────────────────────────────────────────

export function validateTwentyNineMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): ValidationResult {
  const state = stateJson as unknown as TwentyNineState;

  // newRound can be sent by any player in the game. Allowed from gameEnd too
  // so a "Play Again" tap in the game-over dialog can start a fresh session
  // (sessionScores reset is handled in applyNewRound).
  if (move.type === 'newRound') {
    if (state.phase !== 'roundEnd' && state.phase !== 'gameEnd') {
      return { valid: false, error: 'Not round end or game end phase', error_code: 'WRONG_PHASE' };
    }
    return { valid: true };
  }

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
    case 'double':
      return validateDouble(state, move);
    case 'redouble':
      return validateRedouble(state, move);
    default:
      return { valid: false, error: 'Unknown move type', error_code: 'UNKNOWN_MOVE' };
  }
}

function validateDouble(state: TwentyNineState, move: MovePayload): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  if (state.bidderId == null) {
    return { valid: false, error: 'No bid to double', error_code: 'NO_BID_TO_DOUBLE' };
  }
  if ((state.doublingMultiplier ?? 1) !== 1) {
    return { valid: false, error: 'Already doubled', error_code: 'ALREADY_DOUBLED' };
  }
  if (teamForPlayer(state, move.player_id) === teamForPlayer(state, state.bidderId)) {
    return { valid: false, error: 'Only defenders may double', error_code: 'DOUBLE_MUST_BE_DEFENDER' };
  }
  return { valid: true };
}

function validateRedouble(state: TwentyNineState, move: MovePayload): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  if (state.bidderId == null) {
    return { valid: false, error: 'No bid to redouble', error_code: 'NO_BID_TO_REDOUBLE' };
  }
  if ((state.doublingMultiplier ?? 1) !== 2) {
    return { valid: false, error: 'Not doubled', error_code: 'NOT_DOUBLED' };
  }
  if (state.redoubledBy != null) {
    return { valid: false, error: 'Already redoubled', error_code: 'ALREADY_REDOUBLED' };
  }
  if (teamForPlayer(state, move.player_id) !== teamForPlayer(state, state.bidderId)) {
    return { valid: false, error: 'Only bidder team may redouble', error_code: 'REDOUBLE_MUST_BE_BIDDER_TEAM' };
  }
  return { valid: true };
}

function validateBid(
  state: TwentyNineState,
  data: Record<string, unknown>,
): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  // Contract locked once a double/redouble has been called.
  if ((state.doublingMultiplier ?? 1) !== 1) {
    return { valid: false, error: 'Contract locked', error_code: 'CONTRACT_LOCKED' };
  }
  const bidValue = (data.bid_value ?? data.bidValue) as number;
  if (bidValue === SPECIAL_BID) return { valid: true }; // 29 always valid
  const minBid = state.currentBid != null ? state.currentBid + 1 : MIN_BID;
  if (bidValue < minBid) {
    return { valid: false, error: 'Bid too low', error_code: 'BID_TOO_LOW' };
  }
  if (bidValue > MAX_BID) {
    return { valid: false, error: 'Bid too high', error_code: 'BID_TOO_HIGH' };
  }
  return { valid: true };
}

function validatePass(state: TwentyNineState): ValidationResult {
  if (state.phase !== 'bidding') {
    return { valid: false, error: 'Not bidding phase', error_code: 'WRONG_PHASE' };
  }
  return { valid: true };
}

function validateDeclareTrump(
  state: TwentyNineState,
  move: MovePayload,
): ValidationResult {
  if (state.phase !== 'trumpSelection') {
    return { valid: false, error: 'Not trump selection phase', error_code: 'WRONG_PHASE' };
  }
  const suit = move.data.suit as string;
  const hand = state.hands[move.player_id];
  if (!hand || !handHasSuit(hand, suit)) {
    return { valid: false, error: 'Must have cards of declared suit', error_code: 'NO_CARDS_OF_SUIT' };
  }
  return { valid: true };
}

function validatePlayCard(
  state: TwentyNineState,
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
  // Must follow lead suit when possible.
  if (state.currentTrick.length > 0) {
    const leadSuit = state.currentTrick[0].card.suit;
    if (handHasSuit(hand, leadSuit) && card.suit !== leadSuit) {
      return { valid: false, error: 'Must follow suit', error_code: 'MUST_FOLLOW_SUIT' };
    }
  }
  // Classic 29 rule: player who called for trump reveal in the current
  // trick must play a trump if they hold one.
  if (
    state.trumpRevealerThisTrick === move.player_id &&
    state.trumpSuit &&
    handHasSuit(hand, state.trumpSuit) &&
    card.suit !== state.trumpSuit
  ) {
    return { valid: false, error: 'Must play trump after reveal', error_code: 'MUST_PLAY_TRUMP' };
  }
  return { valid: true };
}

function validateRevealTrump(state: TwentyNineState): ValidationResult {
  if (state.phase !== 'playing') {
    return { valid: false, error: 'Not playing phase', error_code: 'WRONG_PHASE' };
  }
  if (state.trumpRevealed) {
    return { valid: false, error: 'Trump already revealed', error_code: 'TRUMP_ALREADY_REVEALED' };
  }
  if (!state.trumpSuit) {
    return { valid: false, error: 'No trump declared', error_code: 'NO_TRUMP_DECLARED' };
  }
  // Reveal is only permitted when the player cannot follow the lead suit.
  if (state.currentTrick.length > 0) {
    const leadSuit = state.currentTrick[0].card.suit;
    const hand = state.hands[state.currentPlayerId] ?? [];
    if (handHasSuit(hand, leadSuit)) {
      return { valid: false, error: 'Can follow suit', error_code: 'CAN_FOLLOW_SUIT' };
    }
  }
  return { valid: true };
}

// ─── Apply Move ──────────────────────────────────────────────────────────────

export function applyTwentyNineMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  const state = stateJson as unknown as TwentyNineState;

  switch (move.type) {
    case 'bid':
      return applyBid(state, move.data) as unknown as Record<string, unknown>;
    case 'pass':
      return applyPass(state) as unknown as Record<string, unknown>;
    case 'declareTrump':
      return applyDeclareTrump(state, move) as unknown as Record<string, unknown>;
    case 'playCard':
      return applyPlayCard(state, move) as unknown as Record<string, unknown>;
    case 'revealTrump':
      return applyRevealTrump(state, move) as unknown as Record<string, unknown>;
    case 'double':
      return applyDouble(state, move) as unknown as Record<string, unknown>;
    case 'redouble':
      return applyRedouble(state, move) as unknown as Record<string, unknown>;
    case 'newRound':
      return applyNewRound(state) as unknown as Record<string, unknown>;
    default:
      return stateJson;
  }
}

function applyDouble(state: TwentyNineState, move: MovePayload): TwentyNineState {
  return {
    ...state,
    doublingMultiplier: 2,
    doubledBy: move.player_id,
    passCount: state.passCount + 1,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyRedouble(state: TwentyNineState, move: MovePayload): TwentyNineState {
  return {
    ...state,
    doublingMultiplier: 4,
    redoubledBy: move.player_id,
    passCount: state.passCount + 1,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyBid(
  state: TwentyNineState,
  data: Record<string, unknown>,
): TwentyNineState {
  const bidValue = (data.bid_value ?? data.bidValue) as number;
  return {
    ...state,
    currentBid: bidValue,
    bidderId: state.currentPlayerId,
    passCount: 0,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyPass(state: TwentyNineState): TwentyNineState {
  const newPassCount = state.passCount + 1;

  // 3 passes after a bid → bidding over, move to trump selection.
  if (newPassCount >= 3 && state.bidderId != null) {
    // The bid winner picks the trump suit (secretly).
    const trumpSelector = state.bidderId;
    return {
      ...state,
      phase: 'trumpSelection',
      passCount: newPassCount,
      currentPlayerId: trumpSelector,
      trumpSelector,
      turnNumber: state.turnNumber + 1,
    };
  }

  // 4 passes with no bid → all players passed (redeal needed).
  if (newPassCount >= 4 && state.bidderId == null) {
    return {
      ...state,
      passCount: newPassCount,
      allPlayersPassed: true,
      currentPlayerId: getNextPlayerId(state),
      turnNumber: state.turnNumber + 1,
    };
  }

  return {
    ...state,
    passCount: newPassCount,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyDeclareTrump(
  state: TwentyNineState,
  move: MovePayload,
): TwentyNineState {
  const firstPlayer = state.playerOrder[(state.dealerIndex + 1) % 4];
  return {
    ...state,
    phase: 'playing',
    trumpSuit: move.data.suit as string,
    currentPlayerId: firstPlayer,
    turnNumber: state.turnNumber + 1,
  };
}

function applyPlayCard(
  state: TwentyNineState,
  move: MovePayload,
): TwentyNineState {
  const card = move.data.card as Card;

  // Remove card from hand
  const newHands = { ...state.hands };
  newHands[move.player_id] = state.hands[move.player_id].filter(
    (c) => !(c.suit === card.suit && c.rank === card.rank),
  );

  const seatIndex = state.playerOrder.indexOf(move.player_id);
  const newTrick = [
    ...state.currentTrick,
    { playerId: move.player_id, card, seatIndex },
  ];

  // Auto-reveal trump when a player plays a trump card while trump is still
  // face-down. The card itself publicly discloses the suit, so the state
  // should reflect that without requiring a separate reveal step.
  const autoRevealing =
    !!state.trumpSuit && !state.trumpRevealed && card.suit === state.trumpSuit;
  const baseState = autoRevealing
    ? {
        ...state,
        trumpRevealed: true,
        trumpRevealerThisTrick: move.player_id,
      }
    : state;

  // Trick complete when 4 players have played
  if (newTrick.length === 4) {
    return completeTrick(baseState, newTrick, newHands);
  }

  return {
    ...baseState,
    hands: newHands,
    currentTrick: newTrick,
    currentPlayerId: getNextPlayerId(state),
    turnNumber: state.turnNumber + 1,
  };
}

function applyRevealTrump(state: TwentyNineState, move: MovePayload): TwentyNineState {
  return {
    ...state,
    trumpRevealed: true,
    trumpRevealerThisTrick: move.player_id,
  };
}

function applyNewRound(state: TwentyNineState): TwentyNineState {
  // Build and shuffle a fresh 32-card deck
  const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
  const ranks = ['seven', 'eight', 'nine', 'ten', 'jack', 'queen', 'king', 'ace'];
  const deck: Card[] = [];
  for (const suit of suits) {
    for (const rank of ranks) {
      deck.push({ suit, rank });
    }
  }
  const randomValues = crypto.getRandomValues(new Uint32Array(deck.length));
  for (let i = deck.length - 1; i > 0; i--) {
    const j = randomValues[i] % (i + 1);
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }

  // Deal 8 cards to each player
  const hands: Record<string, Card[]> = {};
  let cardIndex = 0;
  for (const pid of state.playerOrder) {
    hands[pid] = deck.slice(cardIndex, cardIndex + 8);
    cardIndex += 8;
  }

  // Rotate dealer
  const newDealerIndex = (state.dealerIndex + 1) % 4;
  const firstBidder = state.playerOrder[(newDealerIndex + 1) % 4];

  // "Play Again" path: when starting a brand-new session after gameEnd,
  // wipe session scores and reset roundNumber so the new game starts clean.
  const restartingSession = state.phase === 'gameEnd';

  return {
    ...state,
    phase: 'bidding',
    currentPlayerId: firstBidder,
    dealerIndex: newDealerIndex,
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
    turnNumber: state.turnNumber + 1,
    doublingMultiplier: 1,
    doubledBy: null,
    redoubledBy: null,
    trumpRevealerThisTrick: null,
    sessionScores: restartingSession ? { 0: 0, 1: 0 } : state.sessionScores,
    roundNumber: restartingSession ? 1 : state.roundNumber,
  };
}

// ─── Trick Completion ────────────────────────────────────────────────────────

function completeTrick(
  state: TwentyNineState,
  trick: Array<{ playerId: string; card: Card; seatIndex: number }>,
  hands: Record<string, Card[]>,
): TwentyNineState {
  const leadSuit = trick[0].card.suit;
  const winnerId = determineTrickWinner(trick, leadSuit, state.trumpSuit);
  const winnerTeam = teamForPlayer(state, winnerId);

  const trickPts = trick.reduce((sum, tc) => sum + cardPoints(tc.card), 0);

  const newTricksWon = { ...state.tricksWon };
  newTricksWon[winnerTeam] = (newTricksWon[winnerTeam] ?? 0) + 1;

  const newTeamPoints = { ...state.teamPoints };
  newTeamPoints[winnerTeam] = (newTeamPoints[winnerTeam] ?? 0) + trickPts;

  const totalTricks = Object.values(newTricksWon).reduce((a, b) => a + b, 0);

  // All 8 tricks played → round over
  if (totalTricks === 8) {
    return completeRound(state, hands, newTricksWon, newTeamPoints);
  }

  return {
    ...state,
    hands,
    currentTrick: [],
    tricksWon: newTricksWon,
    teamPoints: newTeamPoints,
    currentPlayerId: winnerId,
    turnNumber: state.turnNumber + 1,
    // The "must play trump after reveal" obligation is only for the revealing
    // trick — clear it once that trick finishes.
    trumpRevealerThisTrick: null,
  };
}

function completeRound(
  state: TwentyNineState,
  hands: Record<string, Card[]>,
  tricksWon: Record<number, number>,
  teamPoints: Record<number, number>,
): TwentyNineState {
  const bidTeam = teamForPlayer(state, state.bidderId!);
  const bidTeamPoints = teamPoints[bidTeam] ?? 0;
  const bid = state.currentBid!;

  // Bid of 29 is met when bidding team gets all 28 card points
  const threshold = bid === SPECIAL_BID ? 28 : bid;
  const bidMet = bidTeamPoints >= threshold;

  const multiplier = state.doublingMultiplier ?? 1;
  const awarded = baseGamePointsForBid(bid) * multiplier;
  const newScores = { ...state.sessionScores };
  if (bidMet) {
    newScores[bidTeam] = (newScores[bidTeam] ?? 0) + awarded;
  } else {
    const otherTeam = bidTeam === 0 ? 1 : 0;
    newScores[otherTeam] = (newScores[otherTeam] ?? 0) + awarded;
  }

  // First team to 6 game-points wins
  const gameOver = Object.values(newScores).some((s) => s >= 6);

  return {
    ...state,
    phase: gameOver ? 'gameEnd' : 'roundEnd',
    hands,
    currentTrick: [],
    tricksWon,
    teamPoints,
    sessionScores: newScores,
    roundNumber: state.roundNumber + 1,
    turnNumber: state.turnNumber + 1,
  };
}

function determineTrickWinner(
  trick: Array<{ playerId: string; card: Card }>,
  leadSuit: string,
  trumpSuit: string | null,
): string {
  let winner = trick[0];

  for (let i = 1; i < trick.length; i++) {
    const tc = trick[i];
    const cur = tc.card;
    const win = winner.card;

    if (trumpSuit) {
      const curIsTrump = cur.suit === trumpSuit;
      const winIsTrump = win.suit === trumpSuit;

      if (curIsTrump && !winIsTrump) { winner = tc; continue; }
      if (winIsTrump && !curIsTrump) continue;
      if (curIsTrump && winIsTrump) {
        if (cardStrength(cur) > cardStrength(win)) winner = tc;
        continue;
      }
    }

    // Neither trump: only lead-suit cards can win
    if (cur.suit !== leadSuit) continue;
    if (win.suit !== leadSuit) { winner = tc; continue; }
    if (cardStrength(cur) > cardStrength(win)) winner = tc;
  }

  return winner.playerId;
}
