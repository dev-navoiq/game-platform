# 03 - Game Core Package

> Create the abstract game framework that all games will extend.

## Task

Build `packages/game_core/` with:
- Abstract interfaces for game state, moves, rules
- Card and deck primitives (for card games)
- Board primitives (for board games)
- Game registry for dynamic game discovery
- Configuration system for server-side tunables
- Asset management system

---

## Package Structure

```
packages/game_core/
├── lib/
│   ├── game_core.dart           # Main export
│   └── src/
│       ├── cards/
│       │   ├── playing_card.dart
│       │   ├── deck.dart
│       │   ├── hand.dart
│       │   └── dealer.dart
│       ├── board/
│       │   ├── board_position.dart
│       │   ├── board_piece.dart
│       │   ├── board_state.dart
│       │   └── board_rules.dart
│       ├── config/
│       │   ├── game_config.dart
│       │   ├── deck_config.dart
│       │   ├── team_config.dart
│       │   └── server_config.dart
│       ├── controller/
│       │   ├── game_controller.dart
│       │   └── game_player.dart
│       ├── registry/
│       │   ├── game_factory.dart
│       │   └── game_registry.dart
│       ├── rules/
│       │   ├── game_state.dart
│       │   ├── game_move.dart
│       │   ├── game_rules.dart
│       │   └── game_event.dart
│       ├── table/
│       │   ├── table_layout.dart
│       │   └── table_position.dart
│       └── assets/
│           └── game_assets.dart
└── test/
```

---

## Core Interfaces

### Game State

```dart
// lib/src/rules/game_state.dart

import 'package:equatable/equatable.dart';

/// Game phases that all games can use
enum GamePhase {
  setup,
  dealing,
  bidding,
  trumpSelection,
  cardPassing,
  playing,
  scoring,
  roundEnd,
  gameEnd,
}

/// Base class for all game states
/// Games extend this with their specific state properties
abstract class GameState extends Equatable {
  /// Current phase of the game
  GamePhase get phase;

  /// ID of player whose turn it is (null if waiting/between turns)
  String? get currentPlayerId;

  /// Current turn number within the round
  int get turnNumber;

  /// Current round number
  int get roundNumber;

  /// Whether the game has ended
  bool get isGameOver;

  /// Convert state to JSON for storage/transmission
  Map<String, dynamic> toJson();

  /// Create a copy with modified fields
  GameState copyWith();

  @override
  List<Object?> get props;
}
```

### Game Move

```dart
// lib/src/rules/game_move.dart

import 'package:equatable/equatable.dart';

/// Types of moves available across games
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

/// Base class for all game moves
abstract class GameMove extends Equatable {
  /// ID of player making the move
  String get playerId;

  /// Type of move
  MoveType get type;

  /// Timestamp of move (set by server)
  DateTime? get timestamp;

  /// Convert to JSON
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props;
}
```

### Game Rules

```dart
// lib/src/rules/game_rules.dart

/// Result of applying a move
class MoveResult<TState extends GameState> {
  final TState newState;
  final bool isValid;
  final String? errorCode;
  final List<GameEvent> events;

  MoveResult({
    required this.newState,
    this.isValid = true,
    this.errorCode,
    this.events = const [],
  });

  MoveResult.invalid(String error)
      : newState = null as TState,
        isValid = false,
        errorCode = error,
        events = const [];
}

/// Abstract rules engine for any game
/// TState: The game's state type
/// TMove: The game's move type
abstract class GameRules<TState extends GameState, TMove extends GameMove> {
  /// Minimum players required
  int get minPlayers;

  /// Maximum players allowed
  int get maxPlayers;

  /// Number of teams (0 for free-for-all)
  int get teamCount;

  /// Valid player counts (e.g., [4] for 29, [4,5,6,7,8] for Oh Hell)
  List<int> get validPlayerCounts;

  /// Create initial state for a new game
  TState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  });

  /// Validate a move against current state
  /// Returns null if valid, error code string if invalid
  String? validateMove(TState state, TMove move);

  /// Get all valid moves for a player
  List<TMove> getValidMoves(TState state, String playerId);

  /// Apply a validated move to produce new state
  MoveResult<TState> applyMove(TState state, TMove move);

  /// Check if game is over
  bool isGameOver(TState state);

  /// Get winner(s) - returns list of player IDs
  List<String> getWinners(TState state);

  /// Calculate current scores
  Map<String, int> calculateScores(TState state);

  /// Get next player after a move
  String? getNextPlayer(TState state, List<String> playerIds);

  /// Apply server config overrides
  void applyServerConfig(Map<String, dynamic> config);
}
```

