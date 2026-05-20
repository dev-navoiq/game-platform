import { MovePayload, ValidationResult } from '../types.ts';
import { validateTwentyNineMove, applyTwentyNineMove } from './twenty_nine.ts';
import { validateOhHellMove, applyOhHellMove } from './oh_hell.ts';
import { passthroughValidate, passthroughApply } from './passthrough.ts';

/**
 * Dispatch move validation to the appropriate game-specific validator.
 * Returns {valid: true} if the move is legal, otherwise an error.
 */
export function validateMove(
  gameType: string,
  stateData: Record<string, unknown>,
  move: MovePayload,
): ValidationResult {
  switch (gameType) {
    case 'twenty_nine':
      return validateTwentyNineMove(stateData, move);
    case 'oh_hell':
      return validateOhHellMove(stateData, move);
    default:
      return passthroughValidate(stateData, move);
  }
}

/**
 * Apply a validated move to the game state.
 * Returns the new state_data object.
 */
export function applyMove(
  gameType: string,
  stateData: Record<string, unknown>,
  move: MovePayload,
): Record<string, unknown> {
  switch (gameType) {
    case 'twenty_nine':
      return applyTwentyNineMove(stateData, move);
    case 'oh_hell':
      return applyOhHellMove(stateData, move);
    default:
      return passthroughApply(stateData, move);
  }
}
