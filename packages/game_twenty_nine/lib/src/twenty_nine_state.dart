import 'package:game_core/game_core.dart';

/// Immutable game state for a session of Twenty-Nine.
class TwentyNineState extends GameState {
  @override
  final GamePhase phase;

  // Private backing field — allows the getter to narrow to non-nullable String,
  // matching what integration tests expect (leader = state.currentPlayerId as String).
  final String? _currentPlayerId;

  /// Always non-null during active play; narrows the base class's String? getter.
  @override
  String get currentPlayerId => _currentPlayerId!;

  @override
  final int turnNumber;

  @override
  final int roundNumber;

  @override
  final RoomSocialMode socialMode;

  @override
  bool get isGameOver => phase == GamePhase.gameEnd;

  /// Each player's current hand.
  final Map<String, Hand> hands;

  /// Cards played in the current trick (in play order).
  final List<TrickCard> currentTrick;

  /// Trump suit (chosen secretly by the bid winner; publicly revealed later).
  final Suit? trumpSuit;

  /// Whether trump has been publicly revealed.
  final bool trumpRevealed;

  /// Current highest bid value. 0 = no bid placed yet.
  final int currentBid;

  /// Player who placed the current winning bid.
  final String? bidderId;

  /// Player who selects trump (the bid winner).
  final String? trumpSelector;

  /// Index of the dealer in [playerOrder].
  final int dealerIndex;

  /// Clockwise seating order.
  final List<String> playerOrder;

  /// Game-level scores (first to 6 wins). Keyed by team index (0 or 1).
  final Map<int, int> sessionScores;

  /// Whether all players passed with no bid placed (triggers redeal).
  final bool allPlayersPassed;

  // ── Internal tracking fields (not in test constructor but needed by rules) ──

  /// Points accumulated by each team this round.
  final Map<int, int> teamPoints;

  /// Tricks won by each team this round (for round-end detection).
  final Map<int, int> tricksWon;

  /// Number of consecutive passes since the last bid.
  final int passCount;

  /// Scoring multiplier from double/redouble. 1 = undoubled, 2 = doubled,
  /// 4 = redoubled.
  final int doublingMultiplier;

  /// Player ID that called "Double" on the current contract (null if undoubled).
  final String? doubledBy;

  /// Player ID that called "Redouble" (null if not redoubled).
  final String? redoubledBy;

  /// Player who revealed trump in the current trick, if any. They are
  /// required to play a trump card on this very trick (if they hold one).
  final String? trumpRevealerThisTrick;

  TwentyNineState({
    required this.phase,
    String? currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
    required this.hands,
    this.currentTrick = const [],
    this.trumpSuit,
    this.trumpRevealed = false,
    this.currentBid = 0,
    this.bidderId,
    this.trumpSelector,
    required this.dealerIndex,
    required this.playerOrder,
    this.sessionScores = const {0: 0, 1: 0},
    this.allPlayersPassed = false,
    this.teamPoints = const {0: 0, 1: 0},
    this.tricksWon = const {0: 0, 1: 0},
    this.passCount = 0,
    this.doublingMultiplier = 1,
    this.doubledBy,
    this.redoubledBy,
    this.trumpRevealerThisTrick,
  }) : _currentPlayerId = currentPlayerId;

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Minimum valid bid. 15 if no bid placed; current bid + 1 otherwise.
  int get minimumBid => currentBid == 0 ? 15 : currentBid + 1;

  /// Team index (0 or 1) for [playerId].
  /// Seats 0 & 2 are team 0; seats 1 & 3 are team 1.
  int teamForPlayer(String playerId) {
    final index = playerOrder.indexOf(playerId);
    return index % 2;
  }

  /// Partner's player ID (2 seats away in playerOrder).
  String? getPartner(String playerId) {
    final index = playerOrder.indexOf(playerId);
    if (index < 0) return null;
    return playerOrder[(index + 2) % playerOrder.length];
  }

  /// ID of the next player after [currentPlayerId] (wraps around).
  String? get nextPlayerId {
    final index = playerOrder.indexOf(currentPlayerId);
    if (index < 0) return null;
    return playerOrder[(index + 1) % playerOrder.length];
  }

  /// Team index of the bid winner.
  int? get bidWinnerTeam =>
      bidderId != null ? teamForPlayer(bidderId!) : null;

  // ── copyWith ────────────────────────────────────────────────────────────────

