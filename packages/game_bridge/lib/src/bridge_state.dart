import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

import 'bridge_config.dart';

/// One entry in the auction log — a bid/pass/double/redouble by a single seat.
class AuctionCall extends Equatable {
  final String playerId;
  final int seatIndex;

  /// One of: `bid`, `pass`, `double`, `redouble`.
  final String type;

  /// Only set when [type] == `bid`.
  final int? level;
  final BridgeDenomination? denomination;

  const AuctionCall({
    required this.playerId,
    required this.seatIndex,
    required this.type,
    this.level,
    this.denomination,
  });

  bool get isBid => type == 'bid';
  bool get isPass => type == 'pass';
  bool get isDouble => type == 'double';
  bool get isRedouble => type == 'redouble';

  @override
  List<Object?> get props => [playerId, seatIndex, type, level, denomination];

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'seatIndex': seatIndex,
        'type': type,
        if (level != null) 'level': level,
        if (denomination != null) 'denomination': denomination!.name,
      };

  factory AuctionCall.fromJson(Map<String, dynamic> json) => AuctionCall(
        playerId: json['playerId'] as String,
        seatIndex: json['seatIndex'] as int,
        type: json['type'] as String,
        level: json['level'] as int?,
        denomination: json['denomination'] != null
            ? BridgeDenomination.values.byName(json['denomination'] as String)
            : null,
      );
}

/// Settled contract once the auction concludes.
class BridgeContract extends Equatable {
  /// 1..7
  final int level;
  final BridgeDenomination denomination;
  final BridgeDoubleStatus doubleStatus;

  /// Player who first named the contract's denomination on the winning side.
  final String declarerId;
  final int declarerSeat;

  const BridgeContract({
    required this.level,
    required this.denomination,
    required this.doubleStatus,
    required this.declarerId,
    required this.declarerSeat,
  });

  /// Tricks the declaring side must take to fulfil the contract (6 + level).
  int get tricksRequired => 6 + level;

  String get declarerTeam => BridgeConfig.teamForSeat(declarerSeat);
  String get defenderTeam => declarerTeam == 'NS' ? 'EW' : 'NS';

  @override
  List<Object?> get props =>
      [level, denomination, doubleStatus, declarerId, declarerSeat];

  Map<String, dynamic> toJson() => {
        'level': level,
        'denomination': denomination.name,
        'doubleStatus': doubleStatus.name,
        'declarerId': declarerId,
        'declarerSeat': declarerSeat,
      };

  factory BridgeContract.fromJson(Map<String, dynamic> json) => BridgeContract(
        level: json['level'] as int,
        denomination:
            BridgeDenomination.values.byName(json['denomination'] as String),
        doubleStatus:
            BridgeDoubleStatus.values.byName(json['doubleStatus'] as String),
        declarerId: json['declarerId'] as String,
        declarerSeat: json['declarerSeat'] as int,
      );
}

/// Outcome of a single completed deal — feeds the round-end scoreboard.
class BridgeDealResult extends Equatable {
  final int dealNumber;
  final BridgeContract? contract;
  final Vulnerability vulnerability;

  /// Tricks taken by the declaring side. 0 if passed out.
  final int declarerTricks;

  /// True if contract was made (or no contract / passed out → false).
  final bool made;

  /// Positive number of overtricks (0 if exact or down).
  final int overtricks;

  /// Positive number of undertricks (0 if made or no contract).
  final int undertricks;

  /// Points scored by team NS this deal (can be 0 if passed out, never negative —
  /// defender penalty points are assigned to the defending team).
  final int nsPoints;
  final int ewPoints;

  const BridgeDealResult({
    required this.dealNumber,
    required this.contract,
    required this.vulnerability,
    required this.declarerTricks,
    required this.made,
    required this.overtricks,
    required this.undertricks,
    required this.nsPoints,
    required this.ewPoints,
  });

  bool get isPassedOut => contract == null;

  @override
  List<Object?> get props => [
        dealNumber,
        contract,
        vulnerability,
        declarerTricks,
        made,
        overtricks,
        undertricks,
        nsPoints,
        ewPoints,
      ];

