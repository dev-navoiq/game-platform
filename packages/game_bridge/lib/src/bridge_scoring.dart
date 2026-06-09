import 'bridge_config.dart';
import 'bridge_state.dart';

/// Result of scoring one completed Bridge deal.
class BridgeScoreResult {
  /// Tricks taken by the declaring side.
  final int declarerTricks;

  /// Whether the contract was made (`tricksTaken >= tricksRequired`).
  final bool made;

  /// 0 when not made or exactly made.
  final int overtricks;

  /// 0 when made; positive otherwise.
  final int undertricks;

  /// Non-negative points awarded to team NS this deal.
  final int nsPoints;

  /// Non-negative points awarded to team EW this deal.
  final int ewPoints;

  const BridgeScoreResult({
    required this.declarerTricks,
    required this.made,
    required this.overtricks,
    required this.undertricks,
    required this.nsPoints,
    required this.ewPoints,
  });
}

/// Stateless duplicate-style Contract Bridge scorer.
///
/// Implements standard ACBL scoring: trick score, game/part-score bonus,
/// slam bonus, doubled/redoubled adjustments, and the laddered undertrick
/// penalty schedule.
class BridgeScorer {
  const BridgeScorer();

  /// Score a completed deal. Pass null [contract] for a passed-out deal.
  BridgeScoreResult scoreDeal({
    required BridgeContract? contract,
    required int declarerTricks,
    required Vulnerability vulnerability,
  }) {
    if (contract == null) {
      return const BridgeScoreResult(
        declarerTricks: 0,
        made: false,
        overtricks: 0,
        undertricks: 0,
        nsPoints: 0,
        ewPoints: 0,
      );
    }

    final required = contract.tricksRequired;
    final made = declarerTricks >= required;
    final overtricks = made ? declarerTricks - required : 0;
    final undertricks = made ? 0 : required - declarerTricks;
    final vul = BridgeConfig.isTeamVulnerable(contract.declarerTeam, vulnerability);

    final int points = made
        ? _scoreMade(
            contract: contract,
            overtricks: overtricks,
            vul: vul,
          )
        : _scoreSet(
            doubleStatus: contract.doubleStatus,
            undertricks: undertricks,
            vul: vul,
          );

    final declarerTeam = contract.declarerTeam;
    final nsPoints = declarerTeam == 'NS'
        ? (made ? points : 0)
        : (made ? 0 : points);
    final ewPoints = declarerTeam == 'EW'
        ? (made ? points : 0)
        : (made ? 0 : points);

    return BridgeScoreResult(
      declarerTricks: declarerTricks,
      made: made,
      overtricks: overtricks,
      undertricks: undertricks,
      nsPoints: nsPoints,
      ewPoints: ewPoints,
    );
  }

  // ── Made contract ─────────────────────────────────────────────────────────

  int _scoreMade({
    required BridgeContract contract,
    required int overtricks,
    required bool vul,
  }) {
    final trickScore = _trickScore(contract);

    final gameBonus = trickScore >= 100
        ? (vul ? 500 : 300)
        : 50; // part-score

    final slamBonus = _slamBonus(level: contract.level, vul: vul);

    final insultBonus = switch (contract.doubleStatus) {
      BridgeDoubleStatus.doubled => 50,
      BridgeDoubleStatus.redoubled => 100,
      BridgeDoubleStatus.undoubled => 0,
    };

    final overtrickScore = _overtrickScore(
      contract: contract,
      overtricks: overtricks,
      vul: vul,
    );

    return trickScore + gameBonus + slamBonus + insultBonus + overtrickScore;
  }

  /// Trick score = per-trick value × level (+ NT first-trick adjustment),
  /// then doubled/redoubled multiplier.
  int _trickScore(BridgeContract c) {
    int base;
    switch (c.denomination) {
      case BridgeDenomination.clubs:
      case BridgeDenomination.diamonds:
        base = 20 * c.level;
        break;
      case BridgeDenomination.hearts:
      case BridgeDenomination.spades:
        base = 30 * c.level;
        break;
      case BridgeDenomination.noTrump:
        base = 40 + 30 * (c.level - 1);
        break;
    }
    return switch (c.doubleStatus) {
      BridgeDoubleStatus.undoubled => base,
      BridgeDoubleStatus.doubled => base * 2,
      BridgeDoubleStatus.redoubled => base * 4,
    };
  }

  int _slamBonus({required int level, required bool vul}) {
    if (level == 6) return vul ? 750 : 500;
    if (level == 7) return vul ? 1500 : 1000;
    return 0;
  }

  int _overtrickScore({
    required BridgeContract contract,
    required int overtricks,
    required bool vul,
  }) {
    if (overtricks <= 0) return 0;

    switch (contract.doubleStatus) {
      case BridgeDoubleStatus.undoubled:
        final perTrick = contract.denomination.isMinor ? 20 : 30;
        return perTrick * overtricks;
      case BridgeDoubleStatus.doubled:
        return overtricks * (vul ? 200 : 100);
      case BridgeDoubleStatus.redoubled:
        return overtricks * (vul ? 400 : 200);
    }
  }

  // ── Defeated contract ─────────────────────────────────────────────────────

  /// Returns the penalty points awarded to the *defending* side.
  int _scoreSet({
    required BridgeDoubleStatus doubleStatus,
    required int undertricks,
    required bool vul,
  }) {
    switch (doubleStatus) {
      case BridgeDoubleStatus.undoubled:
        return undertricks * (vul ? 100 : 50);

      case BridgeDoubleStatus.doubled:
        return _laddered(undertricks: undertricks, vul: vul, multiplier: 1);

      case BridgeDoubleStatus.redoubled:
        return _laddered(undertricks: undertricks, vul: vul, multiplier: 2);
    }
  }

  /// Standard doubled-undertrick ladder.
  ///
  /// Not vulnerable: 1st = 100, 2nd/3rd = 200 each, 4th+ = 300 each.
  /// Vulnerable:     1st = 200, 2nd+ = 300 each.
  /// Redoubled = doubled × 2 ([multiplier] = 2).
  int _laddered({
    required int undertricks,
    required bool vul,
    required int multiplier,
  }) {
    var total = 0;
    for (var i = 1; i <= undertricks; i++) {
      int t;
      if (vul) {
        t = i == 1 ? 200 : 300;
      } else {
        if (i == 1) {
          t = 100;
        } else if (i <= 3) {
          t = 200;
        } else {
          t = 300;
        }
      }
      total += t;
    }
    return total * multiplier;
  }
}
