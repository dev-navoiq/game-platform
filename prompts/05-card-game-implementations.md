# 04 - Card Game Implementations

> Implement concrete card games extending the game_core framework.

## Task

Create game packages for:
- Twenty-Nine (4 players, 2v2 teams, bidding, trump)
- Oh Hell (4-8 players, free-for-all, trick prediction)
- Hearts (4 players, avoid points)
- Spades (4 players, 2v2, bidding)
- Bridge (4 players, 2v2, complex bidding)
- Rummy (2-6 players, set collection)

Each game follows the same package structure and extends `game_core`.

---

## Package Structure Template

```
packages/game_{name}/
├── lib/
│   ├── game_{name}.dart           # Main export
│   └── src/
│       ├── {name}_config.dart     # Game configuration
│       ├── {name}_state.dart      # Game state
│       ├── {name}_move.dart       # Move types
│       ├── {name}_rules.dart      # Rules engine
│       ├── {name}_factory.dart    # Factory registration
│       └── {name}_scoring.dart    # Scoring logic
└── test/
    ├── {name}_rules_test.dart
    ├── {name}_state_test.dart
    └── {name}_integration_test.dart
```

---

## Twenty-Nine Implementation

### Config

```dart
// packages/game_twenty_nine/lib/src/twenty_nine_config.dart

import 'package:game_core/game_core.dart';

class TwentyNineConfig extends GameConfig {
  @override
  String get gameId => 'twenty_nine';

  @override
  String get displayName => 'Twenty-Nine';

  @override
  String get shortDescription => 'Classic trick-taking card game for 4 players';

  @override
  GameCategory get category => GameCategory.card;

  @override
  int get minPlayers => 4;

  @override
  int get maxPlayers => 4;

  @override
  List<int> get validPlayerCounts => [4];

  @override
  TeamConfig get teamConfig => TeamConfig.twoVsTwo;

  @override
  DeckConfig get deckConfig => DeckConfig.standard32;

  @override
  int cardsPerPlayer(int playerCount) => 8;

  @override
  int? get boardSize => null;

  @override
  bool get hasBidding => true;

  @override
  bool get hasTrump => true;

  @override
  bool get hasTricks => true;

  @override
  bool get hasMelds => false;

  @override
  bool get hasDrawPile => false;

  @override
  String get assetDirectory => 'assets/games/twenty_nine';

  @override
  String get iconAsset => 'assets/icons/twenty_nine.png';

  @override
  String? get backgroundAsset => 'assets/games/twenty_nine/background.png';

  @override
  int get defaultTurnTimeout => 30;

  @override
  int get defaultGameTimeout => 1800; // 30 minutes

  // Game-specific constants
  static const int minBid = 15;
  static const int maxBid = 28;
  static const int specialBid29 = 29;
  static const int totalPoints = 28;

  // Card point values in 29
  static const Map<Rank, int> cardPoints = {
    Rank.jack: 3,
    Rank.nine: 2,
    Rank.ace: 1,
    Rank.ten: 1,
    Rank.king: 0,
    Rank.queen: 0,
    Rank.eight: 0,
    Rank.seven: 0,
  };

  static int getCardPoints(PlayingCard card) {
    return cardPoints[card.rank] ?? 0;
  }

  @override
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'displayName': displayName,
    'minPlayers': minPlayers,
    'maxPlayers': maxPlayers,
    'deckConfig': deckConfig.name,
    'teamConfig': teamConfig.structure.name,
  };
}
```

### State

