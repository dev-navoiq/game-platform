import 'twenty_nine_config.dart';

/// Result of scoring a single round of Twenty-Nine.
class RoundScoringResult {
  /// Whether the bidding team met or exceeded their bid.
  final bool biddingTeamScored;

  /// Updated cumulative game-point scores after this round.
  final Map<int, int> updatedGameScores;

  /// Game-point delta awarded by this round (absolute, before applying to a team).
  final int gamePointsAwarded;

  const RoundScoringResult({
    required this.biddingTeamScored,
    required this.updatedGameScores,
    required this.gamePointsAwarded,
  });
}

/// Stateless scorer for Twenty-Nine rounds.
///
/// Scoring follows the classic tiered rule set:
///   • Bid 16–19:       base = 1 game point
///   • Bid 20–28 ("high"): base = 2 game points
///   • Bid 29 ("pair"):    base = 4 game points
///
/// The base is then multiplied by the doubling multiplier:
///   1 (undoubled) → 2 (doubled) → 4 (redoubled)
///
/// A won bid awards the multiplied base to the bidding team. A failed bid
/// awards the same value to the defending team (bidder pays defender).
class TwentyNineScorer {
  const TwentyNineScorer();

  /// Score a completed round and return the updated game scores.
  RoundScoringResult scoreRound({
    required int bid,
    required int biddingTeam,
    required Map<int, int> teamPoints,
    required Map<int, int> gameScores,
    int doublingMultiplier = 1,
  }) {
    final bidTeamPoints = teamPoints[biddingTeam] ?? 0;
    final defendingTeam = (biddingTeam + 1) % 2;
    // A bid of 29 means "capture all 28 card points in the deck".
    final threshold =
        bid == TwentyNineConfig.specialBid ? TwentyNineConfig.totalCardPoints : bid;
    final bidMet = bidTeamPoints >= threshold;

    final base = TwentyNineConfig.baseGamePointsForBid(bid);
    final awarded = base * doublingMultiplier;

    final updated = Map<int, int>.from(gameScores);
    if (bidMet) {
      updated[biddingTeam] = (updated[biddingTeam] ?? 0) + awarded;
    } else {
      updated[defendingTeam] = (updated[defendingTeam] ?? 0) + awarded;
    }

    return RoundScoringResult(
      biddingTeamScored: bidMet,
      updatedGameScores: updated,
      gamePointsAwarded: awarded,
    );
  }
}
