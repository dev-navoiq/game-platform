import 'oh_hell_config.dart';

/// Result of scoring one Oh Hell round.
class OhHellRoundResult {
  /// Points earned this round per player (0 if missed, 10 + 11×bid if exact).
  final Map<String, int> roundPoints;

  /// Updated cumulative scores after this round.
  final Map<String, int> updatedScores;

  const OhHellRoundResult({
    required this.roundPoints,
    required this.updatedScores,
  });
}

/// Stateless scorer for Oh Hell rounds.
class OhHellScorer {
  const OhHellScorer();

  /// Score a completed round.
  ///
  /// Each player who won exactly their bid earns `10 + 11×bid` points.
  /// Others earn 0.
  OhHellRoundResult scoreRound({
    required List<String> playerOrder,
    required Map<String, int> bids,
    required Map<String, int> tricksWon,
    required Map<String, int> cumulativeScores,
  }) {
    final roundPoints = <String, int>{};
    for (final pid in playerOrder) {
      final bid = bids[pid] ?? 0;
      final won = tricksWon[pid] ?? 0;
      roundPoints[pid] = (won == bid) ? OhHellConfig.exactBidScore(bid) : 0;
    }

    final updated = Map<String, int>.from(cumulativeScores);
    for (final pid in playerOrder) {
      updated[pid] = (updated[pid] ?? 0) + (roundPoints[pid] ?? 0);
    }

    return OhHellRoundResult(
      roundPoints: roundPoints,
      updatedScores: updated,
    );
  }
}