```dart
// packages/game_twenty_nine/lib/src/twenty_nine_state.dart

import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

class TwentyNineState extends GameState with EquatableMixin {
  @override
  final GamePhase phase;

  @override
  final String? currentPlayerId;

  @override
  final int turnNumber;

  @override
  final int roundNumber;

  /// Player hands (hidden from other players)
  final Map<String, Hand> hands;

  /// Current trick being played
  final List<TrickCard> currentTrick;

  /// Tricks won by each team
  final Map<int, int> tricksWon;

  /// Points collected by each team
  final Map<int, int> teamPoints;

  /// Session scores (across multiple games)
  final Map<int, int> sessionScores;

  /// Dealer seat index
  final int dealerIndex;

  /// Current bid value
  final int? currentBid;

  /// ID of player who made current bid
  final String? bidderId;

  /// Number of players who passed
  final int passCount;

  /// Trump suit (hidden until revealed)
  final Suit? trumpSuit;

  /// Has trump been revealed?
  final bool trumpRevealed;

  /// ID of player who selects trump (bid winner's partner)
  final String? trumpSelector;

  /// Lead suit for current trick
  final Suit? leadSuit;

  /// Is this a seventh card trump reveal?
  final bool seventhCardTrump;

  /// Player order (clockwise from dealer)
  final List<String> playerOrder;

  TwentyNineState({
    required this.phase,
    this.currentPlayerId,
    this.turnNumber = 0,
    this.roundNumber = 1,
    required this.hands,
    this.currentTrick = const [],
    this.tricksWon = const {0: 0, 1: 0},
    this.teamPoints = const {0: 0, 1: 0},
    this.sessionScores = const {0: 0, 1: 0},
    required this.dealerIndex,
    this.currentBid,
    this.bidderId,
    this.passCount = 0,
    this.trumpSuit,
    this.trumpRevealed = false,
    this.trumpSelector,
    this.leadSuit,
    this.seventhCardTrump = false,
    required this.playerOrder,
  });

  @override
  bool get isGameOver => phase == GamePhase.gameEnd;

  /// Get player's team (0 or 1)
  int getTeamForPlayer(String playerId) {
    final index = playerOrder.indexOf(playerId);
    return index % 2; // 0,2 = team 0; 1,3 = team 1
  }

  /// Get partner's ID
  String? getPartner(String playerId) {
    final index = playerOrder.indexOf(playerId);
    if (index < 0) return null;
    final partnerIndex = (index + 2) % 4;
    return playerOrder[partnerIndex];
  }

  /// Check if trick is complete
  bool get isTrickComplete => currentTrick.length == 4;

  /// Get minimum valid bid (current bid + 1, or 15 if no bid)
  int get minimumBid => (currentBid ?? 14) + 1;

  /// Check if all players have passed
  bool get allPlayersPassed => passCount >= 4;

  /// Get bid winner team
  int? get bidWinnerTeam =>
      bidderId != null ? getTeamForPlayer(bidderId!) : null;

  TwentyNineState copyWith({
    GamePhase? phase,
    String? currentPlayerId,
    int? turnNumber,
    int? roundNumber,
    Map<String, Hand>? hands,
    List<TrickCard>? currentTrick,
    Map<int, int>? tricksWon,
    Map<int, int>? teamPoints,
    Map<int, int>? sessionScores,
    int? dealerIndex,
    int? currentBid,
    String? bidderId,
    int? passCount,
    Suit? trumpSuit,
    bool? trumpRevealed,
    String? trumpSelector,
    Suit? leadSuit,
    bool? seventhCardTrump,
    List<String>? playerOrder,
  }) {
    return TwentyNineState(
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      tricksWon: tricksWon ?? this.tricksWon,
      teamPoints: teamPoints ?? this.teamPoints,
      sessionScores: sessionScores ?? this.sessionScores,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      currentBid: currentBid ?? this.currentBid,
      bidderId: bidderId ?? this.bidderId,
      passCount: passCount ?? this.passCount,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      trumpRevealed: trumpRevealed ?? this.trumpRevealed,
      trumpSelector: trumpSelector ?? this.trumpSelector,
      leadSuit: leadSuit ?? this.leadSuit,
      seventhCardTrump: seventhCardTrump ?? this.seventhCardTrump,
      playerOrder: playerOrder ?? this.playerOrder,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'currentPlayerId': currentPlayerId,
    'turnNumber': turnNumber,
    'roundNumber': roundNumber,
    'hands': hands.map((k, v) => MapEntry(k, v.toJson())),
    'currentTrick': currentTrick.map((c) => c.toJson()).toList(),
    'tricksWon': tricksWon.map((k, v) => MapEntry(k.toString(), v)),
    'teamPoints': teamPoints.map((k, v) => MapEntry(k.toString(), v)),
    'sessionScores': sessionScores.map((k, v) => MapEntry(k.toString(), v)),
    'dealerIndex': dealerIndex,
    'currentBid': currentBid,
    'bidderId': bidderId,
    'passCount': passCount,
    'trumpSuit': trumpSuit?.name,
    'trumpRevealed': trumpRevealed,
    'trumpSelector': trumpSelector,
    'leadSuit': leadSuit?.name,
    'seventhCardTrump': seventhCardTrump,
    'playerOrder': playerOrder,
  };

  factory TwentyNineState.fromJson(Map<String, dynamic> json) {
    return TwentyNineState(
      phase: GamePhase.values.byName(json['phase'] as String),
      currentPlayerId: json['currentPlayerId'] as String?,
      turnNumber: json['turnNumber'] as int,
      roundNumber: json['roundNumber'] as int,
      hands: (json['hands'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Hand.fromJson(v as List)),
      ),
      currentTrick: (json['currentTrick'] as List)
          .map((c) => TrickCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      tricksWon: (json['tricksWon'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      teamPoints: (json['teamPoints'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      sessionScores: (json['sessionScores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      dealerIndex: json['dealerIndex'] as int,
      currentBid: json['currentBid'] as int?,
      bidderId: json['bidderId'] as String?,
      passCount: json['passCount'] as int,
      trumpSuit: json['trumpSuit'] != null
          ? Suit.values.byName(json['trumpSuit'] as String)
          : null,
      trumpRevealed: json['trumpRevealed'] as bool,
      trumpSelector: json['trumpSelector'] as String?,
      leadSuit: json['leadSuit'] != null
          ? Suit.values.byName(json['leadSuit'] as String)
          : null,
      seventhCardTrump: json['seventhCardTrump'] as bool,
      playerOrder: List<String>.from(json['playerOrder'] as List),
    );
  }

  @override
  List<Object?> get props => [
    phase, currentPlayerId, turnNumber, roundNumber, hands,
    currentTrick, tricksWon, teamPoints, sessionScores, dealerIndex,
    currentBid, bidderId, passCount, trumpSuit, trumpRevealed,
    trumpSelector, leadSuit, seventhCardTrump, playerOrder,
  ];
}

/// A card played in a trick
class TrickCard extends Equatable {
  final String playerId;
  final PlayingCard card;
  final int seatIndex;

  const TrickCard({
    required this.playerId,
    required this.card,
    required this.seatIndex,
  });

  @override
  List<Object?> get props => [playerId, card, seatIndex];

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'card': card.toJson(),
    'seatIndex': seatIndex,
  };

  factory TrickCard.fromJson(Map<String, dynamic> json) => TrickCard(
    playerId: json['playerId'] as String,
    card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
    seatIndex: json['seatIndex'] as int,
  );
}
```

