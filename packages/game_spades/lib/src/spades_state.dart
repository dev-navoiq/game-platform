import 'package:game_core/game_core.dart';

/// Immutable game state for Spades.
class SpadesState extends GameState {
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

  /// Fixed seating order. Seats 0 & 2 = team 0; 1 & 3 = team 1.
  final List<String> playerOrder;

  /// Index of the current dealer.
  final int dealerIndex;

  /// Current hands.
  final Map<String, Hand> hands;

  /// Cards played in the current trick.
  final List<TrickCard> currentTrick;

  /// Individual bids (nil bid = 0 with nilBid flag set).
  final Map<String, int> bids;

  /// Whether each player bid nil.
  final Map<String, bool> isNilBid;

  /// Tricks won this round per player.
  final Map<String, int> playerTricksWon;

  /// Tricks won this round per team.
  final Map<int, int> teamTricksWon;

  /// Accumulated bags per team (carry over across rounds).
  final Map<int, int> teamBags;

  /// Cumulative game scores per team.
  final Map<int, int> teamScores;

  /// Whether spades have been broken (played on a non-spade lead trick).
  final bool spadesBroken;

  SpadesState({
    required this.phase,
    this.currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
    required this.playerOrder,
    required this.dealerIndex,
    required this.hands,
    this.currentTrick = const [],
    this.bids = const {},
    this.isNilBid = const {},
    this.playerTricksWon = const {},
    this.teamTricksWon = const {0: 0, 1: 0},
    this.teamBags = const {0: 0, 1: 0},
    this.teamScores = const {0: 0, 1: 0},
    this.spadesBroken = false,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  String? get nextPlayerId {
    if (currentPlayerId == null) return null;
    final idx = playerOrder.indexOf(currentPlayerId!);
    if (idx < 0) return null;
    return playerOrder[(idx + 1) % playerOrder.length];
  }

  int teamForPlayer(String playerId) {
    return playerOrder.indexOf(playerId) % 2;
  }

  int get team0Bid {
    final p0 = playerOrder[0];
    final p2 = playerOrder[2];
    return (bids[p0] ?? 0) + (bids[p2] ?? 0);
  }

  int get team1Bid {
    final p1 = playerOrder[1];
    final p3 = playerOrder[3];
    return (bids[p1] ?? 0) + (bids[p3] ?? 0);
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  @override
  SpadesState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    int? turnNumber,
    int? roundNumber,
    RoomSocialMode? socialMode,
    List<String>? playerOrder,
    int? dealerIndex,
    Map<String, Hand>? hands,
    List<TrickCard>? currentTrick,
    Map<String, int>? bids,
    Map<String, bool>? isNilBid,
    Map<String, int>? playerTricksWon,
    Map<int, int>? teamTricksWon,
    Map<int, int>? teamBags,
    Map<int, int>? teamScores,
    bool? spadesBroken,
  }) {
    return SpadesState(
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      socialMode: socialMode ?? this.socialMode,
      playerOrder: playerOrder ?? this.playerOrder,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      bids: bids ?? this.bids,
      isNilBid: isNilBid ?? this.isNilBid,
      playerTricksWon: playerTricksWon ?? this.playerTricksWon,
      teamTricksWon: teamTricksWon ?? this.teamTricksWon,
      teamBags: teamBags ?? this.teamBags,
      teamScores: teamScores ?? this.teamScores,
      spadesBroken: spadesBroken ?? this.spadesBroken,
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
        'bids': bids,
        'isNilBid': isNilBid,
        'playerTricksWon': playerTricksWon,
        'teamTricksWon':
            teamTricksWon.map((k, v) => MapEntry(k.toString(), v)),
        'teamBags': teamBags.map((k, v) => MapEntry(k.toString(), v)),
        'teamScores': teamScores.map((k, v) => MapEntry(k.toString(), v)),
        'spadesBroken': spadesBroken,
        'socialMode': socialMode.name,
      };

  @override
  List<Object?> get props => [
        phase,
        currentPlayerId,
        turnNumber,
        roundNumber,
        playerOrder,
        dealerIndex,
        bids,
        isNilBid,
        playerTricksWon,
        teamTricksWon,
        teamBags,
        teamScores,
        spadesBroken,
        currentTrick,
        socialMode,
      ];
}
