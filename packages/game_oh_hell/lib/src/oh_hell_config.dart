/// Configuration constants for Oh Hell.
class OhHellConfig {
  OhHellConfig._();

  static const int minPlayers = 3;
  static const int maxPlayers = 7;

  /// Maximum cards per player for a given [playerCount] using a 52-card deck.
  static int maxCardsPerPlayer(int playerCount) => 52 ~/ playerCount;

  /// Full round sequence: descend from max to 1, then ascend back to max.
  /// e.g. 4 players → [13, 12, 11, ..., 1, 2, ..., 13] (25 rounds total).
  static List<int> roundSequence(int playerCount) {
    final max = maxCardsPerPlayer(playerCount);
    final result = <int>[];
    for (var i = max; i >= 1; i--) result.add(i);
    for (var i = 2; i <= max; i++) result.add(i);
    return result;
  }

  /// Score for a player who made their exact bid.
  static int exactBidScore(int bid) => 10 + bid;
}