### Game Events

```dart
// lib/src/rules/game_event.dart

import 'package:equatable/equatable.dart';

/// Events emitted during gameplay for UI/audio feedback
enum GameEventType {
  // Game flow
  gameStarted,
  roundStarted,
  roundEnded,
  gameEnded,

  // Card events
  cardsDealt,
  cardPlayed,
  trickWon,
  trickCollected,
  trumpRevealed,
  bidPlaced,
  bidWon,

  // Board events
  pieceMoved,
  pieceCaptured,
  piecePromoted,
  check,
  checkmate,
  stalemate,
  diceRolled,

  // Player events
  playerJoined,
  playerLeft,
  playerReconnected,
  playerTimeout,
  turnStarted,
  turnEnded,

  // Scoring
  pointsScored,
  bonusAwarded,
  penaltyApplied,
}

class GameEvent extends Equatable {
  final GameEventType type;
  final String? playerId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    this.playerId,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [type, playerId, data, timestamp];

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'playerId': playerId,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };
}
```

---

## Card Primitives

### Playing Card

```dart
// lib/src/cards/playing_card.dart

import 'package:equatable/equatable.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  two, three, four, five, six, seven, eight, nine, ten,
  jack, queen, king, ace
}

class PlayingCard extends Equatable implements Comparable<PlayingCard> {
  final Suit suit;
  final Rank rank;

  const PlayingCard(this.suit, this.rank);

  /// Create from short string like "AH" (Ace of Hearts)
  factory PlayingCard.fromString(String str) {
    final rankStr = str.substring(0, str.length - 1);
    final suitStr = str.substring(str.length - 1);

    final rank = _parseRank(rankStr);
    final suit = _parseSuit(suitStr);

    return PlayingCard(suit, rank);
  }

  /// Short string representation
  String toShortString() => '${_rankString(rank)}${_suitString(suit)}';

  /// Display string
  String get displayString => '${_rankDisplay(rank)}${_suitSymbol(suit)}';

  /// Suit symbol
  String get suitSymbol => _suitSymbol(suit);

  /// Rank display (A, K, Q, J, 10-2)
  String get rankDisplay => _rankDisplay(rank);

  /// Numeric rank value (for comparisons)
  int get rankValue => rank.index;

  /// Is this a face card?
  bool get isFaceCard =>
      rank == Rank.jack || rank == Rank.queen || rank == Rank.king;

  /// Is this suit red?
  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  @override
  int compareTo(PlayingCard other) {
    final suitCompare = suit.index.compareTo(other.suit.index);
    if (suitCompare != 0) return suitCompare;
    return rank.index.compareTo(other.rank.index);
  }

  @override
  List<Object?> get props => [suit, rank];

  Map<String, dynamic> toJson() => {
    'suit': suit.name,
    'rank': rank.name,
  };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
    Suit.values.byName(json['suit'] as String),
    Rank.values.byName(json['rank'] as String),
  );

  // Helper methods
  static Rank _parseRank(String s) {
    switch (s.toUpperCase()) {
      case 'A': return Rank.ace;
      case 'K': return Rank.king;
      case 'Q': return Rank.queen;
      case 'J': return Rank.jack;
      case '10': return Rank.ten;
      case '9': return Rank.nine;
      case '8': return Rank.eight;
      case '7': return Rank.seven;
      case '6': return Rank.six;
      case '5': return Rank.five;
      case '4': return Rank.four;
      case '3': return Rank.three;
      case '2': return Rank.two;
      default: throw ArgumentError('Invalid rank: $s');
    }
  }

  static Suit _parseSuit(String s) {
    switch (s.toUpperCase()) {
      case 'H': return Suit.hearts;
      case 'D': return Suit.diamonds;
      case 'C': return Suit.clubs;
      case 'S': return Suit.spades;
      default: throw ArgumentError('Invalid suit: $s');
    }
  }

  static String _rankString(Rank r) {
    switch (r) {
      case Rank.ace: return 'A';
      case Rank.king: return 'K';
      case Rank.queen: return 'Q';
      case Rank.jack: return 'J';
      case Rank.ten: return '10';
      default: return (r.index + 2).toString();
    }
  }

  static String _rankDisplay(Rank r) => _rankString(r);

  static String _suitString(Suit s) => s.name[0].toUpperCase();

  static String _suitSymbol(Suit s) {
    switch (s) {
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
      case Suit.spades: return '♠';
    }
  }
}
```

