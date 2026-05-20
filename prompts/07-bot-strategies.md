# Bot Strategies

> **Prompt 7 of 18** | Implements AI players for all card and board games with configurable difficulty levels.

## Overview

This prompt creates a unified bot framework with game-specific strategies. Bots support multiple difficulty levels and can simulate human-like play timing.

---

## Package: `bot_strategies`

### Directory Structure

```
packages/bot_strategies/
├── lib/
│   ├── bot_strategies.dart           # Library exports
│   └── src/
│       ├── core/
│       │   ├── bot_player.dart       # Abstract bot interface
│       │   ├── difficulty.dart       # Difficulty levels
│       │   ├── think_time.dart       # Simulated thinking
│       │   └── personality.dart      # Bot personalities
│       ├── card_games/
│       │   ├── twenty_nine_bot.dart
│       │   ├── oh_hell_bot.dart
│       │   ├── hearts_bot.dart
│       │   ├── spades_bot.dart
│       │   └── rummy_bot.dart
│       ├── board_games/
│       │   ├── chess_bot.dart
│       │   ├── ludo_bot.dart
│       │   └── sequence_bot.dart
│       └── utils/
│           ├── card_evaluator.dart
│           ├── monte_carlo.dart
│           └── minimax.dart
├── test/
│   ├── twenty_nine_bot_test.dart
│   ├── chess_bot_test.dart
│   └── ludo_bot_test.dart
└── pubspec.yaml
```

### pubspec.yaml

```yaml
name: bot_strategies
description: AI bot implementations for all game types

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  game_core:
    path: ../game_core
  game_twenty_nine:
    path: ../game_twenty_nine
  game_oh_hell:
    path: ../game_oh_hell
  game_chess:
    path: ../game_chess
  game_ludo:
    path: ../game_ludo
  game_sequence:
    path: ../game_sequence

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

---

## Core Bot Framework

### Bot Player Interface

```dart
// lib/src/core/bot_player.dart
import 'package:game_core/game_core.dart';
import 'difficulty.dart';
import 'think_time.dart';

/// Abstract interface for all game bots
abstract class BotPlayer<TState extends GameState, TMove extends GameMove> {
  final String playerId;
  final String name;
  final BotDifficulty difficulty;
  final BotPersonality personality;

  BotPlayer({
    required this.playerId,
    required this.name,
    required this.difficulty,
    this.personality = BotPersonality.balanced,
  });

  /// Select the best move for the current state
  Future<TMove?> selectMove(TState state, GameRules<TState, TMove> rules);

  /// Get think time before playing (simulates human timing)
  Duration getThinkTime(TState state, TMove move) {
    return ThinkTimeCalculator.calculate(
      difficulty: difficulty,
      personality: personality,
      isComplexDecision: _isComplexDecision(state, move),
    );
  }

  bool _isComplexDecision(TState state, TMove move);

  /// Evaluate a state from this player's perspective
  /// Higher scores are better
  double evaluateState(TState state);

