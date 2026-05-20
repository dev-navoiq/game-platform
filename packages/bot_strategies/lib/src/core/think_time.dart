import 'dart:math';

import 'difficulty.dart';
import 'personality.dart';

/// Calculates simulated think time for bot moves.
/// The UI layer applies the delay — bots themselves are synchronous.
class ThinkTimeCalculator {
  static final Random _random = Random();

  /// Returns a human-like think duration for the given parameters.
  static Duration calculate({
    required BotDifficulty difficulty,
    required BotPersonality personality,
    required bool isComplexDecision,
  }) {
    final baseMs = switch (difficulty) {
      BotDifficulty.beginner => 2000,
      BotDifficulty.easy => 1500,
      BotDifficulty.medium => 1200,
      BotDifficulty.hard => 1000,
      BotDifficulty.expert => 800,
      BotDifficulty.master => 500,
    };

    final personalityMultiplier = switch (personality) {
      BotPersonality.quick => 0.5,
      BotPersonality.balanced => 1.0,
      BotPersonality.thoughtful => 1.5,
      BotPersonality.cautious => 2.0,
    };

    final complexityMultiplier = isComplexDecision ? 1.5 : 1.0;

    // ±30% variance
    final variance = 0.7 + _random.nextDouble() * 0.6;

    final totalMs =
        baseMs * personalityMultiplier * complexityMultiplier * variance;
    return Duration(milliseconds: totalMs.round());
  }
}
