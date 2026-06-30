import 'package:game_core/game_core.dart';

import 'ludo_board.dart';
import 'ludo_token.dart';

class LudoState extends GameState {
  final List<String> playerIds;
  final List<LudoToken> tokens; // All tokens (all players) flat
  final Map<String, LudoColor> playerColors;
  final int currentPlayerIndex;
  final int? lastRoll;
  final int consecutiveSixes;
  final bool canRollAgain; // True after rolling a 6
  final List<String> finishedPlayers; // In order of finish
  final String? winnerId;

  @override
  final GamePhase phase;
  @override
  final int turnNumber;
  @override
  final int roundNumber;
  @override
  final RoomSocialMode socialMode;

  LudoState({
    required this.playerIds,
    required this.tokens,
    required this.playerColors,
    this.currentPlayerIndex = 0,
    this.lastRoll,
    this.consecutiveSixes = 0,
    this.canRollAgain = false,
    this.finishedPlayers = const [],
    this.winnerId,
    this.phase = GamePhase.playing,
    this.turnNumber = 1,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
  });

  factory LudoState.initial({
    required List<String> playerIds,
    int tokensPerPlayer = 4,
    RoomSocialMode socialMode = RoomSocialMode.full,
  }) {
    final colors = [
      LudoColor.red,
      LudoColor.blue,
      LudoColor.green,
      LudoColor.yellow,
    ];
    final playerColors = <String, LudoColor>{};
    final tokens = <LudoToken>[];

    for (var i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      final color = colors[i];
      playerColors[playerId] = color;
      for (var j = 0; j < tokensPerPlayer; j++) {
        tokens.add(LudoToken(
          id: '${playerId}_$j',
          color: color,
          position: LudoPosition.home(color, j),
        ));
      }
    }

    return LudoState(
      playerIds: playerIds,
      tokens: tokens,
      playerColors: playerColors,
      socialMode: socialMode,
    );
  }

  @override
  String get currentPlayerId => playerIds[currentPlayerIndex];

  /// The game ends once only one player is left unfinished — everyone else
  /// has brought all their tokens home and earned a placement. (For 2 players
  /// this collapses to "first to finish wins".)
  @override
  bool get isGameOver => finishedPlayers.length >= playerIds.length - 1;

  /// Tokens belonging to [playerId].
  List<LudoToken> tokensFor(String playerId) {
    final color = playerColors[playerId]!;
    return tokens.where((t) => t.color == color).toList();
  }

  /// All tokens at a given main-track position (for capture detection).
  List<LudoToken> tokensAtMain(int index) => tokens
      .where((t) =>
          t.position.zone == LudoZone.main && t.position.index == index)
      .toList();

  bool hasPlayerFinished(String playerId) =>
      tokensFor(playerId).every((t) => t.isFinished);

  LudoState copyWith({
    List<LudoToken>? tokens,
    int? currentPlayerIndex,
    int? lastRoll,
    bool clearRoll = false,
    int? consecutiveSixes,
    bool? canRollAgain,
    List<String>? finishedPlayers,
    String? winnerId,
    GamePhase? phase,
    int? turnNumber,
    RoomSocialMode? socialMode,
  }) =>
      LudoState(
        playerIds: playerIds,
        tokens: tokens ?? this.tokens,
        playerColors: playerColors,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        lastRoll: clearRoll ? null : (lastRoll ?? this.lastRoll),
        consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
        canRollAgain: canRollAgain ?? this.canRollAgain,
        finishedPlayers: finishedPlayers ?? this.finishedPlayers,
        winnerId: winnerId ?? this.winnerId,
        phase: phase ?? this.phase,
        turnNumber: turnNumber ?? this.turnNumber,
        roundNumber: roundNumber,
        socialMode: socialMode ?? this.socialMode,
      );

  factory LudoState.fromJson(Map<String, dynamic> json) => LudoState(
        playerIds: (json['playerIds'] as List).cast<String>(),
        tokens: (json['tokens'] as List)
            .map((t) => LudoToken.fromJson(t as Map<String, dynamic>))
            .toList(),
        playerColors: (json['playerColors'] as Map).map((k, v) =>
            MapEntry(k as String, LudoColor.values.byName(v as String))),
        currentPlayerIndex: json['currentPlayerIndex'] as int? ?? 0,
        lastRoll: json['lastRoll'] as int?,
        consecutiveSixes: json['consecutiveSixes'] as int? ?? 0,
        canRollAgain: json['canRollAgain'] as bool? ?? false,
        finishedPlayers:
            ((json['finishedPlayers'] as List?) ?? const []).cast<String>(),
        winnerId: json['winnerId'] as String?,
        phase: GamePhase.values.byName(json['phase'] as String? ?? 'playing'),
        turnNumber: json['turnNumber'] as int? ?? 1,
        roundNumber: json['roundNumber'] as int? ?? 1,
        socialMode: RoomSocialMode.values
            .byName(json['socialMode'] as String? ?? 'full'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'playerIds': playerIds,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'playerColors': playerColors.map((k, v) => MapEntry(k, v.name)),
        'currentPlayerIndex': currentPlayerIndex,
        if (lastRoll != null) 'lastRoll': lastRoll,
        'consecutiveSixes': consecutiveSixes,
        'canRollAgain': canRollAgain,
        'finishedPlayers': finishedPlayers,
        if (winnerId != null) 'winnerId': winnerId,
        'phase': phase.name,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'socialMode': socialMode.name,
      };

  @override
  List<Object?> get props => [
        playerIds,
        tokens,
        playerColors,
        currentPlayerIndex,
        lastRoll,
        consecutiveSixes,
        canRollAgain,
        finishedPlayers,
        winnerId,
        phase,
        turnNumber,
        socialMode,
      ];
}
