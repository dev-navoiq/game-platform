// Server-side Contract Bridge rules — mirrors packages/game_bridge/lib/src/
// (bridge_rules.dart / bridge_scoring.dart) in lockstep. Any change to one
// must be reflected in the other.

import { Card, MovePayload, ValidationResult } from '../types.ts';

// ─── Constants ───────────────────────────────────────────────────────────────

const RANK_ORDER: Record<string, number> = {
  two: 0, three: 1, four: 2, five: 3, six: 4, seven: 5, eight: 6,
  nine: 7, ten: 8, jack: 9, queen: 10, king: 11, ace: 12,
};

// Auction ranking. Lower index = lower denomination.
const DENOM_ORDER: Record<string, number> = {
  clubs: 0, diamonds: 1, hearts: 2, spades: 3, noTrump: 4,
};

const TOTAL_TRICKS = 13;
const HAND_SIZE = 13;
const TOTAL_DEALS_DEFAULT = 4;

type DoubleStatus = 'undoubled' | 'doubled' | 'redoubled';
type Vulnerability = 'none' | 'ns' | 'ew' | 'both';
type Denomination = 'clubs' | 'diamonds' | 'hearts' | 'spades' | 'noTrump';

// ─── Interfaces ──────────────────────────────────────────────────────────────

interface AuctionCall {
  playerId: string;
  seatIndex: number;
  type: 'bid' | 'pass' | 'double' | 'redouble';
  level?: number;
  denomination?: Denomination;
}

interface BridgeContract {
  level: number;
  denomination: Denomination;
  doubleStatus: DoubleStatus;
  declarerId: string;
  declarerSeat: number;
}

interface BridgeDealResult {
  dealNumber: number;
  contract: BridgeContract | null;
  vulnerability: Vulnerability;
  declarerTricks: number;
  made: boolean;
  overtricks: number;
  undertricks: number;
  nsPoints: number;
  ewPoints: number;
}

interface BridgeState {
  phase: string; // bidding | playing | roundEnd | gameEnd
  currentPlayerId: string | null;
  turnNumber: number;
  roundNumber: number;
  socialMode?: string;

  playerOrder: string[];
  dealerIndex: number;
  hands: Record<string, Card[]>;

  dealNumber: number;
  vulnerability: Vulnerability;

  auctionHistory: AuctionCall[];

  contract: BridgeContract | null;
  dummyId: string | null;
  dummyRevealed: boolean;

  currentTrick: Array<{ playerId: string; card: Card; seatIndex: number }>;
  tricksWon: Record<string, number>; // 'NS' | 'EW'
  trickNumber: number;

  scores: Record<string, number>; // 'NS' | 'EW'
  dealHistory: BridgeDealResult[];
  totalDeals: number;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function teamForSeat(seatIndex: number): 'NS' | 'EW' {
  return seatIndex % 2 === 0 ? 'NS' : 'EW';
}

function isTeamVulnerable(team: 'NS' | 'EW', v: Vulnerability): boolean {
  if (v === 'none') return false;
  if (v === 'both') return true;
  return team.toLowerCase() === v;
}

function vulnerabilityForDeal(dealNumber: number): Vulnerability {
  const mod = ((dealNumber - 1) % 4) + 1;
  if (mod === 1) return 'none';
  if (mod === 2) return 'ns';
  if (mod === 3) return 'ew';
  return 'both';
}

function nextSeat(state: BridgeState): string {
  const i = state.playerOrder.indexOf(state.currentPlayerId!);
  return state.playerOrder[(i + 1) % state.playerOrder.length];
}

function handHasSuit(hand: Card[], suit: string): boolean {
  return hand.some((c) => c.suit === suit);
}

function handContainsCard(hand: Card[], card: Card): boolean {
  return hand.some((c) => c.suit === card.suit && c.rank === card.rank);
}

function lastBid(history: AuctionCall[]): AuctionCall | null {
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].type === 'bid') return history[i];
  }
  return null;
}

