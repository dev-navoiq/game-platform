import 'twenty_nine_config.dart';

/// Result of scoring a single round of Twenty-Nine.
class RoundScoringResult {
  /// Whether the bidding team met or exceeded their bid.
  final bool biddingTeamScored;

  /// Updated cumulative game-point scores after this round.
  final Map<int, int> updatedGameScores;

  /// Game-point delta awarded by this round (absolute, before applying to a team).
  final int gamePointsAwarded;

  /// Updated red-pip totals per team (positive scorecard).
  final Map<int, int> updatedRedPips;

  /// Updated black-pip totals per team (negative scorecard).
  final Map<int, int> updatedBlackPips;

  /// Effective threshold after applying any [bidAdjustment].
  final int effectiveThreshold;

  const RoundScoringResult({
    required this.biddingTeamScored,
    required this.updatedGameScores,
    required this.gamePointsAwarded,
    required this.updatedRedPips,
    required this.updatedBlackPips,
    required this.effectiveThreshold,
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
  ///
  /// [bidAdjustment] shifts the effective threshold (negative = bidder gets
  /// a break from Royal Wedding; positive = defenders raise the bar).
  /// [redPips]/[blackPips] are the per-team scorecard counters; both teams
  /// gain pips after every round so the visual reflects who is "winning"
  /// AND who is "losing" — mirrors the traditional red/black 6 scorecard.
  RoundScoringResult scoreRound({
    required int bid,
    required int biddingTeam,
    required Map<int, int> teamPoints,
    required Map<int, int> gameScores,
    int doublingMultiplier = 1,
    int bidAdjustment = 0,
    Map<int, int> redPips = const {0: 0, 1: 0},
    Map<int, int> blackPips = const {0: 0, 1: 0},
  }) {
    final bidTeamPoints = teamPoints[biddingTeam] ?? 0;
    final defendingTeam = (biddingTeam + 1) % 2;
    // A bid of 29 means "capture all 28 card points in the deck".
    final baseThreshold = bid == TwentyNineConfig.specialBid
        ? TwentyNineConfig.totalCardPoints
        : bid;
    final threshold = baseThreshold + bidAdjustment;
    final bidMet = bidTeamPoints >= threshold;

    final base = TwentyNineConfig.baseGamePointsForBid(bid);
    final awarded = base * doublingMultiplier;

    final updatedScores = Map<int, int>.from(gameScores);
    final updatedRed = Map<int, int>.from(redPips);
    final updatedBlack = Map<int, int>.from(blackPips);
    if (bidMet) {
      updatedScores[biddingTeam] =
          (updatedScores[biddingTeam] ?? 0) + awarded;
      updatedRed[biddingTeam] = (updatedRed[biddingTeam] ?? 0) + awarded;
      updatedBlack[defendingTeam] =
          (updatedBlack[defendingTeam] ?? 0) + awarded;
    } else {
      updatedScores[defendingTeam] =
          (updatedScores[defendingTeam] ?? 0) + awarded;
      updatedRed[defendingTeam] =
          (updatedRed[defendingTeam] ?? 0) + awarded;
      updatedBlack[biddingTeam] =
          (updatedBlack[biddingTeam] ?? 0) + awarded;
    }

    return RoundScoringResult(
      biddingTeamScored: bidMet,
      updatedGameScores: updatedScores,
      gamePointsAwarded: awarded,
      updatedRedPips: updatedRed,
      updatedBlackPips: updatedBlack,
      effectiveThreshold: threshold,
    );
  }
}
