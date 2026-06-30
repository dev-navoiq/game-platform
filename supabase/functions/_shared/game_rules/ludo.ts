import { MovePayload, ValidationResult } from '../types.ts';

// ─── Board geometry (mirror of packages/game_ludo/lib/src/ludo_board.dart) ────

const MAIN_TRACK_LENGTH = 52;
const HOME_STRETCH_LENGTH = 6;
const SAFE_SQUARES = new Set([0, 8, 13, 21, 26, 34, 39, 47]);

type LudoZone = 'home' | 'main' | 'homeStretch' | 'finish';
type LudoColor = 'red' | 'blue' | 'green' | 'yellow';

interface LudoPosition {
  zone: LudoZone;
  index: number;
  color: LudoColor;
}

interface LudoToken {
  id: string;
  color: LudoColor;
  position: LudoPosition;
}

interface LudoState {
  playerIds: string[];
  tokens: LudoToken[];
  playerColors: Record<string, LudoColor>;
  currentPlayerIndex: number;
  // Kept in sync with playerIds[currentPlayerIndex] for the turn pre-check in
  // validate-move/index.ts (the Dart toJson omits this and derives it instead).
  currentPlayerId?: string;
  lastRoll: number | null;
  consecutiveSixes: number;
  canRollAgain: boolean;
  finishedPlayers: string[];
  winnerId: string | null;
  phase: string;
  turnNumber: number;
  roundNumber: number;
  socialMode?: string;
}

// Rule variants — fixed server-side defaults (match the chosen Ludo ruleset).
const REQUIRE_EXACT_FINISH = true;
const DOUBLE_ROLL_ON_SIX = true;
const BONUS_TURN_ON_CAPTURE = true;
const SAFE_SQUARES_ENABLED = true;

function startPosition(color: LudoColor): number {
  switch (color) {
    case 'red': return 0;
    case 'blue': return 13;
    case 'green': return 26;
    case 'yellow': return 39;
  }
}

function homeStretchEntry(color: LudoColor): number {
  return (startPosition(color) + 50) % MAIN_TRACK_LENGTH;
}

function isSafe(pos: LudoPosition): boolean {
  return pos.zone === 'main' && SAFE_SQUARES.has(pos.index);
}

function distanceTo(from: number, to: number, trackLength: number): number {
  if (to >= from) return to - from;
  return trackLength - from + to;
}

function homePosition(color: LudoColor, slot: number): LudoPosition {
  return { zone: 'home', index: slot, color };
}