function currentDoubleStatus(history: AuctionCall[]): DoubleStatus {
  for (let i = history.length - 1; i >= 0; i--) {
    const c = history[i];
    if (c.type === 'pass') continue;
    if (c.type === 'redouble') return 'redoubled';
    if (c.type === 'double') return 'doubled';
    if (c.type === 'bid') return 'undoubled';
  }
  return 'undoubled';
}

function canDouble(history: AuctionCall[], currentSeat: number): string | null {
  for (let i = history.length - 1; i >= 0; i--) {
    const c = history[i];
    if (c.type === 'pass') continue;
    if (c.type === 'double' || c.type === 'redouble') return 'ALREADY_DOUBLED';
    if (c.type === 'bid') {
      if (c.seatIndex % 2 === currentSeat % 2) return 'CANNOT_DOUBLE_PARTNER';
      return null;
    }
  }
  return 'NO_BID_TO_DOUBLE';
}

function canRedouble(history: AuctionCall[], currentSeat: number): string | null {
  for (let i = history.length - 1; i >= 0; i--) {
    const c = history[i];
    if (c.type === 'pass') continue;
    if (c.type === 'redouble') return 'ALREADY_REDOUBLED';
    if (c.type === 'bid') return 'NOT_DOUBLED';
    if (c.type === 'double') {
      if (c.seatIndex % 2 === currentSeat % 2) return 'CANNOT_REDOUBLE_OWN';
      return null;
    }
  }
  return 'NO_BID_TO_REDOUBLE';
}

function isAuctionOver(history: AuctionCall[]): boolean {
  if (history.length === 0) return false;
  let lastNonPass = -1;
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].type !== 'pass') {
      lastNonPass = i;
      break;
    }
  }
  if (lastNonPass === -1) return history.length >= 4;
  return history.length - 1 - lastNonPass >= 3;
}

function isPassedOut(history: AuctionCall[]): boolean {
  return history.length >= 4 && history.every((c) => c.type === 'pass');
}

function findDeclarerCall(
  history: AuctionCall[],
  denomination: Denomination,
  winningSeat: number,
): AuctionCall {
  const winningParity = winningSeat % 2;
  for (const c of history) {
    if (c.type !== 'bid') continue;
    if (c.seatIndex % 2 !== winningParity) continue;
    if (c.denomination === denomination) return c;
  }
  throw new Error('Could not find declarer');
}

function suitForDenomination(d: Denomination): string | null {
  return d === 'noTrump' ? null : d;
}

// ─── Validation ──────────────────────────────────────────────────────────────