### Moves

```dart
// packages/game_twenty_nine/lib/src/twenty_nine_move.dart

import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

sealed class TwentyNineMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const TwentyNineMove({required this.playerId, this.timestamp});
}

/// Place a bid
class BidMove extends TwentyNineMove {
  final int bidValue;

  const BidMove({
    required super.playerId,
    required this.bidValue,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, bidValue, timestamp];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'bid',
    'playerId': playerId,
    'bidValue': bidValue,
    'timestamp': timestamp?.toIso8601String(),
  };
}

/// Pass on bidding
class PassMove extends TwentyNineMove {
  const PassMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.pass;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pass',
    'playerId': playerId,
    'timestamp': timestamp?.toIso8601String(),
  };
}

/// Declare trump suit
class DeclareTrumpMove extends TwentyNineMove {
  final Suit suit;

  const DeclareTrumpMove({
    required super.playerId,
    required this.suit,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.declareTrump;

  @override
  List<Object?> get props => [playerId, suit, timestamp];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'declareTrump',
    'playerId': playerId,
    'suit': suit.name,
    'timestamp': timestamp?.toIso8601String(),
  };
}

/// Play a card
class PlayCardMove extends TwentyNineMove {
  final PlayingCard card;

  const PlayCardMove({
    required super.playerId,
    required this.card,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.playCard;

  @override
  List<Object?> get props => [playerId, card, timestamp];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'playCard',
    'playerId': playerId,
    'card': card.toJson(),
    'timestamp': timestamp?.toIso8601String(),
  };
}

/// Reveal trump (when must trump)
class RevealTrumpMove extends TwentyNineMove {
  const RevealTrumpMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.revealTrump;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'revealTrump',
    'playerId': playerId,
    'timestamp': timestamp?.toIso8601String(),
  };
}

/// Parse move from JSON
TwentyNineMove parseTwentyNineMove(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final playerId = json['playerId'] as String;
  final timestamp = json['timestamp'] != null
      ? DateTime.parse(json['timestamp'] as String)
      : null;

  switch (type) {
    case 'bid':
      return BidMove(
        playerId: playerId,
        bidValue: json['bidValue'] as int,
        timestamp: timestamp,
      );
    case 'pass':
      return PassMove(playerId: playerId, timestamp: timestamp);
    case 'declareTrump':
      return DeclareTrumpMove(
        playerId: playerId,
        suit: Suit.values.byName(json['suit'] as String),
        timestamp: timestamp,
      );
    case 'playCard':
      return PlayCardMove(
        playerId: playerId,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
        timestamp: timestamp,
      );
    case 'revealTrump':
      return RevealTrumpMove(playerId: playerId, timestamp: timestamp);
    default:
      throw ArgumentError('Unknown move type: $type');
  }
}
```

