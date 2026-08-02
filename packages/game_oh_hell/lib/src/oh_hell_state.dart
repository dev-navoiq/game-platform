import 'package:game_core/game_core.dart';

/// Immutable game state for Oh Hell.
class OhHellState extends GameState {
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

  /// Seating order (fixed for the session).
  final List<String> playerOrder;

  /// Index of the current dealer in [playerOrder].
  final int dealerIndex;

  /// Cards in each player's hand.
  final Map<String, Hand> hands;

  /// Cards played in the current trick.
  final List<TrickCard> currentTrick;

  /// Number of cards dealt this round.
  final int cardsThisRound;

  /// Index into the round sequence (0-based).
  final int roundSequenceIndex;

  /// Total rounds in the sequence (derived from player count and any
  /// host-chosen length options).
  final int totalRounds;

  /// The full deal schedule for this session (e.g. [5,4,3,2,1,2,3,4,5]).
  /// Set at game creation so host-chosen length options survive into every
  /// new round. Null for states serialized before length options existed —
  /// consumers fall back to the classic full sequence.
  final List<int>? roundSequence;

  /// Bids placed this round (playerId → bid). Absent key = not yet bid.
  final Map<String, int> bids;

  /// Tricks won this round per player.
  final Map<String, int> tricksWon;

  /// Cumulative scores across all rounds.
  final Map<String, int> scores;

  /// One entry per completed round. Each entry maps playerId → points
  /// scored that round (0 = missed, otherwise 10 + bid). Used by the
  /// round-end scoreboard; empty until the first round completes.
  final List<Map<String, int>> roundHistory;

  OhHellState({
    required this.phase,
    this.currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
    required this.playerOrder,
    required this.dealerIndex,
    required this.hands,
    this.currentTrick = const [],
    required this.cardsThisRound,
    this.roundSequenceIndex = 0,
    required this.totalRounds,
    this.roundSequence,
    this.bids = const {},
    this.tricksWon = const {},
    this.scores = const {},
    this.roundHistory = const [],
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// ID of the next player after [currentPlayerId] (wraps around).
  String? get nextPlayerId {
    if (currentPlayerId == null) return null;
    final idx = playerOrder.indexOf(currentPlayerId!);
    if (idx < 0) return null;
    return playerOrder[(idx + 1) % playerOrder.length];
  }

  /// Whether the current bidder is the dealer (last to bid).
  bool get isDealerBidding =>
      currentPlayerId != null &&
      currentPlayerId == playerOrder[dealerIndex] &&
      bids.length == playerOrder.length - 1;

  /// The bid the dealer is forbidden from choosing (-1 if unrestricted or
  /// if the forbidden value is outside valid range [0, cardsThisRound]).
  int get forbiddenBidForDealer {
    if (!isDealerBidding) return -1;
    final sumSoFar = bids.values.fold<int>(0, (a, b) => a + b);
    final forbidden = cardsThisRound - sumSoFar;
    if (forbidden < 0 || forbidden > cardsThisRound) return -1;
    return forbidden;
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  @override
  OhHellState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    int? turnNumber,
    int? roundNumber,
    RoomSocialMode? socialMode,
    List<String>? playerOrder,
    int? dealerIndex,
    Map<String, Hand>? hands,
    List<TrickCard>? currentTrick,
    int? cardsThisRound,
    int? roundSequenceIndex,
    int? totalRounds,
    List<int>? roundSequence,
    Map<String, int>? bids,
    Map<String, int>? tricksWon,
    Map<String, int>? scores,
    List<Map<String, int>>? roundHistory,
  }) {
    return OhHellState(
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      socialMode: socialMode ?? this.socialMode,
      playerOrder: playerOrder ?? this.playerOrder,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      cardsThisRound: cardsThisRound ?? this.cardsThisRound,
      roundSequenceIndex: roundSequenceIndex ?? this.roundSequenceIndex,
      totalRounds: totalRounds ?? this.totalRounds,
      roundSequence: roundSequence ?? this.roundSequence,
      bids: bids ?? this.bids,
      tricksWon: tricksWon ?? this.tricksWon,
      scores: scores ?? this.scores,
      roundHistory: roundHistory ?? this.roundHistory,
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
        'dealerIndex': dealerIndex,
        'hands': hands.map((k, v) => MapEntry(k, v.toJson())),
        'currentTrick': currentTrick.map((c) => c.toJson()).toList(),
        'cardsThisRound': cardsThisRound,
        'roundSequenceIndex': roundSequenceIndex,
        'totalRounds': totalRounds,
        if (roundSequence != null) 'roundSequence': roundSequence,
        'bids': bids,
        'tricksWon': tricksWon,
        'scores': scores,
        'roundHistory': roundHistory,
        'socialMode': socialMode.name,
      };

  factory OhHellState.fromJson(Map<String, dynamic> json) {
    return OhHellState(
      phase: GamePhase.values.byName(json['phase'] as String),
      currentPlayerId: json['currentPlayerId'] as String?,
      turnNumber: (json['turnNumber'] as int?) ?? 0,
      roundNumber: (json['roundNumber'] as int?) ?? 1,
      playerOrder: List<String>.from(json['playerOrder'] as List),
      dealerIndex: json['dealerIndex'] as int,
      hands: (json['hands'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Hand.fromJson(v as List)),
      ),
      currentTrick: (json['currentTrick'] as List?)
              ?.map((c) => TrickCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      cardsThisRound: json['cardsThisRound'] as int,
      roundSequenceIndex: (json['roundSequenceIndex'] as int?) ?? 0,
      totalRounds: json['totalRounds'] as int,
      roundSequence: (json['roundSequence'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      bids: (json['bids'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {},
      tricksWon: (json['tricksWon'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {},
      scores: (json['scores'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {},
      roundHistory: (json['roundHistory'] as List?)
              ?.map((e) => (e as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, v as int)))
              .toList() ??
          const [],
      socialMode: RoomSocialModeWire.parse(json['socialMode'] as String?),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        currentPlayerId,
        turnNumber,
        roundNumber,
        playerOrder,
        dealerIndex,
        cardsThisRound,
        roundSequenceIndex,
        bids,
        tricksWon,
        scores,
        currentTrick,
        socialMode,
      ];
}
