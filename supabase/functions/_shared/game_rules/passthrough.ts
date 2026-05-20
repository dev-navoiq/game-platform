import { MovePayload, ValidationResult } from '../types.ts';

/**
 * Passthrough validator for games without full server-side rules.
 * Performs basic sanity checks only. Trusts the client for detailed logic.
 */
export function passthroughValidate(
  stateData: Record<string, unknown>,
  move: MovePayload,
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