### Deck

```dart
// lib/src/cards/deck.dart

import 'dart:math';
import 'playing_card.dart';
import '../config/deck_config.dart';

class Deck {
  final List<PlayingCard> _cards;
  final Random _random;

  Deck._({required List<PlayingCard> cards, Random? random})
      : _cards = cards,
        _random = random ?? Random();

  /// Create a standard 52-card deck
  factory Deck.standard52({Random? random}) {
    final cards = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        cards.add(PlayingCard(suit, rank));
      }
    }
    return Deck._(cards: cards, random: random);
  }

  /// Create a 32-card deck (7 and up, for games like 29)
  factory Deck.standard32({Random? random}) {
    final cards = <PlayingCard>[];
    final validRanks = [
      Rank.seven, Rank.eight, Rank.nine, Rank.ten,
      Rank.jack, Rank.queen, Rank.king, Rank.ace,
    ];
    for (final suit in Suit.values) {
      for (final rank in validRanks) {
        cards.add(PlayingCard(suit, rank));
      }
    }
    return Deck._(cards: cards, random: random);
  }

  /// Create from config
  factory Deck.fromConfig(DeckConfig config, {Random? random}) {
    switch (config) {
      case DeckConfig.standard52:
        return Deck.standard52(random: random);
      case DeckConfig.standard32:
        return Deck.standard32(random: random);
      case DeckConfig.double52:
        final deck1 = Deck.standard52(random: random);
        final deck2 = Deck.standard52(random: random);
        return Deck._(
          cards: [...deck1._cards, ...deck2._cards],
          random: random,
        );
    }
  }

  /// Number of cards remaining
  int get remaining => _cards.length;

  /// Is deck empty?
  bool get isEmpty => _cards.isEmpty;

  /// Shuffle the deck
  void shuffle() {
    _cards.shuffle(_random);
  }

  /// Draw a card from top
  PlayingCard? draw() {
    if (_cards.isEmpty) return null;
    return _cards.removeLast();
  }

  /// Draw multiple cards
  List<PlayingCard> drawMany(int count) {
    final drawn = <PlayingCard>[];
    for (var i = 0; i < count && _cards.isNotEmpty; i++) {
      drawn.add(_cards.removeLast());
    }
    return drawn;
  }

  /// Peek at top card without removing
  PlayingCard? peek() => _cards.isEmpty ? null : _cards.last;

  /// Add cards back to deck
  void addCards(List<PlayingCard> cards) {
    _cards.addAll(cards);
  }

  /// Get all cards (for testing/debug)
  List<PlayingCard> get cards => List.unmodifiable(_cards);
}
```

