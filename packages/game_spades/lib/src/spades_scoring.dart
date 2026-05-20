import 'spades_config.dart';

/// Result of scoring a completed Spades round.
class SpadesRoundResult {
  /// Points scored this round per team.
  final Map<int, int> roundPoints;

  /// Updated cumulative team scores.
  final Map<int, int> updatedScores;

  /// Updated bags per team.
  final Map<int, int> updatedBags;

  const SpadesRoundResult({
    required this.roundPoints,
    required this.updatedScores,
    required this.updatedBags,
  });
}

/// Stateless scorer for Spades rounds.
class SpadesScorer {
  const SpadesScorer();

  /// Score a completed round.
  ///
  /// For each team:
  /// - Made bid: (bid × 10) + bags (overtricks)
  /// - Set (missed bid): -(bid × 10)
  /// - Every 10 bags = -100 points bag penalty.
  ///
  /// Nil bid scoring is handled separately per player before calling this.
  SpadesRoundResult scoreRound({
    required List<String> playerOrder,
    required Map<String, int> bids,
    required Map<String, bool> isNilBid,
    required Map<String, int> playerTricksWon,
    required Map<int, int> teamTricksWon,
    required Map<int, int> currentScores,
    required Map<int, int> currentBags,
  }) {
    final roundPoints = <int, int>{0: 0, 1: 0};
    final updatedBags = Map<int, int>.from(currentBags);

    for (var team = 0; team < 2; team++) {
      final teamPlayers = playerOrder.where((pid) {
        final idx = playerOrder.indexOf(pid);
        return idx % 2 == team;
      }).toList();

      // Sum non-nil bids and their results.
      var teamBid = 0;
      var teamTricks = teamTricksWon[team] ?? 0;
      var nilPoints = 0;

      for (final pid in teamPlayers) {
        if (isNilBid[pid] == true) {
          final tricksTaken = playerTricksWon[pid] ?? 0;
          if (tricksTaken == 0) {
            nilPoints += SpadesConfig.nilBidSuccess;
          } else {
            nilPoints += SpadesConfig.nilBidFailure;
            // Nil bidder's tricks count against team total.
          }
        } else {
          teamBid += bids[pid] ?? 0;
        }
      }

      if (teamBid == 0) {
        // All players bid nil.
        roundPoints[team] = nilPoints;
      } else {
        final madeBid = teamTricks >= teamBid;
        if (madeBid) {
          final bags = teamTricks - teamBid;
          updatedBags[team] = (updatedBags[team] ?? 0) + bags;
          roundPoints[team] = teamBid * 10 + bags + nilPoints;
        } else {
          roundPoints[team] = -(teamBid * 10) + nilPoints;
        }
      }
    }

    // Apply bag penalty (every 10 bags = -100).
    final updated = Map<int, int>.from(currentScores);
    for (var team = 0; team < 2; team++) {
      final totalBags = updatedBags[team] ?? 0;
      final bagPenalties = totalBags ~/ SpadesConfig.bagPenaltyThreshold;
      if (bagPenalties > (currentBags[team] ?? 0) ~/ SpadesConfig.bagPenaltyThreshold) {
        roundPoints[team] = (roundPoints[team] ?? 0) + SpadesConfig.bagPenaltyPoints;
      }
      updated[team] = (updated[team] ?? 0) + (roundPoints[team] ?? 0);
    }

    return SpadesRoundResult(
      roundPoints: roundPoints,
      updatedScores: updated,
      updatedBags: updatedBags,
    );
  }
}
