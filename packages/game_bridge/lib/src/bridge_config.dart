import 'package:game_core/game_core.dart';

/// Denominations available in Contract Bridge bidding.
/// Rank order during the auction: clubs < diamonds < hearts < spades < noTrump.
enum BridgeDenomination {
  clubs,
  diamonds,
  hearts,
  spades,
  noTrump;

  bool get isMinor => this == clubs || this == diamonds;
  bool get isMajor => this == hearts || this == spades;
  bool get hasTrump => this != noTrump;

  /// The corresponding card [Suit], or null for [noTrump].
  Suit? get suit {
    switch (this) {
      case BridgeDenomination.clubs:
        return Suit.clubs;
      case BridgeDenomination.diamonds:
        return Suit.diamonds;
      case BridgeDenomination.hearts:
        return Suit.hearts;
      case BridgeDenomination.spades:
        return Suit.spades;
      case BridgeDenomination.noTrump:
        return null;
    }
  }
}

/// Doubling status applied to a contract.
enum BridgeDoubleStatus { undoubled, doubled, redoubled }

/// Side vulnerability for a deal.
enum Vulnerability { none, ns, ew, both }

class BridgeConfig {
  BridgeConfig._();

  static const int minPlayers = 4;
  static const int maxPlayers = 4;
  static const int handSize = 13;
  static const int totalTricks = 13;

  /// Chicago format: 4 deals per session with rotating vulnerability.
  static const int totalDeals = 4;

  /// Standard Chicago vulnerability by deal (1-indexed, wraps).
  static Vulnerability vulnerabilityForDeal(int dealNumber) {
    final mod = ((dealNumber - 1) % 4) + 1;
    switch (mod) {
      case 1:
        return Vulnerability.none;
      case 2:
        return Vulnerability.ns;
      case 3:
        return Vulnerability.ew;
      default:
        return Vulnerability.both;
    }
  }

  /// Seats 0 (N) and 2 (S) form team NS; 1 (E) and 3 (W) form team EW.
  static String teamForSeat(int seatIndex) =>
      seatIndex.isEven ? 'NS' : 'EW';

  /// Inverse of [teamForSeat].
  static List<int> seatsForTeam(String team) =>
      team == 'NS' ? const [0, 2] : const [1, 3];

  /// Whether a team is vulnerable in this deal.
  static bool isTeamVulnerable(String team, Vulnerability v) {
    switch (v) {
      case Vulnerability.none:
        return false;
      case Vulnerability.ns:
        return team == 'NS';
      case Vulnerability.ew:
        return team == 'EW';
      case Vulnerability.both:
        return true;
    }
  }
}