### Rules

```dart
// packages/game_twenty_nine/lib/src/twenty_nine_rules.dart

import 'package:game_core/game_core.dart';
import 'twenty_nine_config.dart';
import 'twenty_nine_state.dart';
import 'twenty_nine_move.dart';

class TwentyNineRules extends GameRules<TwentyNineState, TwentyNineMove> {
  final TwentyNineConfig _config;
  Map<String, dynamic> _serverConfig = {};

  TwentyNineRules([TwentyNineConfig? config])
      : _config = config ?? TwentyNineConfig();

  @override
  int get minPlayers => _config.minPlayers;

  @override
  int get maxPlayers => _config.maxPlayers;

  @override
  int get teamCount => 2;

  @override
  List<int> get validPlayerCounts => _config.validPlayerCounts;

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  int get _turnTimeout =>
      _serverConfig['turn_timeout'] as int? ?? _config.defaultTurnTimeout;

  @override
  TwentyNineState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) {
      applyServerConfig(serverConfig);
    }

    // Create and shuffle deck
    final deck = Deck.standard32();
    deck.shuffle();

    // Deal 8 cards to each player
    final hands = <String, Hand>{};
    for (final playerId in playerIds) {
      hands[playerId] = Hand(deck.drawMany(8));
    }

    // First player to bid is left of dealer
    final firstBidder = playerIds[(dealerIndex + 1) % 4];

    return TwentyNineState(
      phase: GamePhase.bidding,
      currentPlayerId: firstBidder,
      hands: hands,
      dealerIndex: dealerIndex,
      playerOrder: playerIds,
    );
  }

  @override
  String? validateMove(TwentyNineState state, TwentyNineMove move) {
    // Check if it's the player's turn
    if (state.currentPlayerId != move.playerId) {
      return 'NOT_YOUR_TURN';
    }

    switch (move) {
      case BidMove():
        return _validateBid(state, move);
      case PassMove():
        return _validatePass(state, move);
      case DeclareTrumpMove():
        return _validateDeclareTrump(state, move);
      case PlayCardMove():
        return _validatePlayCard(state, move);
      case RevealTrumpMove():
        return _validateRevealTrump(state, move);
    }
  }

  String? _validateBid(TwentyNineState state, BidMove move) {
    if (state.phase != GamePhase.bidding) {
      return 'NOT_BIDDING_PHASE';
    }

    final minBid = state.minimumBid;
    final maxBid = TwentyNineConfig.maxBid;

    // Special case: 29 bid
    if (move.bidValue == TwentyNineConfig.specialBid29) {
      return null; // 29 is always valid
    }

    if (move.bidValue < minBid) {
      return 'BID_TOO_LOW';
    }

    if (move.bidValue > maxBid) {
      return 'BID_TOO_HIGH';
    }

    return null;
  }

  String? _validatePass(TwentyNineState state, PassMove move) {
    if (state.phase != GamePhase.bidding) {
      return 'NOT_BIDDING_PHASE';
    }
    return null;
  }

  String? _validateDeclareTrump(TwentyNineState state, DeclareTrumpMove move) {
    if (state.phase != GamePhase.trumpSelection) {
      return 'NOT_TRUMP_SELECTION_PHASE';
    }

    if (state.trumpSelector != move.playerId) {
      return 'NOT_TRUMP_SELECTOR';
    }

    // Check player has at least one card of declared suit
    final hand = state.hands[move.playerId];
    if (hand == null || !hand.hasSuit(move.suit)) {
      return 'NO_CARDS_OF_SUIT';
    }

    return null;
  }

  String? _validatePlayCard(TwentyNineState state, PlayCardMove move) {
    if (state.phase != GamePhase.playing) {
      return 'NOT_PLAYING_PHASE';
    }

    final hand = state.hands[move.playerId];
    if (hand == null) {
      return 'NO_HAND';
    }

    if (!hand.contains(move.card)) {
      return 'CARD_NOT_IN_HAND';
    }

    // Must follow lead suit if possible
    if (state.currentTrick.isNotEmpty) {
      final leadSuit = state.leadSuit!;
      if (move.card.suit != leadSuit && hand.hasSuit(leadSuit)) {
        return 'MUST_FOLLOW_SUIT';
      }
    }

    return null;
  }

  String? _validateRevealTrump(TwentyNineState state, RevealTrumpMove move) {
    if (state.phase != GamePhase.playing) {
      return 'NOT_PLAYING_PHASE';
    }

    if (state.trumpRevealed) {
      return 'TRUMP_ALREADY_REVEALED';
    }

    // Can only reveal if:
    // 1. Cannot follow suit AND
    // 2. Is the trump selector OR partner of trump selector
    final hand = state.hands[move.playerId];
    if (hand == null) return 'NO_HAND';

    if (state.currentTrick.isNotEmpty) {
      final leadSuit = state.leadSuit!;
      if (hand.hasSuit(leadSuit)) {
        return 'CAN_FOLLOW_SUIT';
      }
    }

    return null;
  }

  @override
  List<TwentyNineMove> getValidMoves(TwentyNineState state, String playerId) {
    if (state.currentPlayerId != playerId) {
      return [];
    }

    final moves = <TwentyNineMove>[];

    switch (state.phase) {
      case GamePhase.bidding:
        // Pass is always valid
        moves.add(PassMove(playerId: playerId));

        // Valid bids
        final minBid = state.minimumBid;
        for (var i = minBid; i <= TwentyNineConfig.maxBid; i++) {
          moves.add(BidMove(playerId: playerId, bidValue: i));
        }
        // 29 special bid
        moves.add(BidMove(playerId: playerId, bidValue: TwentyNineConfig.specialBid29));
        break;

      case GamePhase.trumpSelection:
        if (state.trumpSelector == playerId) {
          final hand = state.hands[playerId]!;
          for (final suit in Suit.values) {
            if (hand.hasSuit(suit)) {
              moves.add(DeclareTrumpMove(playerId: playerId, suit: suit));
            }
          }
        }
        break;

      case GamePhase.playing:
        final hand = state.hands[playerId]!;

        // If trump not revealed and can't follow suit, can reveal
        if (!state.trumpRevealed &&
            state.currentTrick.isNotEmpty &&
            !hand.hasSuit(state.leadSuit!)) {
          moves.add(RevealTrumpMove(playerId: playerId));
        }

        // Playable cards
        for (final card in hand.cards) {
          if (validateMove(state, PlayCardMove(playerId: playerId, card: card)) == null) {
            moves.add(PlayCardMove(playerId: playerId, card: card));
          }
        }
        break;

      default:
        break;
    }

    return moves;
  }

  @override
  MoveResult<TwentyNineState> applyMove(TwentyNineState state, TwentyNineMove move) {
    final error = validateMove(state, move);
    if (error != null) {
      return MoveResult.invalid(error);
    }

    switch (move) {
      case BidMove():
        return _applyBid(state, move);
      case PassMove():
        return _applyPass(state, move);
      case DeclareTrumpMove():
        return _applyDeclareTrump(state, move);
      case PlayCardMove():
        return _applyPlayCard(state, move);
      case RevealTrumpMove():
        return _applyRevealTrump(state, move);
    }
  }

  MoveResult<TwentyNineState> _applyBid(TwentyNineState state, BidMove move) {
    final nextPlayer = _getNextPlayer(state);
    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.bidPlaced,
        playerId: move.playerId,
        data: {'bidValue': move.bidValue},
      ),
    ];

    return MoveResult(
      newState: state.copyWith(
        currentBid: move.bidValue,
        bidderId: move.playerId,
        passCount: 0,
        currentPlayerId: nextPlayer,
      ),
      events: events,
    );
  }

  MoveResult<TwentyNineState> _applyPass(TwentyNineState state, PassMove move) {
    final newPassCount = state.passCount + 1;
    final events = <GameEvent>[];

    // If all other players passed and someone bid, bidding ends
    if (newPassCount >= 3 && state.bidderId != null) {
      // Move to trump selection
      final trumpSelector = state.getPartner(state.bidderId!)!;

      events.add(GameEvent(
        type: GameEventType.bidWon,
        playerId: state.bidderId,
        data: {'bidValue': state.currentBid},
      ));

      return MoveResult(
        newState: state.copyWith(
          phase: GamePhase.trumpSelection,
          passCount: newPassCount,
          currentPlayerId: trumpSelector,
          trumpSelector: trumpSelector,
        ),
        events: events,
      );
    }

    // If everyone passed with no bid, redeal
    if (newPassCount >= 4 && state.bidderId == null) {
      // TODO: Handle redeal
      return MoveResult(
        newState: state.copyWith(passCount: newPassCount),
        events: events,
      );
    }

    // Continue bidding
    final nextPlayer = _getNextPlayer(state);
    return MoveResult(
      newState: state.copyWith(
        passCount: newPassCount,
        currentPlayerId: nextPlayer,
      ),
      events: events,
    );
  }

  MoveResult<TwentyNineState> _applyDeclareTrump(
    TwentyNineState state,
    DeclareTrumpMove move,
  ) {
    // First player to play is left of dealer
    final firstPlayer = state.playerOrder[(state.dealerIndex + 1) % 4];

    return MoveResult(
      newState: state.copyWith(
        phase: GamePhase.playing,
        trumpSuit: move.suit,
        currentPlayerId: firstPlayer,
      ),
      events: [
        GameEvent(
          type: GameEventType.trumpRevealed,
          playerId: move.playerId,
          data: {'suit': move.suit.name, 'hidden': true},
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyPlayCard(
    TwentyNineState state,
    PlayCardMove move,
  ) {
    final newHands = Map<String, Hand>.from(state.hands);
    newHands[move.playerId] = state.hands[move.playerId]!.copy()
      ..remove(move.card);

    final seatIndex = state.playerOrder.indexOf(move.playerId);
    final newTrick = [
      ...state.currentTrick,
      TrickCard(
        playerId: move.playerId,
        card: move.card,
        seatIndex: seatIndex,
      ),
    ];

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.cardPlayed,
        playerId: move.playerId,
        data: {'card': move.card.toJson()},
      ),
    ];

    // Set lead suit if first card of trick
    final newLeadSuit = state.currentTrick.isEmpty
        ? move.card.suit
        : state.leadSuit;

    // Check if trick is complete
    if (newTrick.length == 4) {
      return _completeTrick(state, newTrick, newHands, events);
    }

    // Continue trick
    final nextPlayer = _getNextPlayer(state);
    return MoveResult(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        leadSuit: newLeadSuit,
        currentPlayerId: nextPlayer,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<TwentyNineState> _applyRevealTrump(
    TwentyNineState state,
    RevealTrumpMove move,
  ) {
    return MoveResult(
      newState: state.copyWith(trumpRevealed: true),
      events: [
        GameEvent(
          type: GameEventType.trumpRevealed,
          playerId: move.playerId,
          data: {'suit': state.trumpSuit!.name, 'hidden': false},
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _completeTrick(
    TwentyNineState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    List<GameEvent> events,
  ) {
    // Determine winner
    final winnerId = _determineTrickWinner(trick, state.leadSuit!, state.trumpSuit);
    final winnerTeam = state.getTeamForPlayer(winnerId);

    // Calculate points in trick
    var trickPoints = 0;
    for (final tc in trick) {
      trickPoints += TwentyNineConfig.getCardPoints(tc.card);
    }

    // Update scores
    final newTricksWon = Map<int, int>.from(state.tricksWon);
    newTricksWon[winnerTeam] = (newTricksWon[winnerTeam] ?? 0) + 1;

    final newTeamPoints = Map<int, int>.from(state.teamPoints);
    newTeamPoints[winnerTeam] = (newTeamPoints[winnerTeam] ?? 0) + trickPoints;

    events.add(GameEvent(
      type: GameEventType.trickWon,
      playerId: winnerId,
      data: {
        'team': winnerTeam,
        'points': trickPoints,
        'trick': trick.map((t) => t.toJson()).toList(),
      },
    ));

    // Check if round is over (all cards played)
    final totalTricks = newTricksWon.values.reduce((a, b) => a + b);
    if (totalTricks == 8) {
      return _completeRound(state, hands, newTricksWon, newTeamPoints, events);
    }

    // Winner leads next trick
    return MoveResult(
      newState: state.copyWith(
        hands: hands,
        currentTrick: [],
        tricksWon: newTricksWon,
        teamPoints: newTeamPoints,
        currentPlayerId: winnerId,
        leadSuit: null,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  String _determineTrickWinner(
    List<TrickCard> trick,
    Suit leadSuit,
    Suit? trumpSuit,
  ) {
    TrickCard? winner;

    for (final tc in trick) {
      if (winner == null) {
        winner = tc;
        continue;
      }

      final currentCard = tc.card;
      final winningCard = winner.card;

      // Trump beats non-trump
      if (trumpSuit != null) {
        if (currentCard.suit == trumpSuit && winningCard.suit != trumpSuit) {
          winner = tc;
          continue;
        }
        if (winningCard.suit == trumpSuit && currentCard.suit != trumpSuit) {
          continue;
        }
        // Both trump - higher wins
        if (currentCard.suit == trumpSuit && winningCard.suit == trumpSuit) {
          if (_cardStrength(currentCard) > _cardStrength(winningCard)) {
            winner = tc;
          }
          continue;
        }
      }

      // Must follow suit to win
      if (currentCard.suit != leadSuit) {
        continue;
      }

      // Higher card of lead suit wins
      if (_cardStrength(currentCard) > _cardStrength(winningCard)) {
        winner = tc;
      }
    }

    return winner!.playerId;
  }

  int _cardStrength(PlayingCard card) {
    // In 29: J > 9 > A > 10 > K > Q > 8 > 7
    switch (card.rank) {
      case Rank.jack: return 8;
      case Rank.nine: return 7;
      case Rank.ace: return 6;
      case Rank.ten: return 5;
      case Rank.king: return 4;
      case Rank.queen: return 3;
      case Rank.eight: return 2;
      case Rank.seven: return 1;
      default: return 0;
    }
  }

  MoveResult<TwentyNineState> _completeRound(
    TwentyNineState state,
    Map<String, Hand> hands,
    Map<int, int> tricksWon,
    Map<int, int> teamPoints,
    List<GameEvent> events,
  ) {
    final bidTeam = state.bidWinnerTeam!;
    final bidValue = state.currentBid!;
    final bidTeamPoints = teamPoints[bidTeam]!;

    // Check if bid team made their bid
    final bidMet = bidTeamPoints >= bidValue;

    // Calculate session score change
    final newSessionScores = Map<int, int>.from(state.sessionScores);
    if (bidMet) {
      // Bid team wins points
      newSessionScores[bidTeam] = (newSessionScores[bidTeam] ?? 0) + 1;
    } else {
      // Bid team loses, other team wins
      final otherTeam = (bidTeam + 1) % 2;
      newSessionScores[otherTeam] = (newSessionScores[otherTeam] ?? 0) + 1;
    }

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'bidTeam': bidTeam,
        'bidValue': bidValue,
        'bidTeamPoints': bidTeamPoints,
        'bidMet': bidMet,
        'sessionScores': newSessionScores,
      },
    ));

    // Check for game end (first to 6 wins)
    final gameOver = newSessionScores.values.any((score) => score >= 6);

    if (gameOver) {
      events.add(GameEvent(
        type: GameEventType.gameEnded,
        data: {'sessionScores': newSessionScores},
      ));

      return MoveResult(
        newState: state.copyWith(
          phase: GamePhase.gameEnd,
          hands: hands,
          currentTrick: [],
          tricksWon: tricksWon,
          teamPoints: teamPoints,
          sessionScores: newSessionScores,
          currentPlayerId: null,
        ),
        events: events,
      );
    }

    // Start new round
    return MoveResult(
      newState: state.copyWith(
        phase: GamePhase.roundEnd,
        hands: hands,
        currentTrick: [],
        tricksWon: tricksWon,
        teamPoints: teamPoints,
        sessionScores: newSessionScores,
        roundNumber: state.roundNumber + 1,
      ),
      events: events,
    );
  }

  String _getNextPlayer(TwentyNineState state) {
    final currentIndex = state.playerOrder.indexOf(state.currentPlayerId!);
    return state.playerOrder[(currentIndex + 1) % 4];
  }

  @override
  bool isGameOver(TwentyNineState state) => state.isGameOver;

  @override
  List<String> getWinners(TwentyNineState state) {
    if (!isGameOver(state)) return [];

    final team0Score = state.sessionScores[0] ?? 0;
    final team1Score = state.sessionScores[1] ?? 0;

    if (team0Score >= 6) {
      return [state.playerOrder[0], state.playerOrder[2]];
    } else if (team1Score >= 6) {
      return [state.playerOrder[1], state.playerOrder[3]];
    }
    return [];
  }

  @override
  Map<String, int> calculateScores(TwentyNineState state) {
    final scores = <String, int>{};
    for (final playerId in state.playerOrder) {
      final team = state.getTeamForPlayer(playerId);
      scores[playerId] = state.sessionScores[team] ?? 0;
    }
    return scores;
  }

  @override
  String? getNextPlayer(TwentyNineState state, List<String> playerIds) {
    return state.currentPlayerId;
  }
}
```

---

## Oh Hell Implementation

Similar structure but with:
- Variable player count (4-8)
- Variable cards per round (descending then ascending)
- Trick prediction bidding
- Bust rule (last bidder can't make total = tricks)
- Individual scoring: (bid + 1) * 10 if exact, 0 otherwise
- Hearts always trump

---

## Hearts Implementation

Key differences:
- 4 players, free-for-all
- Goal: avoid points (hearts = 1pt each, Queen of Spades = 13pts)
- Card passing between hands
- "Shooting the moon" mechanic
- Game ends when someone reaches 100 points

---

## Spades Implementation

Key differences:
- 4 players, 2v2 teams
- Spades always trump
- Blind nil bids
- Bag penalties
- Partnership scoring

---

## Expected Output

For each game:
- Complete config, state, move, and rules classes
- Factory for registration with GameRegistry
- Comprehensive unit tests
- Integration tests for full game flows