export function validateBridgeMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): ValidationResult {
  const state = stateJson as unknown as BridgeState;

  if (move.type === 'newDeal') {
    if (state.phase !== 'roundEnd' && state.phase !== 'gameEnd') {
      return { valid: false, error: 'Not round end', error_code: 'NOT_ROUND_END' };
    }
    return { valid: true };
  }

  const seatId = state.currentPlayerId;
  if (!seatId) {
    return { valid: false, error: 'No current player', error_code: 'NO_CURRENT_PLAYER' };
  }

  const isPlayPhase = state.phase === 'playing';
  const isDummyTurn = isPlayPhase && seatId === state.dummyId;
  const declarerId = state.contract?.declarerId ?? null;
  const isAuthorized =
    move.player_id === seatId ||
    (isDummyTurn && declarerId !== null && move.player_id === declarerId);
  if (!isAuthorized) {
    return { valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' };
  }

  switch (move.type) {
    case 'playCard':
      return validatePlayCard(state, move, seatId);
    case 'bid':
      if (state.phase !== 'bidding') {
        return { valid: false, error: 'Wrong phase', error_code: 'WRONG_PHASE' };
      }
      return validateBid(state, move.data);
    case 'pass':
      if (state.phase !== 'bidding') {
        return { valid: false, error: 'Wrong phase', error_code: 'WRONG_PHASE' };
      }
      return { valid: true };
    case 'double': {
      if (state.phase !== 'bidding') {
        return { valid: false, error: 'Wrong phase', error_code: 'WRONG_PHASE' };
      }
      const seatIndex = state.playerOrder.indexOf(move.player_id);
      const err = canDouble(state.auctionHistory, seatIndex);
      return err ? { valid: false, error: err, error_code: err } : { valid: true };
    }
    case 'redouble': {
      if (state.phase !== 'bidding') {
        return { valid: false, error: 'Wrong phase', error_code: 'WRONG_PHASE' };
      }
      const seatIndex = state.playerOrder.indexOf(move.player_id);
      const err = canRedouble(state.auctionHistory, seatIndex);
      return err ? { valid: false, error: err, error_code: err } : { valid: true };
    }
    default:
      return { valid: false, error: 'Unknown move', error_code: 'UNKNOWN_MOVE' };
  }
}

function validateBid(
  state: BridgeState,
  data: Record<string, unknown>,
): ValidationResult {
  const level = data.level as number | undefined;
  const denomination = data.denomination as Denomination | undefined;
  if (typeof level !== 'number' || !denomination) {
    return { valid: false, error: 'Bid data missing', error_code: 'BID_MISSING' };
  }
  if (level < 1 || level > 7) {
    return { valid: false, error: 'Bid out of range', error_code: 'BID_OUT_OF_RANGE' };
  }

  const lb = lastBid(state.auctionHistory);
  if (lb === null) return { valid: true };

  if (level < lb.level!) {
    return { valid: false, error: 'Bid too low', error_code: 'BID_TOO_LOW' };
  }
  if (level === lb.level! && DENOM_ORDER[denomination] <= DENOM_ORDER[lb.denomination!]) {
    return { valid: false, error: 'Bid too low', error_code: 'BID_TOO_LOW' };
  }
  return { valid: true };
}

function validatePlayCard(
  state: BridgeState,
  move: MovePayload,
  seatId: string,
): ValidationResult {
  if (state.phase !== 'playing') {
    return { valid: false, error: 'Not playing phase', error_code: 'WRONG_PHASE' };
  }
  const card = move.data.card as Card;
  if (!card) {
    return { valid: false, error: 'Card missing', error_code: 'CARD_MISSING' };
  }
  const hand = state.hands[seatId];
  if (!hand) {
    return { valid: false, error: 'No hand', error_code: 'NO_HAND' };
  }
  if (!handContainsCard(hand, card)) {
    return { valid: false, error: 'Card not in hand', error_code: 'CARD_NOT_IN_HAND' };
  }
  if (state.currentTrick.length > 0) {
    const leadSuit = state.currentTrick[0].card.suit;
    if (card.suit !== leadSuit && handHasSuit(hand, leadSuit)) {
      return { valid: false, error: 'Must follow suit', error_code: 'MUST_FOLLOW_SUIT' };
    }
  }
  return { valid: true };
}

// ─── Apply Move ──────────────────────────────────────────────────────────────

export function applyBridgeMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  const state = stateJson as unknown as BridgeState;

  switch (move.type) {
    case 'newDeal':
      return applyNewDeal(state) as unknown as Record<string, unknown>;
    case 'playCard':
      return applyPlayCard(state, move) as unknown as Record<string, unknown>;
    case 'bid':
    case 'pass':
    case 'double':
    case 'redouble':
      return applyAuctionCall(state, move) as unknown as Record<string, unknown>;
    default:
      return stateJson;
  }
}

function toAuctionCall(move: MovePayload, seatIndex: number): AuctionCall {
  switch (move.type) {
    case 'bid':
      return {
        playerId: move.player_id,
        seatIndex,
        type: 'bid',
        level: move.data.level as number,
        denomination: move.data.denomination as Denomination,
      };
    case 'pass':
      return { playerId: move.player_id, seatIndex, type: 'pass' };
    case 'double':
      return { playerId: move.player_id, seatIndex, type: 'double' };
    case 'redouble':
      return { playerId: move.player_id, seatIndex, type: 'redouble' };
    default:
      throw new Error(`Not an auction move: ${move.type}`);
  }
}

