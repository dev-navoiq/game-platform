import 'package:equatable/equatable.dart';

/// Events emitted during gameplay for UI feedback, audio cues, and logging.
enum GameEventType {
  // Game flow
  gameStarted,
  roundStarted,
  roundEnded,
  gameEnded,

  // Card events
  cardsDealt,
  cardPlayed,
  trickWon,
  trickCollected,
  trumpRevealed,
  bidPlaced,
  bidWon,

  // Board events
  pieceMoved,
  pieceCaptured,
  piecePromoted,
  check,
  checkmate,
  stalemate,
  diceRolled,

  // Player events
  playerJoined,
  playerLeft,
  playerReconnected,
  playerTimeout,
  turnStarted,
  turnEnded,

  // Scoring
  pointsScored,
  bonusAwarded,
  penaltyApplied,

  // Deal events
  handDissolved,
}

class GameEvent extends Equatable {
  final GameEventType type;
  final String? playerId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    this.playerId,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [type, playerId, data, timestamp];

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'playerId': playerId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}
