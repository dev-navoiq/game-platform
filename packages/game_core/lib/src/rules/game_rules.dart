import 'game_state.dart';
import 'game_move.dart';
import 'game_event.dart';

/// Result of attempting to apply a move.
/// On success [isValid] is true and [newState] holds the resulting state.
/// On failure [isValid] is false and [error] holds an error code string.
class MoveResult<TState extends GameState> {
  final TState? _newState;
  final bool isValid;
  final String? error;
  final List<GameEvent> events;

  MoveResult._({
    TState? newState,
    required this.isValid,
    this.error,
    this.events = const [],
  }) : _newState = newState;

  /// The resulting state. Throws if called on an invalid result.
  TState get newState => _newState!;

  /// Successful move result.
  factory MoveResult.valid({
    required TState newState,
    List<GameEvent> events = const [],
  }) =>
      MoveResult._(newState: newState, isValid: true, events: events);

  /// Failed move result.
  factory MoveResult.invalid({required String error}) =>
      MoveResult._(isValid: false, error: error);
}

/// Abstract rules engine for any game.
/// [TState] is the concrete game state; [TMove] is the concrete move type.
abstract class GameRules<TState extends GameState, TMove extends GameMove> {
  /// Minimum number of players required.
  int get minPlayers;

  /// Maximum number of players allowed.
  int get maxPlayers;

  /// Exact player counts supported (e.g. [4] for Twenty-Nine, [4,5,6,7,8] for Oh Hell).
  List<int> get validPlayerCounts;

  /// Create the initial state for a new game session.
  TState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  });

  /// Validate [move] against [state].
  /// Returns null if valid; returns an error code string if invalid.
  String? validateMove(TState state, TMove move);

  /// Return all moves that [playerId] may legally make in [state].
  List<TMove> getValidMoves(TState state, String playerId);

  /// Apply a (pre-validated) move and return the new state + emitted events.
  MoveResult<TState> applyMove(TState state, TMove move);

  /// Whether [state] represents a finished game.
  bool isGameOver(TState state);

  /// IDs of the winning player(s) at game end.
  List<String> getWinners(TState state);

  /// Current scores keyed by player ID.
  Map<String, int> calculateScores(TState state);

  /// ID of the next player to act, or null if no immediate next turn.
  String? getNextPlayer(TState state, List<String> playerIds);

  /// Apply server-side configuration overrides (hot-patchable via Shorebird).
  void applyServerConfig(Map<String, dynamic> config);
}
