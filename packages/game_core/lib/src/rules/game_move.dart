import 'package:equatable/equatable.dart';

/// Discriminated union of all move types across game categories.
enum MoveType {
  // Card games
  playCard,
  bid,
  pass,
  declareTrump,
  revealTrump,
  discard,
  draw,
  meld,

  // Board games
  movePiece,
  placePiece,
  capture,
  castle,
  promote,
  rollDice,

  // Universal
  resign,
  offerDraw,
  acceptDraw,
  timeout,
}

/// Base class for all game moves.
/// Each game package provides a concrete subclass.
abstract class GameMove extends Equatable {
  const GameMove();

  /// ID of the player making this move.
  String get playerId;

  /// Category of move.
  MoveType get type;

  /// Server-assigned timestamp (null until server processes the move).
  DateTime? get timestamp;

  /// Serialise for storage or Realtime transmission.
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props;
}
