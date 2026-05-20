import 'board_position.dart';
import 'board_state.dart';

/// Abstract movement/capture rules for a board game.
/// Concrete board-game packages extend this for their specific rules.
abstract class BoardRules<TState extends BoardState> {
  /// Valid destination positions for the piece at [from].
  List<BoardPosition> getValidMoves(TState state, BoardPosition from);

  /// Whether moving from [from] to [to] is legal.
  bool isValidMove(TState state, BoardPosition from, BoardPosition to);

  /// Apply the move and return the resulting state.
  TState applyMove(TState state, BoardPosition from, BoardPosition to);
}