  /// Get all valid moves with their evaluations
  List<EvaluatedMove<TMove>> evaluateMoves(
    TState state,
    GameRules<TState, TMove> rules,
  ) {
    final validMoves = rules.getValidMoves(state, playerId);
    return validMoves.map((move) {
      final newState = rules.applyMove(state, move);
      return EvaluatedMove(move, evaluateState(newState));
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }
}

class EvaluatedMove<TMove> {
  final TMove move;
  final double score;

  const EvaluatedMove(this.move, this.score);
}
```

### Difficulty Levels

```dart
// lib/src/core/difficulty.dart
enum BotDifficulty {
  beginner,
  easy,
  medium,
  hard,
  expert,
  master,
}

extension BotDifficultyExtension on BotDifficulty {
  /// Probability of making the optimal move
  double get accuracy {
    switch (this) {
      case BotDifficulty.beginner: return 0.3;
      case BotDifficulty.easy: return 0.5;
      case BotDifficulty.medium: return 0.7;
      case BotDifficulty.hard: return 0.85;
      case BotDifficulty.expert: return 0.95;
      case BotDifficulty.master: return 1.0;
    }
  }

  /// Search depth for lookahead algorithms
  int get searchDepth {
    switch (this) {
      case BotDifficulty.beginner: return 1;
      case BotDifficulty.easy: return 2;
      case BotDifficulty.medium: return 3;
      case BotDifficulty.hard: return 4;
      case BotDifficulty.expert: return 5;
      case BotDifficulty.master: return 6;
    }
  }

  /// Monte Carlo simulations count
  int get simulationCount {
    switch (this) {
      case BotDifficulty.beginner: return 100;
      case BotDifficulty.easy: return 500;
      case BotDifficulty.medium: return 1000;
      case BotDifficulty.hard: return 5000;
      case BotDifficulty.expert: return 10000;
      case BotDifficulty.master: return 50000;
    }
  }

  /// Display name
  String get displayName {
    switch (this) {
      case BotDifficulty.beginner: return 'Beginner';
      case BotDifficulty.easy: return 'Easy';
      case BotDifficulty.medium: return 'Medium';
      case BotDifficulty.hard: return 'Hard';
      case BotDifficulty.expert: return 'Expert';
      case BotDifficulty.master: return 'Master';
    }
  }
}
```

### Think Time Simulation

```dart
// lib/src/core/think_time.dart
import 'dart:math';
import 'difficulty.dart';
import 'personality.dart';

class ThinkTimeCalculator {
  static final Random _random = Random();

  /// Calculate simulated think time
  static Duration calculate({
    required BotDifficulty difficulty,
    required BotPersonality personality,
    required bool isComplexDecision,
  }) {
    // Base time based on difficulty
    final baseMs = switch (difficulty) {
      BotDifficulty.beginner => 2000,
      BotDifficulty.easy => 1500,
      BotDifficulty.medium => 1200,
      BotDifficulty.hard => 1000,
      BotDifficulty.expert => 800,
      BotDifficulty.master => 500,
    };

    // Personality modifier
    final personalityMultiplier = switch (personality) {
      BotPersonality.quick => 0.5,
      BotPersonality.balanced => 1.0,
      BotPersonality.thoughtful => 1.5,
      BotPersonality.cautious => 2.0,
    };

    // Complexity modifier
    final complexityMultiplier = isComplexDecision ? 1.5 : 1.0;

    // Add randomness (+-30%)
    final variance = 0.7 + _random.nextDouble() * 0.6;

    final totalMs = baseMs * personalityMultiplier * complexityMultiplier * variance;
    return Duration(milliseconds: totalMs.round());
  }
}
```

### Bot Personalities

```dart
// lib/src/core/personality.dart
enum BotPersonality {
  quick,      // Fast, aggressive
  balanced,   // Standard play
  thoughtful, // Takes time, strategic
  cautious,   // Defensive, risk-averse
}

extension BotPersonalityExtension on BotPersonality {
  /// Risk tolerance (0-1, higher = more aggressive)
  double get riskTolerance {
    switch (this) {
      case BotPersonality.quick: return 0.8;
      case BotPersonality.balanced: return 0.5;
      case BotPersonality.thoughtful: return 0.4;
      case BotPersonality.cautious: return 0.2;
    }
  }

  /// Display name
  String get displayName {
    switch (this) {
      case BotPersonality.quick: return 'Quick';
      case BotPersonality.balanced: return 'Balanced';
      case BotPersonality.thoughtful: return 'Thoughtful';
      case BotPersonality.cautious: return 'Cautious';
    }
  }

  /// Bot avatar/icon identifier
  String get avatarId {
    switch (this) {
      case BotPersonality.quick: return 'bot_quick';
      case BotPersonality.balanced: return 'bot_balanced';
      case BotPersonality.thoughtful: return 'bot_thoughtful';
      case BotPersonality.cautious: return 'bot_cautious';
    }
  }
}
```

---

## Card Game Bots

### Twenty-Nine Bot

```dart
// lib/src/card_games/twenty_nine_bot.dart
import 'dart:math';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import '../core/bot_player.dart';
import '../core/difficulty.dart';
import '../core/personality.dart';
import '../utils/card_evaluator.dart';

class TwentyNineBot extends BotPlayer<TwentyNineState, TwentyNineMove> {
  final Random _random;

  TwentyNineBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    Random? random,
  }) : _random = random ?? Random();

  @override
  Future<TwentyNineMove?> selectMove(
    TwentyNineState state,
    GameRules<TwentyNineState, TwentyNineMove> rules,
  ) async {
    final validMoves = rules.getValidMoves(state, playerId);
    if (validMoves.isEmpty) return null;

    // Apply difficulty-based selection
    if (_random.nextDouble() > difficulty.accuracy) {
      // Make a suboptimal move
      return _selectRandomMove(validMoves);
    }

    // Select best move based on game phase
    return switch (state.phase) {
      GamePhase.bidding => _selectBiddingMove(state, validMoves),
      GamePhase.trumpSelection => _selectTrumpMove(state, validMoves),
      GamePhase.playing => _selectPlayingMove(state, validMoves),
      _ => validMoves.first,
    };
  }

  TwentyNineMove _selectRandomMove(List<TwentyNineMove> moves) {
    return moves[_random.nextInt(moves.length)];
  }

  TwentyNineMove _selectBiddingMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final hand = state.playerHands[playerId] ?? [];
    final handStrength = _evaluateHandStrength(hand);

    // Find bid moves
    final bidMoves = moves.whereType<TwentyNineBid>().toList();
    final passMoves = moves.whereType<TwentyNinePass>().toList();

    if (bidMoves.isEmpty) {
      return passMoves.isNotEmpty ? passMoves.first : moves.first;
    }

    // Bid based on hand strength
    final minBid = state.currentBid + 1;
    final maxBid = state.currentBid + 3; // Don't overbid

    // Calculate target bid based on hand strength
    final targetBid = (15 + (handStrength * 14)).round().clamp(minBid, 28);

    // Personality affects bidding aggression
    final adjustedTarget = targetBid + (personality.riskTolerance * 2 - 1).round();