/// Mirror of LudoRules._calculateNewPosition. Returns null for illegal moves.
function calculateNewPosition(
  token: LudoToken,
  steps: number,
  color: LudoColor,
): LudoPosition | null {
  switch (token.position.zone) {
    case 'home':
      if (steps !== 6) return null;
      return { zone: 'main', index: startPosition(color), color: 'red' };

    case 'main': {
      const current = token.position.index;
      const start = startPosition(color);
      const entry = homeStretchEntry(color);
      const distFromStart = distanceTo(start, current, MAIN_TRACK_LENGTH);
      const entryDist = distanceTo(start, entry, MAIN_TRACK_LENGTH);
      const totalDist = distFromStart + steps;

      if (totalDist > entryDist) {
        const stepsAfterEntry = totalDist - entryDist;
        if (stepsAfterEntry <= HOME_STRETCH_LENGTH) {
          return { zone: 'homeStretch', index: stepsAfterEntry - 1, color };
        } else if (stepsAfterEntry === HOME_STRETCH_LENGTH + 1) {
          return { zone: 'finish', index: 0, color };
        }
        return null; // Overshot
      }
      return {
        zone: 'main',
        index: (current + steps) % MAIN_TRACK_LENGTH,
        color: 'red',
      };
    }

    case 'homeStretch': {
      const newIndex = token.position.index + steps;
      if (newIndex < HOME_STRETCH_LENGTH) {
        return { zone: 'homeStretch', index: newIndex, color };
      } else if (newIndex === HOME_STRETCH_LENGTH) {
        return { zone: 'finish', index: 0, color };
      }
      if (REQUIRE_EXACT_FINISH) return null; // Overshot
      return { zone: 'finish', index: 0, color };
    }

    case 'finish':
      return null;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function tokensFor(state: LudoState, playerId: string): LudoToken[] {
  const color = state.playerColors[playerId];
  return state.tokens.filter((t) => t.color === color);
}

function hasPlayerFinished(tokens: LudoToken[], playerId: string, state: LudoState): boolean {
  const color = state.playerColors[playerId];
  return tokens.filter((t) => t.color === color).every((t) => t.position.zone === 'finish');
}

function findToken(state: LudoState, tokenId: string): LudoToken | undefined {
  return state.tokens.find((t) => t.id === tokenId);
}

function nextActivePlayerIndex(state: LudoState, current: number): number {
  const n = state.playerIds.length;
  let next = (current + 1) % n;
  let safety = 0;
  while (state.finishedPlayers.includes(state.playerIds[next]) && safety < n) {
    next = (next + 1) % n;
    safety++;
  }
  return next;
}

function validTokenMoves(state: LudoState, playerId: string): LudoToken[] {
  const roll = state.lastRoll!;
  const color = state.playerColors[playerId];
  return tokensFor(state, playerId).filter((token) => {
    if (token.position.zone === 'finish') return false;
    return calculateNewPosition(token, roll, color) !== null;
  });
}

function rollDie(): number {
  return (crypto.getRandomValues(new Uint32Array(1))[0] % 6) + 1;
}

/// Keep the derived currentPlayerId field in sync with currentPlayerIndex.
function finalize(state: LudoState): LudoState {
  return { ...state, currentPlayerId: state.playerIds[state.currentPlayerIndex] };
}

// ─── Validation ────────────────────────────────────────────────────────────────

export function validateLudoMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): ValidationResult {
  const state = stateJson as unknown as LudoState;

  if (state.finishedPlayers.length >= state.playerIds.length - 1) {
    return { valid: false, error: 'Game over', error_code: 'GAME_OVER' };
  }
  if (state.playerIds[state.currentPlayerIndex] !== move.player_id) {
    return { valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' };
  }

  switch (move.type) {
    case 'rollDice':
    case 'roll':
      if (state.lastRoll != null) {
        return { valid: false, error: 'Already rolled', error_code: 'ALREADY_ROLLED' };
      }
      return { valid: true };

    case 'moveToken':
    case 'move': {
      if (state.lastRoll == null) {
        return { valid: false, error: 'Must roll first', error_code: 'MUST_ROLL_FIRST' };
      }
      const tokenId = (move.data.tokenId ?? move.data.token_id) as string;
      const token = findToken(state, tokenId);
      if (!token) {
        return { valid: false, error: 'Token not found', error_code: 'TOKEN_NOT_FOUND' };
      }
      if (token.color !== state.playerColors[move.player_id]) {
        return { valid: false, error: 'Not your token', error_code: 'NOT_YOUR_TOKEN' };
      }
      const newPos = calculateNewPosition(token, state.lastRoll, token.color);
      if (newPos == null) {
        return { valid: false, error: 'Invalid token move', error_code: 'INVALID_TOKEN_MOVE' };
      }
      return { valid: true };
    }

    case 'pass':
      if (state.lastRoll == null) {
        return { valid: false, error: 'Must roll first', error_code: 'MUST_ROLL_FIRST' };
      }
      if (validTokenMoves(state, move.player_id).length > 0) {
        return { valid: false, error: 'Token moves available', error_code: 'TOKEN_MOVES_AVAILABLE' };
      }
      return { valid: true };

    default:
      return { valid: false, error: 'Unknown move type', error_code: 'UNKNOWN_MOVE' };
  }
}

// ─── Apply ──────────────────────────────────────────────────────────────────────

export function applyLudoMove(
  stateJson: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  const state = stateJson as unknown as LudoState;

  switch (move.type) {
    case 'rollDice':
    case 'roll':
      return finalize(applyRoll(state)) as unknown as Record<string, unknown>;
    case 'moveToken':
    case 'move':
      return finalize(applyTokenMove(state, move)) as unknown as Record<string, unknown>;
    case 'pass':
      return finalize(applyPass(state)) as unknown as Record<string, unknown>;
    default:
      return stateJson;
  }
}

function applyRoll(state: LudoState): LudoState {
  const roll = rollDie();

  // Three consecutive sixes → lose the turn.
  if (roll === 6 && state.consecutiveSixes >= 2) {
    return {
      ...state,
      lastRoll: null,
      consecutiveSixes: 0,
      canRollAgain: false,
      currentPlayerIndex: nextActivePlayerIndex(state, state.currentPlayerIndex),
      turnNumber: state.turnNumber + 1,
    };
  }

  return {
    ...state,
    lastRoll: roll,
    consecutiveSixes: roll === 6 ? state.consecutiveSixes + 1 : 0,
    canRollAgain: roll === 6 && DOUBLE_ROLL_ON_SIX,
    turnNumber: state.turnNumber + 1,
  };
}

function applyTokenMove(state: LudoState, move: MovePayload): LudoState {
  const tokenId = (move.data.tokenId ?? move.data.token_id) as string;
  const token = findToken(state, tokenId)!;
  const color = token.color;
  const newPos = calculateNewPosition(token, state.lastRoll!, color)!;

  let tokens: LudoToken[] = state.tokens.map((t) => ({ ...t, position: { ...t.position } }));
  let captured = false;

  // Capture opponents on non-safe main-track squares.
  if (newPos.zone === 'main' && SAFE_SQUARES_ENABLED && !isSafe(newPos)) {
    tokens = tokens.map((other) => {
      if (other.color === color) return other;
      if (other.position.zone === 'main' && other.position.index === newPos.index) {
        captured = true;
        const slot = parseInt(other.id.split('_').pop()!, 10);
        return { ...other, position: homePosition(other.color, slot) };
      }
      return other;
    });
  }

  // Move the token.
  tokens = tokens.map((t) => (t.id === token.id ? { ...t, position: newPos } : t));

  // Did this move bring the current player all the way home?
  const finishedPlayers = [...state.finishedPlayers];
  let winnerId = state.winnerId;
  let phase = state.phase;
  const justFinished =
    hasPlayerFinished(tokens, move.player_id, state) &&
    !finishedPlayers.includes(move.player_id);
  if (justFinished) {
    finishedPlayers.push(move.player_id);
    if (winnerId == null) winnerId = move.player_id; // First to finish wins.
  }

  // Game ends once only one player remains unfinished; keep playing for
  // 2nd/3rd placements until then. (For 2 players this is "first to finish".)
  const gameOver = finishedPlayers.length >= state.playerIds.length - 1;
  if (gameOver && phase !== 'gameEnd') {
    phase = 'gameEnd';
    for (const id of state.playerIds) {
      if (!finishedPlayers.includes(id)) finishedPlayers.push(id);
    }
  }

  // A six or a capture grants another roll — never if the player just
  // finished or the game has ended.
  const bonusTurn =
    !justFinished &&
    !gameOver &&
    (state.canRollAgain || (captured && BONUS_TURN_ON_CAPTURE));

  const nextIdx = bonusTurn
    ? state.currentPlayerIndex
    : nextActivePlayerIndex(state, state.currentPlayerIndex);

  return {
    ...state,
    tokens,
    lastRoll: null,
    consecutiveSixes: state.canRollAgain ? state.consecutiveSixes : 0,
    canRollAgain: bonusTurn,
    currentPlayerIndex: nextIdx,
    finishedPlayers,
    winnerId,
    phase,
    turnNumber: state.turnNumber + 1,
  };
}

function applyPass(state: LudoState): LudoState {
  return {
    ...state,
    lastRoll: null,
    consecutiveSixes: 0,
    canRollAgain: false,
    currentPlayerIndex: nextActivePlayerIndex(state, state.currentPlayerIndex),
    turnNumber: state.turnNumber + 1,
  };
}