  TwentyNineState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    int? turnNumber,
    int? roundNumber,
    RoomSocialMode? socialMode,
    Map<String, Hand>? hands,
    List<TrickCard>? currentTrick,
    Suit? trumpSuit,
    bool? trumpRevealed,
    int? currentBid,
    String? bidderId,
    String? trumpSelector,
    int? dealerIndex,
    List<String>? playerOrder,
    Map<int, int>? sessionScores,
    bool? allPlayersPassed,
    Map<int, int>? teamPoints,
    Map<int, int>? tricksWon,
    int? passCount,
    int? doublingMultiplier,
    String? doubledBy,
    String? redoubledBy,
    String? trumpRevealerThisTrick,
    bool clearTrumpRevealer = false,
  }) {
    return TwentyNineState(
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      socialMode: socialMode ?? this.socialMode,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      trumpRevealed: trumpRevealed ?? this.trumpRevealed,
      currentBid: currentBid ?? this.currentBid,
      bidderId: bidderId ?? this.bidderId,
      trumpSelector: trumpSelector ?? this.trumpSelector,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      playerOrder: playerOrder ?? this.playerOrder,
      sessionScores: sessionScores ?? this.sessionScores,
      allPlayersPassed: allPlayersPassed ?? this.allPlayersPassed,
      teamPoints: teamPoints ?? this.teamPoints,
      tricksWon: tricksWon ?? this.tricksWon,
      passCount: passCount ?? this.passCount,
      doublingMultiplier: doublingMultiplier ?? this.doublingMultiplier,
      doubledBy: doubledBy ?? this.doubledBy,
      redoubledBy: redoubledBy ?? this.redoubledBy,
      trumpRevealerThisTrick: clearTrumpRevealer
          ? null
          : (trumpRevealerThisTrick ?? this.trumpRevealerThisTrick),
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'currentPlayerId': currentPlayerId,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'hands': hands.map((k, v) => MapEntry(k, v.toJson())),
        'currentTrick': currentTrick.map((c) => c.toJson()).toList(),
        'trumpSuit': trumpSuit?.name,
        'trumpRevealed': trumpRevealed,
        'currentBid': currentBid,
        'bidderId': bidderId,
        'trumpSelector': trumpSelector,
        'dealerIndex': dealerIndex,
        'playerOrder': playerOrder,
        'sessionScores':
            sessionScores.map((k, v) => MapEntry(k.toString(), v)),
        'allPlayersPassed': allPlayersPassed,
        'teamPoints': teamPoints.map((k, v) => MapEntry(k.toString(), v)),
        'tricksWon': tricksWon.map((k, v) => MapEntry(k.toString(), v)),
        'passCount': passCount,
        'socialMode': socialMode.name,
        'doublingMultiplier': doublingMultiplier,
        'doubledBy': doubledBy,
        'redoubledBy': redoubledBy,
        'trumpRevealerThisTrick': trumpRevealerThisTrick,
      };

  factory TwentyNineState.fromJson(Map<String, dynamic> json) {
    return TwentyNineState(
      phase: GamePhase.values.byName(json['phase'] as String),
      currentPlayerId: json['currentPlayerId'] as String?,
      turnNumber: (json['turnNumber'] as int?) ?? 0,
      roundNumber: (json['roundNumber'] as int?) ?? 1,
      hands: (json['hands'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Hand.fromJson(v as List)),
      ),
      currentTrick: (json['currentTrick'] as List)
          .map((c) => TrickCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      trumpSuit: json['trumpSuit'] != null
          ? Suit.values.byName(json['trumpSuit'] as String)
          : null,
      trumpRevealed: (json['trumpRevealed'] as bool?) ?? false,
      currentBid: (json['currentBid'] as int?) ?? 0,
      bidderId: json['bidderId'] as String?,
      trumpSelector: json['trumpSelector'] as String?,
      dealerIndex: json['dealerIndex'] as int,
      playerOrder: List<String>.from(json['playerOrder'] as List),
      sessionScores: (json['sessionScores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      allPlayersPassed: (json['allPlayersPassed'] as bool?) ?? false,
      teamPoints: (json['teamPoints'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      tricksWon: (json['tricksWon'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      passCount: (json['passCount'] as int?) ?? 0,
      socialMode: json['socialMode'] != null
          ? RoomSocialMode.values.byName(json['socialMode'] as String)
          : RoomSocialMode.full,
      doublingMultiplier: (json['doublingMultiplier'] as int?) ?? 1,
      doubledBy: json['doubledBy'] as String?,
      redoubledBy: json['redoubledBy'] as String?,
      trumpRevealerThisTrick: json['trumpRevealerThisTrick'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        currentPlayerId,
        turnNumber,
        roundNumber,
        currentBid,
        bidderId,
        trumpSuit,
        trumpRevealed,
        trumpSelector,
        dealerIndex,
        playerOrder,
        sessionScores,
        allPlayersPassed,
        teamPoints,
        tricksWon,
        passCount,
        currentTrick,
        socialMode,
        doublingMultiplier,
        doubledBy,
        redoubledBy,
        trumpRevealerThisTrick,
      ];
}
