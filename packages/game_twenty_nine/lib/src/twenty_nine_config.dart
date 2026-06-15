import 'package:game_core/game_core.dart';

/// Configuration constants and card-value helpers for Twenty-Nine.
class TwentyNineConfig {
  TwentyNineConfig._();

  static const int minBid = 15;
  static const int maxBid = 28;
  static const int specialBid = 29;
  static const int totalCardPoints = 28;

  /// Threshold above which a bid counts as a "high bid" and scoring is doubled.
  /// Classic 29 variants treat bids of 20 or more as naturally doubled.
  static const int highBidThreshold = 20;

  /// Amount the round threshold shifts when Royal Wedding (K+Q of trump) is
  /// announced. Subtracted for the bidder team, added for defenders.
  static const int royalWeddingAdjustment = 4;

  /// First team to reach this many "red" game-points wins the session.
  /// Mirror in [TwentyNineConfig.scorecardMax]: black 6 reaching the same
  /// value means the team has lost.
  static const int scorecardMax = 6;

  /// Base game-point value for a won bid, before any double/redouble multiplier.
  /// Low bids (16–19): 1. High bids (20–28): 2. A won 29-bid: 4.
  static int baseGamePointsForBid(int bid) {
    if (bid == specialBid) return 4;
    if (bid >= highBidThreshold) return 2;
    return 1;
  }

  /// Point value of [card] in Twenty-Nine.
  /// J=3, 9=2, A=1, 10=1, K/Q/8/7=0.
  static int getCardPoints(PlayingCard card) {
    switch (card.rank) {
      case Rank.jack:
        return 3;
      case Rank.nine:
        return 2;
      case Rank.ace:
        return 1;
      case Rank.ten:
        return 1;
      default:
        return 0;
    }
  }

  /// Relative strength of [card] within a suit.
  /// J(8) > 9(7) > A(6) > 10(5) > K(4) > Q(3) > 8(2) > 7(1).
  static int cardStrength(PlayingCard card) {
    switch (card.rank) {
      case Rank.jack:
        return 8;
      case Rank.nine:
        return 7;
      case Rank.ace:
        return 6;
      case Rank.ten:
        return 5;
      case Rank.king:
        return 4;
      case Rank.queen:
        return 3;
      case Rank.eight:
        return 2;
      case Rank.seven:
        return 1;
      default:
        return 0;
    }
  }
}
