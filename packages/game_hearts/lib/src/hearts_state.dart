import 'package:game_core/game_core.dart';

import 'hearts_config.dart';

/// Immutable game state for Hearts.
class HeartsState extends GameState {
  @override
  final GamePhase phase;

  @override
  final String? currentPlayerId;

  @override
  final int turnNumber;

  @override
  final int roundNumber;

  @override
  final RoomSocialMode socialMode;

  @override
  bool get isGameOver => phase == GamePhase.gameEnd;

  /// Fixed seating order.
  final List<String> playerOrder;

  /// Current hands.
  final Map<String, Hand> hands;

  /// Cards played in the current trick.
  final List<TrickCard> currentTrick;

  /// Cumulative game scores.
  final Map<String, int> scores;

  /// Points taken this hand per player.
  final Map<String, int> handPoints;

  /// Whether at least one heart has been played as a discard.
  final bool heartsBroken;

  /// Cards each player has selected to pass (empty map = none selected yet).
  final Map<String, List<PlayingCard>> passSelections;

  /// Pass direction for this hand.
  final PassDirection passDirection;

  HeartsState({
    required this.phase,
    this.currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
    required this.playerOrder,
    required this.hands,
    this.currentTrick = const [],
    this.scores = const {},
    this.handPoints = const {},
    this.heartsBroken = false,
    this.passSelections = const {},
    this.passDirection = PassDirection.left,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  String? get nextPlayerId {
    if (currentPlayerId == null) return null;
    final idx = playerOrder.indexOf(currentPlayerId!);
    if (idx < 0) return null;
    return playerOrder[(idx + 1) % playerOrder.length];
  }

  /// Pass direction for a given [roundNumber].
  static PassDirection directionForRound(int round) {
    switch (round % 4) {
      case 1:
        return PassDirection.left;
      case 2:
        return PassDirection.right;
      case 3:
        return PassDirection.across;
      default: // 0
        return PassDirection.keep;
    }
  }

  /// Recipient index offset for the given [direction] and [playerCount].
  static int passOffset(PassDirection direction, int playerCount) {
    switch (direction) {
      case PassDirection.left:
        return 1;
      case PassDirection.right:
        return playerCount - 1;
      case PassDirection.across:
        return playerCount ~/ 2;
      case PassDirection.keep:
        return 0;
    }
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  @override
  HeartsState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    int? turnNumber,
    int? roundNumber,
    RoomSocialMode? socialMode,
    List<String>? playerOrder,
    Map<String, Hand>? hands,
    List<TrickCard>? currentTrick,
    Map<String, int>? scores,
    Map<String, int>? handPoints,
    bool? heartsBroken,
    Map<String, List<PlayingCard>>? passSelections,
    PassDirection? passDirection,
  }) {
    return HeartsState(
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      socialMode: socialMode ?? this.socialMode,
      playerOrder: playerOrder ?? this.playerOrder,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      scores: scores ?? this.scores,
      handPoints: handPoints ?? this.handPoints,
      heartsBroken: heartsBroken ?? this.heartsBroken,
      passSelections: passSelections ?? this.passSelections,
      passDirection: passDirection ?? this.passDirection,
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'currentPlayerId': currentPlayerId,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'playerOrder': playerOrder,
        'hands': hands.map((k, v) => MapEntry(k, v.toJson())),
        'currentTrick': currentTrick.map((c) => c.toJson()).toList(),
        'scores': scores,
        'handPoints': handPoints,
        'heartsBroken': heartsBroken,
        'passDirection': passDirection.name,
        'socialMode': socialMode.name,
      };

  @override
  List<Object?> get props => [
        phase,
        currentPlayerId,
        turnNumber,
        roundNumber,
        playerOrder,
        scores,
        handPoints,
        heartsBroken,
        currentTrick,
        passDirection,
        socialMode,
      ];
}