  Map<String, dynamic> toJson() => {
        'dealNumber': dealNumber,
        'contract': contract?.toJson(),
        'vulnerability': vulnerability.name,
        'declarerTricks': declarerTricks,
        'made': made,
        'overtricks': overtricks,
        'undertricks': undertricks,
        'nsPoints': nsPoints,
        'ewPoints': ewPoints,
      };

  factory BridgeDealResult.fromJson(Map<String, dynamic> json) =>
      BridgeDealResult(
        dealNumber: json['dealNumber'] as int,
        contract: json['contract'] == null
            ? null
            : BridgeContract.fromJson(
                json['contract'] as Map<String, dynamic>),
        vulnerability:
            Vulnerability.values.byName(json['vulnerability'] as String),
        declarerTricks: json['declarerTricks'] as int,
        made: json['made'] as bool,
        overtricks: json['overtricks'] as int,
        undertricks: json['undertricks'] as int,
        nsPoints: json['nsPoints'] as int,
        ewPoints: json['ewPoints'] as int,
      );
}

/// Immutable Bridge game state.
class BridgeState extends GameState {
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

  /// Clockwise seating order. Seats 0/2 = team NS, seats 1/3 = team EW.
  final List<String> playerOrder;

  /// Index of the dealer for this deal.
  final int dealerIndex;

  /// Cards in each player's hand.
  final Map<String, Hand> hands;

  /// 1-based deal number (resets after game end → 1 on restart).
  final int dealNumber;

  /// Vulnerability for this deal.
  final Vulnerability vulnerability;

  // ── Auction ─────────────────────────────────────────────────────────────────

  /// Chronological auction log.
  final List<AuctionCall> auctionHistory;

  // ── Play ────────────────────────────────────────────────────────────────────

  /// Settled contract once auction ends (null while bidding or passed out).
  final BridgeContract? contract;

  /// Declarer's partner — their hand is revealed after the opening lead.
  final String? dummyId;

  /// True once the opening lead has been played and dummy is visible.
  final bool dummyRevealed;

  /// Cards in the current trick (cleared after each trick completes).
  final List<TrickCard> currentTrick;

  /// Tricks won this deal — keyed by team ("NS" / "EW").
  final Map<String, int> tricksWon;

  /// 0..12 — trick index within the deal.
  final int trickNumber;

  // ── Scores ──────────────────────────────────────────────────────────────────

  /// Cumulative team scores across all deals. Keyed by team ("NS" / "EW").
  final Map<String, int> scores;

  /// Per-deal results — populated as deals finish.
  final List<BridgeDealResult> dealHistory;

  /// Total deals in the session (Chicago default = 4).
  final int totalDeals;

