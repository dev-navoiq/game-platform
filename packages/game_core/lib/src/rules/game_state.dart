import 'package:equatable/equatable.dart';

import 'game_phase.dart';
import 'room_social_mode.dart';

/// Base class for all game states.
/// Each game package provides a concrete immutable subclass.
abstract class GameState extends Equatable {
  const GameState();

  /// Current phase of the game.
  GamePhase get phase;

  /// ID of the player whose turn it is; null between turns or during setup.
  String? get currentPlayerId;

  /// Turn number within the current round (1-based).
  int get turnNumber;

  /// Round number (1-based).
  int get roundNumber;

  /// Whether the game has finished.
  bool get isGameOver;

  /// Social mode inherited from the room — drives chat/voice/bubble visibility
  /// in the UI without requiring a DB round-trip on every frame.
  RoomSocialMode get socialMode;

  /// Serialise to JSON for storage or Realtime transmission.
  Map<String, dynamic> toJson();

  /// Return a copy with optional field overrides.
  GameState copyWith();

  @override
  List<Object?> get props;
}