function applyAuctionCall(state: BridgeState, move: MovePayload): BridgeState {
  const seatIndex = state.playerOrder.indexOf(state.currentPlayerId!);
  const call = toAuctionCall(move, seatIndex);
  const newHistory = [...state.auctionHistory, call];

  if (isAuctionOver(newHistory)) {
    return settleAuction(state, newHistory);
  }

  return {
    ...state,
    auctionHistory: newHistory,
    currentPlayerId: nextSeat(state),
    turnNumber: state.turnNumber + 1,
  };
}

function settleAuction(state: BridgeState, history: AuctionCall[]): BridgeState {
  if (isPassedOut(history)) {
    return finishDeal(
      {
        ...state,
        auctionHistory: history,
        turnNumber: state.turnNumber + 1,
      },
      null,
      0,
    );
  }

  const lb = lastBid(history)!;
  const doubleStatus = currentDoubleStatus(history);
  const declarerCall = findDeclarerCall(history, lb.denomination!, lb.seatIndex);
  const declarerSeat = declarerCall.seatIndex;
  const declarerId = declarerCall.playerId;
  const dummySeat = (declarerSeat + 2) % 4;
  const openingLeaderSeat = (declarerSeat + 1) % 4;

  const contract: BridgeContract = {
    level: lb.level!,
    denomination: lb.denomination!,
    doubleStatus,
    declarerId,
    declarerSeat,
  };

  return {
    ...state,
    phase: 'playing',
    auctionHistory: history,
    contract,
    dummyId: state.playerOrder[dummySeat],
    currentPlayerId: state.playerOrder[openingLeaderSeat],
    currentTrick: [],
    tricksWon: { NS: 0, EW: 0 },
    trickNumber: 0,
    dummyRevealed: false,
    turnNumber: state.turnNumber + 1,
  };
}

function applyPlayCard(state: BridgeState, move: MovePayload): BridgeState {
  const card = move.data.card as Card;
  const seatId = state.currentPlayerId!;
  const seatIndex = state.playerOrder.indexOf(seatId);

  const newHands = { ...state.hands };
  newHands[seatId] = state.hands[seatId].filter(
    (c) => !(c.suit === card.suit && c.rank === card.rank),
  );

  const newTrick = [
    ...state.currentTrick,
    { playerId: seatId, card, seatIndex },
  ];

  const justRevealedDummy =
    !state.dummyRevealed && state.trickNumber === 0 && newTrick.length === 1;

  if (newTrick.length === 4) {
    return completeTrick(state, newTrick, newHands, justRevealedDummy);
  }

  return {
    ...state,
    hands: newHands,
    currentTrick: newTrick,
    currentPlayerId: nextSeat(state),
    dummyRevealed: state.dummyRevealed || justRevealedDummy,
    turnNumber: state.turnNumber + 1,
  };
}

function completeTrick(
  state: BridgeState,
  trick: Array<{ playerId: string; card: Card; seatIndex: number }>,
  hands: Record<string, Card[]>,
  revealDummy: boolean,
): BridgeState {
  const leadSuit = trick[0].card.suit;
  const trumpSuit = state.contract
    ? suitForDenomination(state.contract.denomination)
    : null;
  const winner = determineTrickWinner(trick, leadSuit, trumpSuit);
  const winnerTeam = teamForSeat(winner.seatIndex);

  const newTricksWon = { ...state.tricksWon };
  newTricksWon[winnerTeam] = (newTricksWon[winnerTeam] ?? 0) + 1;

  const newTrickNumber = state.trickNumber + 1;

  if (newTrickNumber >= TOTAL_TRICKS) {
    const declarerTricks =
      state.contract ? newTricksWon[teamForSeat(state.contract.declarerSeat)] ?? 0 : 0;
    return finishDeal(
      {
        ...state,
        hands,
        currentTrick: [],
        tricksWon: newTricksWon,
        trickNumber: newTrickNumber,
        dummyRevealed: state.dummyRevealed || revealDummy,
        turnNumber: state.turnNumber + 1,
      },
      state.contract,
      declarerTricks,
    );
  }

  return {
    ...state,
    hands,
    currentTrick: [],
    tricksWon: newTricksWon,
    trickNumber: newTrickNumber,
    currentPlayerId: winner.playerId,
    dummyRevealed: state.dummyRevealed || revealDummy,
    turnNumber: state.turnNumber + 1,
  };
}

