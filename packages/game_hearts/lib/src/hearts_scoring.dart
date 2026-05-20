import 'package:game_core/game_core.dart';

import 'hearts_config.dart';

/// Result of scoring a completed Hearts hand.
class HeartsHandResult {
  /// Points scored this hand per player.
  final Map<String, int> handPoints;

  /// Updated cumulative scores.
  final Map<String, int> updatedScores;

  /// Whether a player shot the moon (took all 26 points).
  final String? moonShooter;

  const HeartsHandResult({
    required this.handPoints,
    required this.updatedScores,
    this.moonShooter,
  });
}

/// Stateless scorer for Hearts hands.
class HeartsScorer {
  const HeartsScorer();

  /// Count points in a set of [cards] for Hearts scoring.
  static int countPoints(List<PlayingCard> cards) {
    var total = 0;
    for (final card in cards) {
      if (card.suit == Suit.hearts) total += HeartsConfig.heartPoints;
      if (card.suit == Suit.spades && card.rank == Rank.queen) {
        total += HeartsConfig.queenOfSpadesPoints;
      }
    }
    return total;
  }

  /// Score a completed hand.
  HeartsHandResult scoreHand({
    required List<String> playerOrder,
    required Map<String, int> handPoints,
    required Map<String, int> cumulativeScores,
  }) {
    // Check for shooting the moon.
    final moonShooter = playerOrder.cast<String?>().firstWhere(
          (pid) => (handPoints[pid] ?? 0) == HeartsConfig.totalHandPoints,
          orElse: () => null,
        );

    final Map<String, int> adjusted;
    if (moonShooter != null) {
      // Everyone else gets 26 points.
      adjusted = {
        for (final pid in playerOrder)
          pid: pid == moonShooter ? 0 : HeartsConfig.totalHandPoints,
      };
    } else {
      adjusted = Map.from(handPoints);
    }

    final updated = Map<String, int>.from(cumulativeScores);
    for (final pid in playerOrder) {
      updated[pid] = (updated[pid] ?? 0) + (adjusted[pid] ?? 0);
    }

    return HeartsHandResult(
      handPoints: adjusted,
      updatedScores: updated,
      moonShooter: moonShooter,
    );
  }
}
