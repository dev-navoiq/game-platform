/// Configuration constants for Spades.
class SpadesConfig {
  SpadesConfig._();

  static const int playerCount = 4;
  static const int cardsPerPlayer = 13;
  static const int bagPenaltyThreshold = 10;
  static const int bagPenaltyPoints = -100;
  static const int nilBidSuccess = 100;
  static const int nilBidFailure = -100;
  static const int gameOverScore = 500;
}