function determineTrickWinner(
  trick: Array<{ playerId: string; card: Card; seatIndex: number }>,
  leadSuit: string,
  trumpSuit: string | null,
): { playerId: string; seatIndex: number } {
  let winner = trick[0];
  for (let i = 1; i < trick.length; i++) {
    const tc = trick[i];
    const cur = tc.card;
    const win = winner.card;
    const curTrump = trumpSuit !== null && cur.suit === trumpSuit;
    const winTrump = trumpSuit !== null && win.suit === trumpSuit;

    if (curTrump && !winTrump) {
      winner = tc;
    } else if (!curTrump && winTrump) {
      // keep
    } else if (curTrump && winTrump) {
      if (RANK_ORDER[cur.rank] > RANK_ORDER[win.rank]) winner = tc;
    } else {
      if (cur.suit === leadSuit) {
        if (win.suit !== leadSuit || RANK_ORDER[cur.rank] > RANK_ORDER[win.rank]) {
          winner = tc;
        }
      }
    }
  }
  return winner;
}

// ─── Deal completion + new deal ─────────────────────────────────────────────

function finishDeal(
  state: BridgeState,
  contract: BridgeContract | null,
  declarerTricks: number,
): BridgeState {
  const result = scoreDeal(contract, declarerTricks, state.vulnerability);

  const newScores = { ...state.scores };
  newScores['NS'] = (newScores['NS'] ?? 0) + result.nsPoints;
  newScores['EW'] = (newScores['EW'] ?? 0) + result.ewPoints;

  const dealResult: BridgeDealResult = {
    dealNumber: state.dealNumber,
    contract,
    vulnerability: state.vulnerability,
    declarerTricks: result.declarerTricks,
    made: result.made,
    overtricks: result.overtricks,
    undertricks: result.undertricks,
    nsPoints: result.nsPoints,
    ewPoints: result.ewPoints,
  };
  const newHistory = [...state.dealHistory, dealResult];
  const isLastDeal = state.dealNumber >= state.totalDeals;

  return {
    ...state,
    phase: isLastDeal ? 'gameEnd' : 'roundEnd',
    scores: newScores,
    dealHistory: newHistory,
    currentPlayerId: null,
  };
}