  BridgeState({
    required this.phase,
    this.currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
    required this.playerOrder,
    required this.dealerIndex,
    required this.hands,
    required this.dealNumber,
    required this.vulnerability,
    this.auctionHistory = const [],
    this.contract,
    this.dummyId,
    this.dummyRevealed = false,
    this.currentTrick = const [],
    this.tricksWon = const {'NS': 0, 'EW': 0},
    this.trickNumber = 0,
    this.scores = const {'NS': 0, 'EW': 0},
    this.dealHistory = const [],
    this.totalDeals = BridgeConfig.totalDeals,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  String? get declarerId => contract?.declarerId;

  /// Whose seat-turn is it (raw current player, ignoring dummy proxy).
  int? get currentSeatIndex {
    if (currentPlayerId == null) return null;
    final i = playerOrder.indexOf(currentPlayerId!);
    return i < 0 ? null : i;
  }

  /// Next seat clockwise after [currentPlayerId].
  String? get nextPlayerId {
    if (currentPlayerId == null) return null;
    final i = playerOrder.indexOf(currentPlayerId!);
    if (i < 0) return null;
    return playerOrder[(i + 1) % playerOrder.length];
  }

  /// True while still in the auction.
  bool get isBidding => phase == GamePhase.bidding;

  // ── copyWith ────────────────────────────────────────────────────────────────

  @override
  BridgeState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    bool clearCurrentPlayer = false,
    int? turnNumber,
    int? roundNumber,
    RoomSocialMode? socialMode,
    List<String>? playerOrder,
    int? dealerIndex,
    Map<String, Hand>? hands,
    int? dealNumber,
    Vulnerability? vulnerability,
    List<AuctionCall>? auctionHistory,
    BridgeContract? contract,
    bool clearContract = false,
    String? dummyId,
    bool clearDummy = false,
    bool? dummyRevealed,
    List<TrickCard>? currentTrick,
    Map<String, int>? tricksWon,
    int? trickNumber,
    Map<String, int>? scores,
    List<BridgeDealResult>? dealHistory,
    int? totalDeals,
  }) {
    return BridgeState(
      phase: phase ?? this.phase,
      currentPlayerId: clearCurrentPlayer
          ? null
          : (currentPlayerId ?? this.currentPlayerId),
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      socialMode: socialMode ?? this.socialMode,
      playerOrder: playerOrder ?? this.playerOrder,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      hands: hands ?? this.hands,
      dealNumber: dealNumber ?? this.dealNumber,
      vulnerability: vulnerability ?? this.vulnerability,
      auctionHistory: auctionHistory ?? this.auctionHistory,
      contract: clearContract ? null : (contract ?? this.contract),
      dummyId: clearDummy ? null : (dummyId ?? this.dummyId),
      dummyRevealed: dummyRevealed ?? this.dummyRevealed,
      currentTrick: currentTrick ?? this.currentTrick,
      tricksWon: tricksWon ?? this.tricksWon,
      trickNumber: trickNumber ?? this.trickNumber,
      scores: scores ?? this.scores,
      dealHistory: dealHistory ?? this.dealHistory,
      totalDeals: totalDeals ?? this.totalDeals,
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'currentPlayerId': currentPlayerId,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'socialMode': socialMode.name,
        'playerOrder': playerOrder,
        'dealerIndex': dealerIndex,
        'hands': hands.map((k, v) => MapEntry(k, v.toJson())),
        'dealNumber': dealNumber,
        'vulnerability': vulnerability.name,
        'auctionHistory': auctionHistory.map((a) => a.toJson()).toList(),
        'contract': contract?.toJson(),
        'dummyId': dummyId,
        'dummyRevealed': dummyRevealed,
        'currentTrick': currentTrick.map((c) => c.toJson()).toList(),
        'tricksWon': tricksWon,
        'trickNumber': trickNumber,
        'scores': scores,
        'dealHistory': dealHistory.map((d) => d.toJson()).toList(),
        'totalDeals': totalDeals,
      };

  factory BridgeState.fromJson(Map<String, dynamic> json) {
    return BridgeState(
      phase: GamePhase.values.byName(json['phase'] as String),
      currentPlayerId: json['currentPlayerId'] as String?,
      turnNumber: (json['turnNumber'] as int?) ?? 0,
      roundNumber: (json['roundNumber'] as int?) ?? 1,
      socialMode: RoomSocialModeWire.parse(json['socialMode'] as String?),
      playerOrder: List<String>.from(json['playerOrder'] as List),
      dealerIndex: json['dealerIndex'] as int,
      hands: (json['hands'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Hand.fromJson(v as List)),
      ),
      dealNumber: json['dealNumber'] as int,
      vulnerability:
          Vulnerability.values.byName(json['vulnerability'] as String),
      auctionHistory: (json['auctionHistory'] as List?)
              ?.map((a) => AuctionCall.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      contract: json['contract'] == null
          ? null
          : BridgeContract.fromJson(json['contract'] as Map<String, dynamic>),
      dummyId: json['dummyId'] as String?,
      dummyRevealed: (json['dummyRevealed'] as bool?) ?? false,
      currentTrick: (json['currentTrick'] as List?)
              ?.map((c) => TrickCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      tricksWon: (json['tricksWon'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {'NS': 0, 'EW': 0},
      trickNumber: (json['trickNumber'] as int?) ?? 0,
      scores: (json['scores'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {'NS': 0, 'EW': 0},
      dealHistory: (json['dealHistory'] as List?)
              ?.map(
                  (d) => BridgeDealResult.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      totalDeals:
          (json['totalDeals'] as int?) ?? BridgeConfig.totalDeals,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        currentPlayerId,
        turnNumber,
        roundNumber,
        socialMode,
        playerOrder,
        dealerIndex,
        dealNumber,
        vulnerability,
        auctionHistory,
        contract,
        dummyId,
        dummyRevealed,
        currentTrick,
        tricksWon,
        trickNumber,
        scores,
      ];
}
