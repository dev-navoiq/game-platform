/// Calculates mute vote thresholds.
///
/// The democratic mute system requires ≥50% of non-bot players to vote
/// before a player is muted. This matches the database trigger logic.
class MuteCalculator {
  MuteCalculator._();

  /// The fraction of players that must vote to mute (50%).
  static const double threshold = 0.5;

  /// Whether the mute threshold has been reached.
  ///
  /// Returns `true` when [voteCount] >= ceil([playerCount] / 2).
  /// Returns `false` if [playerCount] is 0 or negative.
  static bool shouldMute({
    required int voteCount,
    required int playerCount,
  }) {
    if (playerCount <= 0) return false;
    return voteCount >= (playerCount / 2).ceil();
  }

  /// How many more votes are needed to reach the mute threshold.
  ///
  /// Returns 0 if the threshold is already met.
  static int votesNeeded({
    required int currentVotes,
    required int playerCount,
  }) {
    if (playerCount <= 0) return 0;
    final needed = (playerCount / 2).ceil() - currentVotes;
    return needed.clamp(0, playerCount);
  }

  /// The minimum number of votes required to mute for a given player count.
  static int votesRequired(int playerCount) {
    if (playerCount <= 0) return 0;
    return (playerCount / 2).ceil();
  }
}