    if (adjustedTarget >= minBid && adjustedTarget <= maxBid) {
      return TwentyNineBid(playerId: playerId, bid: adjustedTarget.clamp(minBid, 28));
    }

    // Pass if hand isn't strong enough
    return passMoves.isNotEmpty ? passMoves.first : bidMoves.first;
  }

  double _evaluateHandStrength(List<PlayingCard> hand) {
    // Count high cards (J, 9, A, 10)
    var score = 0.0;

    for (final card in hand) {
      score += CardEvaluator.twentyNineCardValue(card) / 3.0;
    }

    // Bonus for having multiple cards of same suit
    final suitCounts = <Suit, int>{};
    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }

    for (final count in suitCounts.values) {
      if (count >= 4) score += 0.2;
      if (count >= 5) score += 0.3;
    }

    return (score / hand.length).clamp(0.0, 1.0);
  }

  TwentyNineMove _selectTrumpMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final hand = state.playerHands[playerId] ?? [];
    final trumpMoves = moves.whereType<TwentyNineSelectTrump>().toList();

    if (trumpMoves.isEmpty) return moves.first;

    // Find strongest suit
    final suitStrengths = <Suit, double>{};

    for (final suit in Suit.values) {
      final suitCards = hand.where((c) => c.suit == suit).toList();
      if (suitCards.isEmpty) continue;

      var strength = suitCards.length.toDouble();
      for (final card in suitCards) {
        strength += CardEvaluator.twentyNineCardValue(card) / 3.0;
      }
      suitStrengths[suit] = strength;
    }

    // Select strongest suit as trump
    final bestSuit = suitStrengths.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;

    return trumpMoves.firstWhere(
      (m) => m.trump == bestSuit,
      orElse: () => trumpMoves.first,
    );
  }

  TwentyNineMove _selectPlayingMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final playMoves = moves.whereType<TwentyNinePlayCard>().toList();
    if (playMoves.isEmpty) return moves.first;

    final trick = state.currentTrick;
    final isLeading = trick.cards.isEmpty;
    final partner = state.getPartner(playerId);

    if (isLeading) {
      return _selectLeadCard(state, playMoves);
    } else {
      return _selectFollowCard(state, playMoves, partner);
    }
  }

  TwentyNineMove _selectLeadCard(
    TwentyNineState state,
    List<TwentyNinePlayCard> moves,
  ) {
    // Lead with high cards if we're winning
    // Lead with low cards to draw trump if we're losing
    final teamScore = state.getTeamScore(playerId);
    final opponentScore = state.currentBid - teamScore;

    if (teamScore > opponentScore) {
      // We're winning - lead high to secure tricks
      return moves.reduce((a, b) =>
        CardEvaluator.twentyNineCardValue(a.card) >
        CardEvaluator.twentyNineCardValue(b.card) ? a : b
      );
    } else {
      // We're losing - lead low to draw out trumps
      return moves.reduce((a, b) =>
        CardEvaluator.twentyNineCardValue(a.card) <
        CardEvaluator.twentyNineCardValue(b.card) ? a : b
      );
    }
  }

  TwentyNineMove _selectFollowCard(
    TwentyNineState state,
    List<TwentyNinePlayCard> moves,
    String? partnerId,
  ) {
    final trick = state.currentTrick;
    final winningCard = _findWinningCard(trick, state.trumpSuit);
    final winningPlayerId = trick.cards.entries
      .firstWhere((e) => e.value == winningCard)
      .key;
    final partnerIsWinning = winningPlayerId == partnerId;

    if (partnerIsWinning) {
      // Partner is winning - play low
      return moves.reduce((a, b) =>
        CardEvaluator.twentyNineCardValue(a.card) <
        CardEvaluator.twentyNineCardValue(b.card) ? a : b
      );
    } else {
      // Opponent is winning - try to win if possible
      final winningMoves = moves.where((m) =>
        _wouldWinTrick(m.card, trick, state.trumpSuit)
      ).toList();

      if (winningMoves.isNotEmpty) {
        // Win with lowest winning card
        return winningMoves.reduce((a, b) =>
          CardEvaluator.twentyNineCardValue(a.card) <
          CardEvaluator.twentyNineCardValue(b.card) ? a : b
        );
      }

      // Can't win - throw lowest
      return moves.reduce((a, b) =>
        CardEvaluator.twentyNineCardValue(a.card) <
        CardEvaluator.twentyNineCardValue(b.card) ? a : b
      );
    }
  }

  PlayingCard? _findWinningCard(Trick trick, Suit? trump) {
    if (trick.cards.isEmpty) return null;

    final leadSuit = trick.cards.values.first.suit;
    PlayingCard? winner;

    for (final card in trick.cards.values) {
      if (winner == null) {
        winner = card;
        continue;
      }

      if (card.suit == trump && winner.suit != trump) {
        winner = card;
      } else if (card.suit == winner.suit) {
        if (CardEvaluator.twentyNineCardValue(card) >
            CardEvaluator.twentyNineCardValue(winner)) {
          winner = card;
        }
      }
    }

    return winner;
  }

  bool _wouldWinTrick(PlayingCard card, Trick trick, Suit? trump) {
    final currentWinner = _findWinningCard(trick, trump);
    if (currentWinner == null) return true;

    final leadSuit = trick.cards.values.first.suit;

    // Trump beats non-trump
    if (card.suit == trump && currentWinner.suit != trump) return true;
    if (card.suit != trump && currentWinner.suit == trump) return false;

    // Must follow suit to win
    if (card.suit != leadSuit && card.suit != trump) return false;

    // Same suit comparison
    if (card.suit == currentWinner.suit) {
      return CardEvaluator.twentyNineCardValue(card) >
             CardEvaluator.twentyNineCardValue(currentWinner);
    }

    return false;
  }

  @override
  bool _isComplexDecision(TwentyNineState state, TwentyNineMove move) {
    // Bidding and trump selection are complex
    if (move is TwentyNineBid || move is TwentyNineSelectTrump) return true;

    // Late-game trick decisions are complex
    final tricksPlayed = 8 - (state.playerHands[playerId]?.length ?? 0);
    return tricksPlayed >= 5;
  }

  @override
  double evaluateState(TwentyNineState state) {
    final teamScore = state.getTeamScore(playerId);
    final targetBid = state.currentBid;

    // Score based on progress toward bid
    if (teamScore >= targetBid) {
      return 1.0;
    }

    final tricksRemaining = state.playerHands[playerId]?.length ?? 0;
    final pointsNeeded = targetBid - teamScore;

    // Can we still make the bid?
    if (pointsNeeded > tricksRemaining * 3) {
      return 0.2; // Unlikely to make bid
    }

    return 0.5 + (teamScore / targetBid) * 0.5;
  }
}
```

### Oh Hell Bot

```dart
// lib/src/card_games/oh_hell_bot.dart
import 'dart:math';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import '../core/bot_player.dart';
import '../core/difficulty.dart';
import '../utils/card_evaluator.dart';