function shuffleDeck(deck: Card[]): void {
  const randomValues = crypto.getRandomValues(new Uint32Array(deck.length));
  for (let i = deck.length - 1; i > 0; i--) {
    const j = randomValues[i] % (i + 1);
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
}

function build52Deck(): Card[] {
  const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
  const ranks = [
    'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'jack', 'queen', 'king', 'ace',
  ];
  const deck: Card[] = [];
  for (const suit of suits) {
    for (const rank of ranks) {
      deck.push({ suit, rank });
    }
  }
  return deck;
}

function applyNewDeal(state: BridgeState): BridgeState {
  const restarting = state.phase === 'gameEnd';
  const nextDealNumber = restarting ? 1 : state.dealNumber + 1;
  const nextDealerIndex = restarting
    ? state.dealerIndex
    : (state.dealerIndex + 1) % state.playerOrder.length;

  const deck = build52Deck();
  shuffleDeck(deck);
  const hands: Record<string, Card[]> = {};
  let idx = 0;
  for (const pid of state.playerOrder) {
    hands[pid] = deck.slice(idx, idx + HAND_SIZE);
    idx += HAND_SIZE;
  }

  return {
    ...state,
    phase: 'bidding',
    currentPlayerId: state.playerOrder[nextDealerIndex],
    dealerIndex: nextDealerIndex,
    hands,
    dealNumber: nextDealNumber,
    vulnerability: vulnerabilityForDeal(nextDealNumber),
    auctionHistory: [],
    contract: null,
    dummyId: null,
    dummyRevealed: false,
    currentTrick: [],
    tricksWon: { NS: 0, EW: 0 },
    trickNumber: 0,
    scores: restarting ? { NS: 0, EW: 0 } : state.scores,
    dealHistory: restarting ? [] : state.dealHistory,
    totalDeals: state.totalDeals ?? TOTAL_DEALS_DEFAULT,
    roundNumber: nextDealNumber,
    turnNumber: state.turnNumber + 1,
  };
}

// ─── Scoring (mirrors bridge_scoring.dart) ──────────────────────────────────

interface ScoreResult {
  declarerTricks: number;
  made: boolean;
  overtricks: number;
  undertricks: number;
  nsPoints: number;
  ewPoints: number;
}

function scoreDeal(
  contract: BridgeContract | null,
  declarerTricks: number,
  vulnerability: Vulnerability,
): ScoreResult {
  if (!contract) {
    return {
      declarerTricks: 0,
      made: false,
      overtricks: 0,
      undertricks: 0,
      nsPoints: 0,
      ewPoints: 0,
    };
  }

  const required = 6 + contract.level;
  const made = declarerTricks >= required;
  const overtricks = made ? declarerTricks - required : 0;
  const undertricks = made ? 0 : required - declarerTricks;
  const declarerTeam = teamForSeat(contract.declarerSeat);
  const vul = isTeamVulnerable(declarerTeam, vulnerability);

  const points = made
    ? scoreMade(contract, overtricks, vul)
    : scoreSet(contract.doubleStatus, undertricks, vul);

  const nsPoints =
    declarerTeam === 'NS' ? (made ? points : 0) : (made ? 0 : points);
  const ewPoints =
    declarerTeam === 'EW' ? (made ? points : 0) : (made ? 0 : points);

  return { declarerTricks, made, overtricks, undertricks, nsPoints, ewPoints };
}

function scoreMade(
  contract: BridgeContract,
  overtricks: number,
  vul: boolean,
): number {
  const trickScore = computeTrickScore(contract);
  const gameBonus = trickScore >= 100 ? (vul ? 500 : 300) : 50;
  const slamBonus = computeSlamBonus(contract.level, vul);
  const insult =
    contract.doubleStatus === 'doubled' ? 50 :
    contract.doubleStatus === 'redoubled' ? 100 : 0;
  const overtrickScore = computeOvertrickScore(contract, overtricks, vul);
  return trickScore + gameBonus + slamBonus + insult + overtrickScore;
}

function computeTrickScore(c: BridgeContract): number {
  let base: number;
  if (c.denomination === 'clubs' || c.denomination === 'diamonds') {
    base = 20 * c.level;
  } else if (c.denomination === 'hearts' || c.denomination === 'spades') {
    base = 30 * c.level;
  } else {
    base = 40 + 30 * (c.level - 1);
  }
  if (c.doubleStatus === 'doubled') return base * 2;
  if (c.doubleStatus === 'redoubled') return base * 4;
  return base;
}

function computeSlamBonus(level: number, vul: boolean): number {
  if (level === 6) return vul ? 750 : 500;
  if (level === 7) return vul ? 1500 : 1000;
  return 0;
}

function computeOvertrickScore(
  contract: BridgeContract,
  overtricks: number,
  vul: boolean,
): number {
  if (overtricks <= 0) return 0;
  if (contract.doubleStatus === 'undoubled') {
    const perTrick =
      contract.denomination === 'clubs' || contract.denomination === 'diamonds'
        ? 20
        : 30;
    return perTrick * overtricks;
  }
  if (contract.doubleStatus === 'doubled') return overtricks * (vul ? 200 : 100);
  return overtricks * (vul ? 400 : 200); // redoubled
}

function scoreSet(
  doubleStatus: DoubleStatus,
  undertricks: number,
  vul: boolean,
): number {
  if (doubleStatus === 'undoubled') {
    return undertricks * (vul ? 100 : 50);
  }
  const multiplier = doubleStatus === 'redoubled' ? 2 : 1;
  let total = 0;
  for (let i = 1; i <= undertricks; i++) {
    let t: number;
    if (vul) {
      t = i === 1 ? 200 : 300;
    } else {
      if (i === 1) t = 100;
      else if (i <= 3) t = 200;
      else t = 300;
    }
    total += t;
  }
  return total * multiplier;
}
