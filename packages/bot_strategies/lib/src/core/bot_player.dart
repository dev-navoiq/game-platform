import 'dart:math';

import 'package:game_core/game_core.dart';

import 'difficulty.dart';
import 'personality.dart';
import 'think_time.dart';

/// Abstract interface for all game bots.
///
/// Generic over the game's state and move types. All methods are synchronous
/// (no async, no network) so bots can run fully offline.
abstract class BotPlayer<TState extends GameState, TMove extends GameMove> {
  final String playerId;
  final String name;
  final BotDifficulty difficulty;
  final BotPersonality personality;
  final Random random;

  BotPlayer({
    required this.playerId,
    required this.name,
    required this.difficulty,
    this.personality = BotPersonality.balanced,
    Random? random,
  }) : random = random ?? Random();

  /// Select the best move for the current state.
  TMove? selectMove(TState state, List<TMove> validMoves);

  /// Get think time before playing (simulates human timing).
  /// The UI applies the delay — the bot itself returns immediately.
  Duration getThinkTime(TState state, TMove move) {
    return ThinkTimeCalculator.calculate(
      difficulty: difficulty,
      personality: personality,
      isComplexDecision: isComplexDecision(state, move),
    );
  }

  /// Whether the given decision is complex (affects think time).
  bool isComplexDecision(TState state, TMove move);

  /// Pick a random move from the list (for suboptimal play at lower
  /// difficulties).
  TMove selectRandom(List<TMove> moves) {
    return moves[random.nextInt(moves.length)];
  }

  /// Returns true with probability [difficulty.accuracy].
  /// When false the bot should make a suboptimal (random) move.
  bool shouldPlayOptimally() {
    return random.nextDouble() < difficulty.accuracy;
  }
}

/// A move paired with its evaluation score.
class EvaluatedMove<TMove> {
  final TMove move;
  final double score;

  const EvaluatedMove(this.move, this.score);
}