### Hand

```dart
// lib/src/cards/hand.dart

import 'playing_card.dart';

class Hand {
  final List<PlayingCard> _cards;

  Hand([List<PlayingCard>? initial]) : _cards = List.from(initial ?? []);

  /// Number of cards in hand
  int get size => _cards.length;

  /// Is hand empty?
  bool get isEmpty => _cards.isEmpty;

  /// All cards in hand
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  /// Add a card to hand
  void add(PlayingCard card) {
    _cards.add(card);
  }

  /// Add multiple cards
  void addAll(List<PlayingCard> cards) {
    _cards.addAll(cards);
  }

  /// Remove a specific card
  bool remove(PlayingCard card) {
    return _cards.remove(card);
  }

  /// Remove card at index
  PlayingCard removeAt(int index) {
    return _cards.removeAt(index);
  }

  /// Check if hand contains a card
  bool contains(PlayingCard card) {
    return _cards.contains(card);
  }

  /// Check if hand has any card of a suit
  bool hasSuit(Suit suit) {
    return _cards.any((c) => c.suit == suit);
  }

  /// Get all cards of a suit
  List<PlayingCard> cardsOfSuit(Suit suit) {
    return _cards.where((c) => c.suit == suit).toList();
  }

  /// Sort hand by suit then rank
  void sort() {
    _cards.sort();
  }

  /// Sort by custom comparator
  void sortBy(int Function(PlayingCard a, PlayingCard b) compare) {
    _cards.sort(compare);
  }

  /// Clear hand
  void clear() {
    _cards.clear();
  }

  /// Create copy
  Hand copy() => Hand(List.from(_cards));

  List<Map<String, dynamic>> toJson() =>
      _cards.map((c) => c.toJson()).toList();

  factory Hand.fromJson(List<dynamic> json) => Hand(
    json.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>)).toList(),
  );
}
```

---

## Board Primitives

### Board Position

```dart
// lib/src/board/board_position.dart

import 'package:equatable/equatable.dart';

/// A position on a game board
class BoardPosition extends Equatable {
  final int row;
  final int col;

  const BoardPosition(this.row, this.col);

  /// Chess notation (a1-h8)
  factory BoardPosition.fromChessNotation(String notation) {
    final col = notation.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = int.parse(notation[1]) - 1;
    return BoardPosition(row, col);
  }

  /// Convert to chess notation
  String toChessNotation() {
    final colChar = String.fromCharCode('a'.codeUnitAt(0) + col);
    return '$colChar${row + 1}';
  }

  /// Check if position is valid for given board size
  bool isValidFor(int boardSize) {
    return row >= 0 && row < boardSize && col >= 0 && col < boardSize;
  }

  /// Manhattan distance to another position
  int distanceTo(BoardPosition other) {
    return (row - other.row).abs() + (col - other.col).abs();
  }

  /// Get adjacent positions
  List<BoardPosition> get adjacent {
    return [
      BoardPosition(row - 1, col),
      BoardPosition(row + 1, col),
      BoardPosition(row, col - 1),
      BoardPosition(row, col + 1),
    ];
  }

  /// Get diagonal positions
  List<BoardPosition> get diagonals {
    return [
      BoardPosition(row - 1, col - 1),
      BoardPosition(row - 1, col + 1),
      BoardPosition(row + 1, col - 1),
      BoardPosition(row + 1, col + 1),
    ];
  }

  @override
  List<Object?> get props => [row, col];

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory BoardPosition.fromJson(Map<String, dynamic> json) =>
      BoardPosition(json['row'] as int, json['col'] as int);
}
```

### Board Piece

