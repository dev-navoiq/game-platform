/// Configuration constants for Hearts.
class HeartsConfig {
  HeartsConfig._();

  static const int playerCount = 4;
  static const int cardsPerPlayer = 13;
  static const int gameOverScore = 100;
  static const int queenOfSpadesPoints = 13;
  static const int heartPoints = 1;

  /// Total points in a single hand (13 hearts × 1 + Q♠ = 26).
  static const int totalHandPoints = 26;
}

/// Direction to pass cards at the start of a hand.
enum PassDirection {
  /// Pass 3 cards to the player to your left (clockwise).
  left,

  /// Pass 3 cards to the player to your right (counter-clockwise).
  right,

  /// Pass 3 cards to the player across from you.
  across,

  /// No passing — keep your hand.
  keep,
}