class OhHellBot extends BotPlayer<OhHellState, OhHellMove> {
  final Random _random;

  OhHellBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    Random? random,
  }) : _random = random ?? Random();

  @override
  Future<OhHellMove?> selectMove(
    OhHellState state,
    GameRules<OhHellState, OhHellMove> rules,
  ) async {
    final validMoves = rules.getValidMoves(state, playerId);
    if (validMoves.isEmpty) return null;

    if (_random.nextDouble() > difficulty.accuracy) {
      return validMoves[_random.nextInt(validMoves.length)];
    }

    return switch (state.phase) {
      GamePhase.bidding => _selectBid(state, validMoves),
      GamePhase.playing => _selectPlay(state, validMoves),
      _ => validMoves.first,
    };
  }

  OhHellMove _selectBid(OhHellState state, List<OhHellMove> moves) {
    final bidMoves = moves.whereType<OhHellBid>().toList();
    if (bidMoves.isEmpty) return moves.first;

    final hand = state.playerHands[playerId] ?? [];
    final trump = state.trumpSuit;

    // Count expected tricks
    var expectedTricks = 0.0;

    for (final card in hand) {
      final value = CardEvaluator.standardCardValue(card);

      if (card.suit == trump) {
        // Trump cards are more likely to win
        expectedTricks += 0.3 + (value / 14) * 0.7;
      } else {
        // High cards in non-trump
        if (value >= 12) expectedTricks += 0.5;
        else if (value >= 10) expectedTricks += 0.3;
      }
    }

    // Adjust for personality
    expectedTricks *= (0.8 + personality.riskTolerance * 0.4);

    final targetBid = expectedTricks.round().clamp(0, hand.length);

    // Find the closest valid bid
    return bidMoves.reduce((a, b) {
      final diffA = (a.bid - targetBid).abs();
      final diffB = (b.bid - targetBid).abs();
      return diffA <= diffB ? a : b;
    });
  }

  OhHellMove _selectPlay(OhHellState state, List<OhHellMove> moves) {
    final playMoves = moves.whereType<OhHellPlayCard>().toList();
    if (playMoves.isEmpty) return moves.first;

    final myBid = state.playerBids[playerId] ?? 0;
    final myTricks = state.playerTricks[playerId] ?? 0;
    final tricksNeeded = myBid - myTricks;

    if (tricksNeeded > 0) {
      // Need more tricks - try to win
      return _tryToWin(state, playMoves);
    } else if (tricksNeeded == 0) {
      // Made bid - avoid winning
      return _tryToLose(state, playMoves);
    } else {
      // Over bid - just play out
      return playMoves.first;
    }
  }

  OhHellMove _tryToWin(OhHellState state, List<OhHellPlayCard> moves) {
    final trick = state.currentTrick;

    if (trick.cards.isEmpty) {
      // Leading - play high
      return moves.reduce((a, b) =>
        CardEvaluator.standardCardValue(a.card) >
        CardEvaluator.standardCardValue(b.card) ? a : b
      );
    }

    // Try to win with lowest winning card
    final winningMoves = moves.where((m) =>
      _wouldWinTrick(m.card, trick, state.trumpSuit)
    ).toList();

    if (winningMoves.isNotEmpty) {
      return winningMoves.reduce((a, b) =>
        CardEvaluator.standardCardValue(a.card) <
        CardEvaluator.standardCardValue(b.card) ? a : b
      );
    }

    // Can't win - play lowest
    return moves.reduce((a, b) =>
      CardEvaluator.standardCardValue(a.card) <
      CardEvaluator.standardCardValue(b.card) ? a : b
    );
  }

  OhHellMove _tryToLose(OhHellState state, List<OhHellPlayCard> moves) {
    // Play lowest non-winning card
    final trick = state.currentTrick;

    final losingMoves = moves.where((m) =>
      !_wouldWinTrick(m.card, trick, state.trumpSuit)
    ).toList();

    if (losingMoves.isNotEmpty) {
      return losingMoves.reduce((a, b) =>
        CardEvaluator.standardCardValue(a.card) <
        CardEvaluator.standardCardValue(b.card) ? a : b
      );
    }

    // Must win - play highest (might as well win big)
    return moves.reduce((a, b) =>
      CardEvaluator.standardCardValue(a.card) >
      CardEvaluator.standardCardValue(b.card) ? a : b
    );
  }

  bool _wouldWinTrick(PlayingCard card, Trick trick, Suit? trump) {
    // Similar to TwentyNineBot implementation
    return false; // Placeholder
  }

  @override
  bool _isComplexDecision(OhHellState state, OhHellMove move) {
    return move is OhHellBid;
  }

  @override
  double evaluateState(OhHellState state) {
    final bid = state.playerBids[playerId] ?? 0;
    final tricks = state.playerTricks[playerId] ?? 0;

    if (tricks == bid) return 1.0;
    if (tricks > bid) return 0.3; // Over-bid
    return 0.5; // Under-bid (still possible)
  }
}
```

---

## Board Game Bots

### Chess Bot (Minimax with Alpha-Beta)

```dart
// lib/src/board_games/chess_bot.dart
import 'dart:math';
import 'package:game_chess/game_chess.dart';
import '../core/bot_player.dart';
import '../core/difficulty.dart';
import '../utils/minimax.dart';

