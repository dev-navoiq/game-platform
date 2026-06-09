// Standalone tests for the BridgeScorer — covers the ACBL scoring table
// edge cases: minor/major/NT trick scores, doubled/redoubled multipliers,
// game/part-score/slam bonuses, made-with-overtricks, and the laddered
// undertrick penalty schedule (vulnerable + not vulnerable).

import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge/game_bridge.dart';

void main() {
  const scorer = BridgeScorer();

  BridgeContract contract({
    required int level,
    required BridgeDenomination denom,
    BridgeDoubleStatus dbl = BridgeDoubleStatus.undoubled,
    String declarerId = 'p1',
    int declarerSeat = 0, // NS
  }) =>
      BridgeContract(
        level: level,
        denomination: denom,
        doubleStatus: dbl,
        declarerId: declarerId,
        declarerSeat: declarerSeat,
      );

  group('Made contracts — trick score', () {
    test('1♣ undoubled = 20 trick + 50 part-score', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 1, denom: BridgeDenomination.clubs),
        declarerTricks: 7,
        vulnerability: Vulnerability.none,
      );
      expect(r.made, true);
      expect(r.nsPoints, 70); // 20 + 50
    });

    test('1NT undoubled, no overtricks = 40 + 50 = 90', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 1, denom: BridgeDenomination.noTrump),
        declarerTricks: 7,
        vulnerability: Vulnerability.none,
      );
      expect(r.nsPoints, 90);
    });

    test('3NT undoubled, not vul = 100 trick + 300 game = 400', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 3, denom: BridgeDenomination.noTrump),
        declarerTricks: 9,
        vulnerability: Vulnerability.none,
      );
      expect(r.nsPoints, 400);
    });

    test('3NT undoubled, vul = 100 trick + 500 game = 600', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 3, denom: BridgeDenomination.noTrump),
        declarerTricks: 9,
        vulnerability: Vulnerability.ns,
      );
      expect(r.nsPoints, 600);
    });

    test('4♠ undoubled, not vul = 120 trick + 300 game = 420', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 4, denom: BridgeDenomination.spades),
        declarerTricks: 10,
        vulnerability: Vulnerability.none,
      );
      expect(r.nsPoints, 420);
    });

    test('overtricks added at per-trick rate when undoubled', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 4, denom: BridgeDenomination.spades),
        declarerTricks: 11,
        vulnerability: Vulnerability.none,
      );
      // 120 trick + 300 game + 30 overtrick
      expect(r.nsPoints, 450);
      expect(r.overtricks, 1);
    });
  });

  group('Doubled / Redoubled — made', () {
    test('1NT doubled not vul = 80 trick + 50 game + 50 insult = 180', () {
      final r = scorer.scoreDeal(
        contract: contract(
            level: 1,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 7,
        vulnerability: Vulnerability.none,
      );
      // 40*2 = 80 trick; 80 >= 100? No → part-score 50; insult 50 → 180
      expect(r.nsPoints, 180);
    });

    test('2♠ doubled not vul (160 trick) = game bonus', () {
      final r = scorer.scoreDeal(
        contract: contract(
            level: 2,
            denom: BridgeDenomination.spades,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 8,
        vulnerability: Vulnerability.none,
      );
      // 60*2 = 120 trick → game (300 not vul) + 50 insult = 470
      expect(r.nsPoints, 470);
    });

    test('doubled overtrick not vul = 100', () {
      final r = scorer.scoreDeal(
        contract: contract(
            level: 4,
            denom: BridgeDenomination.spades,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 11,
        vulnerability: Vulnerability.none,
      );
      // 240 trick + 300 game + 50 insult + 100 overtrick = 690
      expect(r.nsPoints, 690);
    });

    test('redoubled overtrick vul = 400', () {
      final r = scorer.scoreDeal(
        contract: contract(
            level: 4,
            denom: BridgeDenomination.spades,
            dbl: BridgeDoubleStatus.redoubled),
        declarerTricks: 11,
        vulnerability: Vulnerability.both,
      );
      // 480 trick + 500 game (vul) + 100 insult + 400 overtrick = 1480
      expect(r.nsPoints, 1480);
    });
  });

  group('Slam bonuses', () {
    test('6♠ not vul = 1430', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 6, denom: BridgeDenomination.spades),
        declarerTricks: 12,
        vulnerability: Vulnerability.none,
      );
      // 180 trick + 300 game + 500 small slam = 980
      expect(r.nsPoints, 980);
    });

    test('7NT vul = 2220', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 7, denom: BridgeDenomination.noTrump),
        declarerTricks: 13,
        vulnerability: Vulnerability.both,
      );
      // 220 trick (40 + 30*6) + 500 game (vul) + 1500 grand slam = 2220
      expect(r.nsPoints, 2220);
    });
  });

  group('Defeated contracts — undertrick penalties', () {
    test('undoubled not vul: 50 per undertrick', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 3, denom: BridgeDenomination.noTrump),
        declarerTricks: 6, // down 3
        vulnerability: Vulnerability.none,
      );
      expect(r.made, false);
      expect(r.undertricks, 3);
      expect(r.ewPoints, 150);
      expect(r.nsPoints, 0);
    });

    test('undoubled vul: 100 per undertrick', () {
      final r = scorer.scoreDeal(
        contract: contract(level: 4, denom: BridgeDenomination.spades),
        declarerTricks: 8, // down 2
        vulnerability: Vulnerability.ns,
      );
      expect(r.ewPoints, 200);
    });

    test('doubled not vul ladder: 100, 300, 500, 800 ...', () {
      // 1 undertrick = 100
      var r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 8,
        vulnerability: Vulnerability.none,
      );
      expect(r.ewPoints, 100);

      // 3 undertricks = 100 + 200 + 200 = 500
      r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 6,
        vulnerability: Vulnerability.none,
      );
      expect(r.ewPoints, 500);

      // 4 undertricks = 100 + 200 + 200 + 300 = 800
      r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 5,
        vulnerability: Vulnerability.none,
      );
      expect(r.ewPoints, 800);
    });

    test('doubled vul ladder: 200, 500, 800 ...', () {
      // 1 = 200
      var r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 8,
        vulnerability: Vulnerability.both,
      );
      expect(r.ewPoints, 200);

      // 2 = 200 + 300 = 500
      r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.doubled),
        declarerTricks: 7,
        vulnerability: Vulnerability.both,
      );
      expect(r.ewPoints, 500);
    });

    test('redoubled = doubled × 2', () {
      final r = scorer.scoreDeal(
        contract: contract(
            level: 3,
            denom: BridgeDenomination.noTrump,
            dbl: BridgeDoubleStatus.redoubled),
        declarerTricks: 6, // down 3
        vulnerability: Vulnerability.none,
      );
      // doubled not vul 3 down = 500 → ×2 = 1000
      expect(r.ewPoints, 1000);
    });
  });

  group('Passed out', () {
    test('null contract scores 0 for both sides', () {
      final r = scorer.scoreDeal(
        contract: null,
        declarerTricks: 0,
        vulnerability: Vulnerability.both,
      );
      expect(r.nsPoints, 0);
      expect(r.ewPoints, 0);
      expect(r.made, false);
    });
  });

  group('Defenders side', () {
    test('EW declarer down → NS scores the penalty', () {
      final r = scorer.scoreDeal(
        contract: contract(
          level: 3,
          denom: BridgeDenomination.noTrump,
          declarerId: 'p2',
          declarerSeat: 1, // EW
        ),
        declarerTricks: 6,
        vulnerability: Vulnerability.none,
      );
      expect(r.nsPoints, 150);
      expect(r.ewPoints, 0);
    });
  });
}
