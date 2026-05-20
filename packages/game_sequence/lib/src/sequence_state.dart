import 'package:game_core/game_core.dart';

import 'sequence_board.dart';

class SequenceState extends GameState {
  final List<String> playerIds;
  final SequenceBoard board;
  final Map<String, List<PlayingCard>> playerHands;
  final Map<String, ChipColor> playerColors;
  final Map<ChipColor, int> sequenceCount; // sequences completed per color
  final int drawPileSize; // Remaining cards in the draw pile
  final List<PlayingCard> drawPile; // Actual draw pile
  final int currentPlayerIndex;
  final String? winnerId;

  @override
  final GamePhase phase;
  @override
  final int turnNumber;
  @override
  final int roundNumber;
  @override
  final RoomSocialMode socialMode;

  SequenceState({
    required this.playerIds,
    required this.board,
    required this.playerHands,
    required this.playerColors,
    required this.sequenceCount,
    required this.drawPile,
    this.currentPlayerIndex = 0,
    this.winnerId,
    this.phase = GamePhase.playing,
    this.turnNumber = 1,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
  }) : drawPileSize = drawPile.length;

  @override
  String get currentPlayerId => playerIds[currentPlayerIndex];

  @override
  bool get isGameOver => winnerId != null;

  SequenceState copyWith({
    SequenceBoard? board,
    Map<String, List<PlayingCard>>? playerHands,
    Map<ChipColor, int>? sequenceCount,
    List<PlayingCard>? drawPile,
    int? currentPlayerIndex,
    String? winnerId,
    GamePhase? phase,
    int? turnNumber,
    RoomSocialMode? socialMode,
  }) =>
      SequenceState(
        playerIds: playerIds,
        board: board ?? this.board,
        playerHands: playerHands ?? this.playerHands,
        playerColors: playerColors,
        sequenceCount: sequenceCount ?? this.sequenceCount,
        drawPile: drawPile ?? this.drawPile,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        winnerId: winnerId ?? this.winnerId,
        phase: phase ?? this.phase,
        turnNumber: turnNumber ?? this.turnNumber,
        roundNumber: roundNumber,
        socialMode: socialMode ?? this.socialMode,
      );

  @override
  Map<String, dynamic> toJson() => {
        'playerIds': playerIds,
        'playerHands': playerHands.map(
            (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
        'playerColors': playerColors.map((k, v) => MapEntry(k, v.name)),
        'sequenceCount': sequenceCount.map((k, v) => MapEntry(k.name, v)),
        'drawPileSize': drawPileSize,
        'currentPlayerIndex': currentPlayerIndex,
        if (winnerId != null) 'winnerId': winnerId,
        'phase': phase.name,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'socialMode': socialMode.name,
      };

  @override
  List<Object?> get props => [
        playerIds,
        board,
        playerHands,
        playerColors,
        sequenceCount,
        drawPileSize,
        currentPlayerIndex,
        winnerId,
        phase,
        turnNumber,
        socialMode,
      ];
}