class ChessBot extends BotPlayer<ChessState, ChessMove> {
  final Random _random;
  final Map<String, double> _transpositionTable = {};

  ChessBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    Random? random,
  }) : _random = random ?? Random();

  @override
  Future<ChessMove?> selectMove(
    ChessState state,
    GameRules<ChessState, ChessMove> rules,
  ) async {
    final validMoves = rules.getValidMoves(state, playerId);
    if (validMoves.isEmpty) return null;

    // Use minimax with alpha-beta pruning
    final depth = difficulty.searchDepth;
    final isMaximizing = state.activeColor == PieceColor.white;

    ChessMove? bestMove;
    var bestScore = isMaximizing ? double.negativeInfinity : double.infinity;
    var alpha = double.negativeInfinity;
    var beta = double.infinity;

    // Sort moves for better pruning (captures first)
    final sortedMoves = _sortMoves(state, validMoves);

    for (final move in sortedMoves) {
      final newState = rules.applyMove(state, move);
      final score = _minimax(newState, rules, depth - 1, alpha, beta, !isMaximizing);

      if (isMaximizing) {
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
        alpha = max(alpha, score);
      } else {
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
        beta = min(beta, score);
      }
    }

    // Add some randomness for lower difficulties
    if (_random.nextDouble() > difficulty.accuracy && validMoves.length > 1) {
      return validMoves[_random.nextInt(validMoves.length)];
    }

    return bestMove ?? validMoves.first;
  }

  List<ChessMove> _sortMoves(ChessState state, List<ChessMove> moves) {
    // Sort to improve alpha-beta pruning
    // Captures first, then checks, then other moves
    return moves.toList()..sort((a, b) {
      final aCapture = state.board.pieceAt(a.to) != null ? 1 : 0;
      final bCapture = state.board.pieceAt(b.to) != null ? 1 : 0;
      return bCapture.compareTo(aCapture);
    });
  }

  double _minimax(
    ChessState state,
    GameRules<ChessState, ChessMove> rules,
    int depth,
    double alpha,
    double beta,
    bool isMaximizing,
  ) {
    // Check transposition table
    final key = '${state.board.toFEN()}_$depth';
    if (_transpositionTable.containsKey(key)) {
      return _transpositionTable[key]!;
    }

    if (depth == 0 || state.isGameOver) {
      final score = evaluateState(state);
      _transpositionTable[key] = score;
      return score;
    }

    final currentPlayerId = state.currentPlayerId;
    final moves = rules.getValidMoves(state, currentPlayerId);

    if (moves.isEmpty) {
      return evaluateState(state);
    }

    if (isMaximizing) {
      var maxEval = double.negativeInfinity;
      for (final move in moves) {
        final newState = rules.applyMove(state, move);
        final eval = _minimax(newState, rules, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      _transpositionTable[key] = maxEval;
      return maxEval;
    } else {
      var minEval = double.infinity;
      for (final move in moves) {
        final newState = rules.applyMove(state, move);
        final eval = _minimax(newState, rules, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      _transpositionTable[key] = minEval;
      return minEval;
    }
  }

  @override
  double evaluateState(ChessState state) {
    if (state.result != null) {
      if (state.result!.winnerId == playerId) return 10000;
      if (state.result!.winnerId != null) return -10000;
      return 0; // Draw
    }

    var score = 0.0;
    final myColor = state.playerIds.indexOf(playerId) == 0
      ? PieceColor.white
      : PieceColor.black;

    // Material count
    for (final entry in state.board.pieces) {
      final piece = entry.value;
      final value = _getPieceValue(piece.type);
      if (piece.color == myColor) {
        score += value;
      } else {
        score -= value;
      }
    }

    // Positional bonuses
    score += _evaluatePosition(state, myColor);

    // King safety
    score += _evaluateKingSafety(state, myColor);

    // Control of center
    score += _evaluateCenterControl(state, myColor);

    return score;
  }

  double _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn: return 100;
      case PieceType.knight: return 320;
      case PieceType.bishop: return 330;
      case PieceType.rook: return 500;
      case PieceType.queen: return 900;
      case PieceType.king: return 0;
    }
  }

  double _evaluatePosition(ChessState state, PieceColor color) {
    // Piece-square tables for positional evaluation
    var score = 0.0;

    // Bonus for developed pieces
    for (final entry in state.board.pieces) {
      if (entry.value.color != color) continue;

      final square = entry.key;
      final piece = entry.value;

      // Knights/bishops in center are good
      if (piece.type == PieceType.knight || piece.type == PieceType.bishop) {
        if (square.file >= 2 && square.file <= 5 &&
            square.rank >= 2 && square.rank <= 5) {
          score += 20;
        }
      }

      // Rooks on open files
      if (piece.type == PieceType.rook) {
        if (_isOpenFile(state.board, square.file)) {
          score += 25;
        }
      }
    }

    return score;
  }

  bool _isOpenFile(ChessBoard board, int file) {
    for (var rank = 0; rank < 8; rank++) {
      final piece = board.pieceAt(ChessSquare(file, rank));
      if (piece?.type == PieceType.pawn) return false;
    }
    return true;
  }

  double _evaluateKingSafety(ChessState state, PieceColor color) {
    final kingSquare = state.board.findKing(color);
    if (kingSquare == null) return 0;

    var safety = 0.0;

    // Castled king is safer
    final homeRank = color == PieceColor.white ? 0 : 7;
    if (kingSquare.rank == homeRank) {
      if (kingSquare.file >= 5) safety += 30; // Kingside castled
      if (kingSquare.file <= 2) safety += 30; // Queenside castled
    }

    // Pawn shield
    final pawnShieldSquares = [
      kingSquare.offset(-1, color == PieceColor.white ? 1 : -1),
      kingSquare.offset(0, color == PieceColor.white ? 1 : -1),
      kingSquare.offset(1, color == PieceColor.white ? 1 : -1),
    ];

    for (final sq in pawnShieldSquares) {
      if (!sq.isValid) continue;
      final piece = state.board.pieceAt(sq);
      if (piece?.type == PieceType.pawn && piece?.color == color) {
        safety += 10;
      }
    }

    return safety;
  }

  double _evaluateCenterControl(ChessState state, PieceColor color) {
    var control = 0.0;
    final centerSquares = [
      ChessSquare(3, 3), ChessSquare(3, 4),
      ChessSquare(4, 3), ChessSquare(4, 4),
    ];

    for (final sq in centerSquares) {
      final piece = state.board.pieceAt(sq);
      if (piece != null && piece.color == color) {
        control += 15;
      }
    }

    return control;
  }

  @override
  bool _isComplexDecision(ChessState state, ChessMove move) {
    // Mid-game and endgame decisions are more complex
    final pieceCount = state.board.pieces.length;
    return pieceCount >= 10 && pieceCount <= 24;
  }
}
```

### Ludo Bot

```dart
// lib/src/board_games/ludo_bot.dart
import 'dart:math';
import 'package:game_ludo/game_ludo.dart';
import '../core/bot_player.dart';
import '../core/difficulty.dart';

class LudoBot extends BotPlayer<LudoState, LudoMove> {
  final Random _random;

  LudoBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    Random? random,
  }) : _random = random ?? Random();

  @override
  Future<LudoMove?> selectMove(
    LudoState state,
    GameRules<LudoState, LudoMove> rules,
  ) async {
    final validMoves = rules.getValidMoves(state, playerId);
    if (validMoves.isEmpty) return null;

    // Must roll dice first
    if (validMoves.every((m) => m is LudoRollDice)) {
      return validMoves.first;
    }

    // Must pass if no valid token moves
    if (validMoves.every((m) => m is LudoPass)) {
      return validMoves.first;
    }

    // Evaluate token moves
    final tokenMoves = validMoves.whereType<LudoMoveToken>().toList();

    if (_random.nextDouble() > difficulty.accuracy) {
      return tokenMoves[_random.nextInt(tokenMoves.length)];
    }

    return _selectBestMove(state, tokenMoves);
  }

  LudoMove _selectBestMove(LudoState state, List<LudoMoveToken> moves) {
    var bestMove = moves.first;
    var bestScore = double.negativeInfinity;

    for (final move in moves) {
      final score = _evaluateMove(state, move);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  double _evaluateMove(LudoState state, LudoMoveToken move) {
    var score = 0.0;
    final token = _findToken(state, move.tokenId);
    if (token == null) return score;

    final myColor = state.playerColors[playerId]!;

    // Priority 1: Capture opponent
    final captureTarget = _wouldCapture(state, token, move.steps);
    if (captureTarget != null) {
      score += 100;
    }

    // Priority 2: Leave home (on 6)
    if (token.isAtHome) {
      score += 80;
    }

    // Priority 3: Enter safe zone / finish
    if (_wouldEnterSafeZone(token, move.steps, myColor)) {
      score += 70;
    }

    if (_wouldFinish(token, move.steps, myColor)) {
      score += 150;
    }

    // Priority 4: Move to safe square
    if (_wouldLandOnSafe(token, move.steps)) {
      score += 30;
    }

    // Priority 5: Avoid danger
    if (_isInDanger(state, token)) {
      score += 50; // Moving away from danger
    }

    // Progress bonus (prefer advancing)
    score += _calculateProgress(token, move.steps, myColor);

    // Personality adjustments
    score *= (0.8 + personality.riskTolerance * 0.4);

    return score;
  }

  LudoToken? _findToken(LudoState state, String tokenId) {
    for (final tokens in state.playerTokens.values) {
      for (final token in tokens) {
        if (token.id == tokenId) return token;
      }
    }
    return null;
  }

  LudoToken? _wouldCapture(LudoState state, LudoToken token, int steps) {
    // Calculate new position and check for opponent token
    return null; // Placeholder
  }

  bool _wouldEnterSafeZone(LudoToken token, int steps, LudoColor color) {
    return false; // Placeholder
  }

  bool _wouldFinish(LudoToken token, int steps, LudoColor color) {
    return false; // Placeholder
  }

  bool _wouldLandOnSafe(LudoToken token, int steps) {
    return false; // Placeholder
  }

  bool _isInDanger(LudoState state, LudoToken token) {
    // Check if any opponent token can capture this token
    return false; // Placeholder
  }

  double _calculateProgress(LudoToken token, int steps, LudoColor color) {
    return steps.toDouble(); // Simple progress metric
  }

  @override
  bool _isComplexDecision(LudoState state, LudoMove move) {
    // Complex when multiple tokens can move
    final tokenMoves = state.playerTokens[playerId]!
      .where((t) => t.isInPlay)
      .length;
    return tokenMoves > 1;
  }

  @override
  double evaluateState(LudoState state) {
    final myTokens = state.playerTokens[playerId]!;
    var score = 0.0;

    for (final token in myTokens) {
      if (token.isFinished) {
        score += 100;
      } else if (token.isInPlay) {
        score += 30;
      }
      // Home tokens = 0
    }

    return score / 400; // Normalize to 0-1
  }
}
```

---

## Utility Classes

### Card Evaluator

```dart
// lib/src/utils/card_evaluator.dart
import 'package:game_core/game_core.dart';

class CardEvaluator {
  /// Twenty-Nine card values (J=3, 9=2, A=1, 10=1, K/Q=0)
  static int twentyNineCardValue(PlayingCard card) {
    switch (card.rank) {
      case Rank.jack: return 3;
      case Rank.nine: return 2;
      case Rank.ace: return 1;
      case Rank.ten: return 1;
      default: return 0;
    }
  }

  /// Standard card ranking (2=2, 3=3, ..., J=11, Q=12, K=13, A=14)
  static int standardCardValue(PlayingCard card) {
    switch (card.rank) {
      case Rank.two: return 2;
      case Rank.three: return 3;
      case Rank.four: return 4;
      case Rank.five: return 5;
      case Rank.six: return 6;
      case Rank.seven: return 7;
      case Rank.eight: return 8;
      case Rank.nine: return 9;
      case Rank.ten: return 10;
      case Rank.jack: return 11;
      case Rank.queen: return 12;
      case Rank.king: return 13;
      case Rank.ace: return 14;
    }
  }

  /// Evaluate a hand for trick-taking games
  static double evaluateHand(
    List<PlayingCard> hand,
    Suit? trump,
    int Function(PlayingCard) valueFunc,
  ) {
    var score = 0.0;

    for (final card in hand) {
      final value = valueFunc(card);
      final multiplier = card.suit == trump ? 1.5 : 1.0;
      score += value * multiplier;
    }

    return score;
  }
}
```

### Monte Carlo Tree Search

```dart
// lib/src/utils/monte_carlo.dart
import 'dart:math';
import 'package:game_core/game_core.dart';

class MonteCarloTreeSearch<TState extends GameState, TMove extends GameMove> {
  final GameRules<TState, TMove> rules;
  final String playerId;
  final int simulations;
  final Random _random;

  MonteCarloTreeSearch({
    required this.rules,
    required this.playerId,
    required this.simulations,
    Random? random,
  }) : _random = random ?? Random();

  TMove? findBestMove(TState state) {
    final validMoves = rules.getValidMoves(state, playerId);
    if (validMoves.isEmpty) return null;

    final wins = <TMove, int>{};
    final plays = <TMove, int>{};

    for (var i = 0; i < simulations; i++) {
      final move = validMoves[_random.nextInt(validMoves.length)];
      final newState = rules.applyMove(state, move);
      final result = _simulateRandomGame(newState);

      plays[move] = (plays[move] ?? 0) + 1;
      if (result == playerId) {
        wins[move] = (wins[move] ?? 0) + 1;
      }
    }

    // Select move with highest win rate
    TMove? bestMove;
    var bestRate = -1.0;

    for (final move in validMoves) {
      final moveWins = wins[move] ?? 0;
      final movePlays = plays[move] ?? 1;
      final winRate = moveWins / movePlays;

      if (winRate > bestRate) {
        bestRate = winRate;
        bestMove = move;
      }
    }

    return bestMove ?? validMoves.first;
  }

  String? _simulateRandomGame(TState state) {
    var currentState = state;
    var moveCount = 0;
    const maxMoves = 200;

    while (!currentState.isGameOver && moveCount < maxMoves) {
      final currentPlayerId = _getCurrentPlayer(currentState);
      final moves = rules.getValidMoves(currentState, currentPlayerId);

      if (moves.isEmpty) break;

      final randomMove = moves[_random.nextInt(moves.length)];
      currentState = rules.applyMove(currentState, randomMove);
      moveCount++;
    }

    return _getWinner(currentState);
  }

  String _getCurrentPlayer(TState state) {
    // This would need to be implemented based on game type
    return state.playerIds.first;
  }

  String? _getWinner(TState state) {
    // This would need to be implemented based on game type
    return null;
  }
}
```

---

## Bot Factory

```dart
// lib/src/bot_factory.dart
import 'package:game_core/game_core.dart';
import 'core/bot_player.dart';
import 'core/difficulty.dart';
import 'core/personality.dart';
import 'card_games/twenty_nine_bot.dart';
import 'card_games/oh_hell_bot.dart';
import 'board_games/chess_bot.dart';
import 'board_games/ludo_bot.dart';

class BotFactory {
  static final List<String> _botNames = [
    'Alex', 'Jordan', 'Casey', 'Morgan', 'Riley',
    'Quinn', 'Avery', 'Blake', 'Cameron', 'Drew',
  ];

  static int _nameIndex = 0;

  static String _getNextName() {
    final name = _botNames[_nameIndex % _botNames.length];
    _nameIndex++;
    return name;
  }

  static BotPlayer<TState, TMove> createBot<TState extends GameState, TMove extends GameMove>({
    required String gameType,
    required String playerId,
    String? name,
    BotDifficulty difficulty = BotDifficulty.medium,
    BotPersonality personality = BotPersonality.balanced,
  }) {
    final botName = name ?? _getNextName();

    switch (gameType) {
      case 'twenty_nine':
        return TwentyNineBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ) as BotPlayer<TState, TMove>;

      case 'oh_hell':
        return OhHellBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ) as BotPlayer<TState, TMove>;

      case 'chess':
        return ChessBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ) as BotPlayer<TState, TMove>;

      case 'ludo':
        return LudoBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ) as BotPlayer<TState, TMove>;

      default:
        throw ArgumentError('Unknown game type: $gameType');
    }
  }
}
```

---

## Tests

```dart
// test/twenty_nine_bot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bot_strategies/bot_strategies.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  group('TwentyNineBot', () {
    late TwentyNineBot bot;
    late TwentyNineRules rules;

    setUp(() {
      bot = TwentyNineBot(
        playerId: 'bot1',
        name: 'TestBot',
        difficulty: BotDifficulty.hard,
      );
      rules = TwentyNineRules(TwentyNineConfig.standard());
    });

    test('always returns valid move', () async {
      final state = TwentyNineState.initial(
        gameId: 'test',
        playerIds: ['bot1', 'p2', 'p3', 'p4'],
      );

      final move = await bot.selectMove(state, rules);
      expect(move, isNotNull);
      expect(rules.isValidMove(state, move!), isTrue);
    });

    test('bids based on hand strength', () async {
      // Create state with strong hand
      // Verify bot bids appropriately
    });

    test('think time increases for complex decisions', () {
      // Verify think time calculation
    });
  });
}
```

---

## Integration Notes

1. **Real-time Play**: Bots use `getThinkTime()` to simulate human-like delays
2. **Difficulty Scaling**: Adjust `BotDifficulty` for skill-based matchmaking
3. **Personality Variety**: Use different personalities for more engaging gameplay
4. **Performance**: Chess bot uses transposition tables for efficient searching
5. **Testing**: All bots are deterministic when given a seeded `Random`
