/// Configuration constants for Oh Hell.
class OhHellConfig {
  OhHellConfig._();

  static const int minPlayers = 4;
  static const int maxPlayers = 6;

  /// Maximum cards per player for a given [playerCount] using a 52-card deck.
  static int maxCardsPerPlayer(int playerCount) => 52 ~/ playerCount;

  /// Round sequence: descend from the opening deal to 1, then (unless
  /// [downOnly]) ascend back up. e.g. 4 players → [13, 12, ..., 1, 2, ...,
  /// 13] (25 rounds total).
  ///
  /// [maxCards] caps the opening deal below the deck limit for shorter
  /// games (e.g. 5 → 9 rounds); [downOnly] stops at the 1-card round.
  /// Mirrors `buildOhHellRoundSequence` in
  /// `supabase/functions/_shared/game_setup.ts` — keep the two in sync.
  static List<int> roundSequence(
    int playerCount, {
    int? maxCards,
    bool downOnly = false,
  }) {
    final deckMax = maxCardsPerPlayer(playerCount);
    final max = (maxCards != null && maxCards >= 1 && maxCards < deckMax)
        ? maxCards
        : deckMax;
    final result = <int>[];
    for (var i = max; i >= 1; i--) result.add(i);
    if (!downOnly) {
      for (var i = 2; i <= max; i++) result.add(i);
    }
    return result;
  }

  /// Score for a player who made their exact bid: 10 + 11×bid.
  /// (0→10, 1→21, 2→32, 3→43 … — ambitious exact bids are rewarded far
  /// more than safe zeros; changed from 10 + bid on 2026-08-02.)
  static int exactBidScore(int bid) => 10 + 11 * bid;
}