```dart
// lib/src/board/board_piece.dart

import 'package:equatable/equatable.dart';

/// Type of piece (game-specific values)
abstract class PieceType {
  String get name;
  String get symbol;
}

/// A piece on the board
class BoardPiece<T extends PieceType> extends Equatable {
  final T type;
  final String ownerId;
  final int teamIndex;
  final bool hasMoved;

  const BoardPiece({
    required this.type,
    required this.ownerId,
    required this.teamIndex,
    this.hasMoved = false,
  });

  BoardPiece<T> copyWith({
    T? type,
    String? ownerId,
    int? teamIndex,
    bool? hasMoved,
  }) {
    return BoardPiece(
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      teamIndex: teamIndex ?? this.teamIndex,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  @override
  List<Object?> get props => [type, ownerId, teamIndex, hasMoved];
}
```

---

## Configuration System

### Game Config

```dart
// lib/src/config/game_config.dart

import 'deck_config.dart';
import 'team_config.dart';

/// Game category
enum GameCategory { card, board, dice }

/// Base configuration for any game
abstract class GameConfig {
  /// Unique identifier
  String get gameId;

  /// Display name
  String get displayName;

  /// Short description
  String get shortDescription;

  /// Category
  GameCategory get category;

  /// Player counts
  int get minPlayers;
  int get maxPlayers;
  List<int> get validPlayerCounts;

  /// Team configuration
  TeamConfig get teamConfig;

  /// For card games: deck configuration
  DeckConfig? get deckConfig;

  /// For card games: cards per player
  int cardsPerPlayer(int playerCount);

  /// For board games: board size
  int? get boardSize;

  /// Game features
  bool get hasBidding;
  bool get hasTrump;
  bool get hasTricks;
  bool get hasMelds;
  bool get hasDrawPile;

  /// Asset paths
  String get assetDirectory;
  String get iconAsset;
  String? get backgroundAsset;

  /// Default timeouts (can be overridden by server config)
  int get defaultTurnTimeout;
  int get defaultGameTimeout;

  /// Convert to JSON for storage
  Map<String, dynamic> toJson();
}
```

### Deck Config

```dart
// lib/src/config/deck_config.dart

enum DeckConfig {
  standard52,   // Full deck
  standard32,   // 7-A only (for 29)
  double52,     // Two decks (for Rummy, Sequence)
}

extension DeckConfigExtension on DeckConfig {
  int get cardCount {
    switch (this) {
      case DeckConfig.standard52:
        return 52;
      case DeckConfig.standard32:
        return 32;
      case DeckConfig.double52:
        return 104;
    }
  }

  String get displayName {
    switch (this) {
      case DeckConfig.standard52:
        return '52 Cards';
      case DeckConfig.standard32:
        return '32 Cards';
      case DeckConfig.double52:
        return 'Double Deck';
    }
  }
}
```

### Team Config

```dart
// lib/src/config/team_config.dart

enum TeamStructure {
  none,           // Free-for-all
  twoVsTwo,       // 2v2 (29, Spades)
  threeVsThree,   // 3v3
  custom,         // Variable teams
}

class TeamConfig {
  final TeamStructure structure;
  final int teamCount;
  final List<int>? teamSizes;

  const TeamConfig({
    required this.structure,
    this.teamCount = 0,
    this.teamSizes,
  });

  static const TeamConfig freeForAll = TeamConfig(
    structure: TeamStructure.none,
    teamCount: 0,
  );

  static const TeamConfig twoVsTwo = TeamConfig(
    structure: TeamStructure.twoVsTwo,
    teamCount: 2,
    teamSizes: [2, 2],
  );

  bool get hasTeams => structure != TeamStructure.none;

  int getTeamForSeat(int seatIndex, int playerCount) {
    if (!hasTeams) return -1;

    switch (structure) {
      case TeamStructure.twoVsTwo:
        return seatIndex % 2; // 0,2 = team 0; 1,3 = team 1
      case TeamStructure.threeVsThree:
        return seatIndex % 2;
      default:
        return -1;
    }
  }
}
```

---

## Game Registry

### Game Factory

