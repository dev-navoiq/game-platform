import { MovePayload, ValidationResult } from '../types.ts';

/**
 * Passthrough validator for games without full server-side rules
 * (chess, hearts, spades, sequence, rummy — see SECURITY-AUDIT C6).
 *
 * IMPORTANT: this does NOT verify move *legality* (is this a legal chess move?).
 * That requires a per-game engine port — tracked in SECURITY-GUIDELINES §7.
 * What it does enforce are the generic, rule-agnostic invariants that catch the
 * worst passthrough exploits without ever rejecting a legal self-move:
 *   - author present, move type present
 *   - it is the author's turn
 *   - the move does not act on BEHALF OF another player (resign/claim spoofing):
 *     any player_id embedded in move.data must equal the move author
 *   - the move type is one the current phase permits (per-game allow-list)
 *
 * Note: validate-move already forces move.player_id === auth.uid() (or a bot in
 * the room), so a human cannot submit as an opponent. This adds the in-payload
 * actor check as defense in depth.
 */

// Phase → allowed move types. A game/phase absent here is not gated (open).
const PHASE_MOVE_ALLOWLIST: Record<string, Record<string, string[]>> = {
  chess: {
    playing: ['movePiece', 'promote', 'castle', 'enPassant', 'resign', 'offerDraw', 'acceptDraw', 'claimDraw'],
  },
  hearts: {
    passing: ['passCards'],
    playing: ['playCard'],
  },
  spades: {
    bidding: ['bid', 'nil', 'blindNil'],
    playing: ['playCard'],
  },
  sequence: {
    playing: ['playCard', 'discardDeadCard'],
  },
};

export function passthroughValidate(
  stateData: Record<string, unknown>,
  move: MovePayload,
  gameType?: string,
): ValidationResult {
  if (!move.player_id) {
    return { valid: false, error: 'Missing player_id', error_code: 'MISSING_PLAYER' };
  }
  if (!move.type) {
    return { valid: false, error: 'Missing move type', error_code: 'MISSING_TYPE' };
  }

  // Check it's the player's turn (if state tracks currentPlayerId)
  const currentPlayer = stateData.currentPlayerId as string | undefined;
  if (currentPlayer && currentPlayer !== move.player_id) {
    return { valid: false, error: 'Not your turn', error_code: 'NOT_YOUR_TURN' };
  }

  // Reject acting on behalf of another player (e.g. resign/claim spoofing):
  // any actor id carried in the move payload must be the author.
  const data = (move.data ?? {}) as Record<string, unknown>;
  for (const key of ['player_id', 'playerId', 'target_id', 'targetId', 'actor', 'actor_id']) {
    const v = data[key];
    if (typeof v === 'string' && v.length > 0 && v !== move.player_id) {
      return { valid: false, error: 'Move actor mismatch', error_code: 'ACTOR_MISMATCH' };
    }
  }

  // Phase-appropriate move type (per-game allow-list; open where unspecified).
  const phase = stateData.phase as string | undefined;
  const perGame = gameType ? PHASE_MOVE_ALLOWLIST[gameType] : undefined;
  const allowed = perGame && phase ? perGame[phase] : undefined;
  if (allowed && !allowed.includes(move.type)) {
    return { valid: false, error: `Move '${move.type}' not allowed in phase '${phase}'`, error_code: 'BAD_PHASE_MOVE' };
  }

  return { valid: true };
}

/**
 * Passthrough apply: merges the move data into the state.
 * The client is responsible for computing the new state;
 * this just records the move was accepted.
 */
export function passthroughApply(
  stateData: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  return {
    ...stateData,
    lastMove: {
      player_id: move.player_id,
      type: move.type,
      data: move.data,
    },
  };
}