```dart
// lib/src/registry/game_factory.dart

import '../config/game_config.dart';
import '../rules/game_state.dart';
import '../rules/game_move.dart';
import '../rules/game_rules.dart';

/// Factory for creating game instances
abstract class GameFactory<TState extends GameState, TMove extends GameMove> {
  /// Game configuration
  GameConfig get config;

  /// Create rules engine
  GameRules<TState, TMove> createRules();

  /// Create initial state
  TState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  });

  /// Parse a move from JSON
  TMove parseMoveFromJson(Map<String, dynamic> json);

  /// Parse state from JSON
  TState parseStateFromJson(Map<String, dynamic> json);
}
```

### Game Registry

```dart
// lib/src/registry/game_registry.dart

import '../config/game_config.dart';
import 'game_factory.dart';

/// Central registry for all available games
class GameRegistry {
  static final Map<String, GameFactory> _factories = {};

  /// Register a game factory
  static void register(GameFactory factory) {
    _factories[factory.config.gameId] = factory;
  }

  /// Unregister a game
  static void unregister(String gameId) {
    _factories.remove(gameId);
  }

  /// Clear all registrations
  static void clear() {
    _factories.clear();
  }

  /// Get factory by game ID
  static GameFactory? getFactory(String gameId) {
    return _factories[gameId];
  }

  /// Check if game is registered
  static bool isRegistered(String gameId) {
    return _factories.containsKey(gameId);
  }

  /// Get all available games
  static List<GameConfig> get availableGames {
    return _factories.values.map((f) => f.config).toList();
  }

  /// Get games for a specific player count
  static List<GameConfig> gamesForPlayerCount(int count) {
    return _factories.values
        .map((f) => f.config)
        .where((c) => c.validPlayerCounts.contains(count))
        .toList();
  }

  /// Get card games only
  static List<GameConfig> get cardGames {
    return _factories.values
        .map((f) => f.config)
        .where((c) => c.category == GameCategory.card)
        .toList();
  }

  /// Get board games only
  static List<GameConfig> get boardGames {
    return _factories.values
        .map((f) => f.config)
        .where((c) => c.category == GameCategory.board)
        .toList();
  }

  /// Get team games
  static List<GameConfig> get teamGames {
    return _factories.values
        .map((f) => f.config)
        .where((c) => c.teamConfig.hasTeams)
        .toList();
  }

  /// Get free-for-all games
  static List<GameConfig> get freeForAllGames {
    return _factories.values
        .map((f) => f.config)
        .where((c) => !c.teamConfig.hasTeams)
        .toList();
  }
}
```

---

## Main Export

```dart
// lib/game_core.dart

library game_core;

// Cards
export 'src/cards/playing_card.dart';
export 'src/cards/deck.dart';
export 'src/cards/hand.dart';
export 'src/cards/dealer.dart';

// Board
export 'src/board/board_position.dart';
export 'src/board/board_piece.dart';
export 'src/board/board_state.dart';
export 'src/board/board_rules.dart';

// Config
export 'src/config/game_config.dart';
export 'src/config/deck_config.dart';
export 'src/config/team_config.dart';
export 'src/config/server_config.dart';

// Controller
export 'src/controller/game_controller.dart';
export 'src/controller/game_player.dart';

// Registry
export 'src/registry/game_factory.dart';
export 'src/registry/game_registry.dart';

// Rules
export 'src/rules/game_state.dart';
export 'src/rules/game_move.dart';
export 'src/rules/game_rules.dart';
export 'src/rules/game_event.dart';

// Table
export 'src/table/table_layout.dart';
export 'src/table/table_position.dart';

// Assets
export 'src/assets/game_assets.dart';
```

---

## Expected Output

- Complete `game_core` package with all interfaces
- Type-safe generics for state and moves
- Card primitives (PlayingCard, Deck, Hand)
- Board primitives (BoardPosition, BoardPiece)
- Configuration system
- Game registry for dynamic discovery
- Full test coverage for card/board primitives
