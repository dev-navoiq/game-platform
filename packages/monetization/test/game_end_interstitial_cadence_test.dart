import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryGameEndAdStore store;
  late DateTime currentTime;
  late bool fatigued;

  GameEndInterstitialCadence buildCadence() => GameEndInterstitialCadence(
        store,
        now: () => currentTime,
        isFatigued: () async => fatigued,
      );

  setUp(() {
    store = InMemoryGameEndAdStore();
    currentTime = DateTime(2026, 7, 7, 12, 0);
    fatigued = false;
  });

  /// Completes [count] games, advancing the clock by [gap] between each,
  /// and returns the decisions in order.
  Future<List<GameEndAdDecision>> playGames(
    GameEndInterstitialCadence cadence,
    int count, {
    Duration gap = const Duration(minutes: 10),
  }) async {
    final decisions = <GameEndAdDecision>[];
    for (var i = 0; i < count; i++) {
      currentTime = currentTime.add(gap);
      decisions.add(await cadence.onGameCompleted());
    }
    return decisions;
  }

  group('GameEndInterstitialCadence - every 2nd game', () {
    test('1st completed game shows nothing', () async {
      final cadence = buildCadence();

      final decision = await cadence.onGameCompleted();

      expect(decision, GameEndAdDecision.none);
    });

    test('2nd completed game shows an interstitial', () async {
      final cadence = buildCadence();

      final decisions = await playGames(cadence, 2);

      expect(decisions, [
        GameEndAdDecision.none,
        GameEndAdDecision.interstitial,
      ]);
    });

    test('odd games never show, even games show (given wide gaps)', () async {
      final cadence = buildCadence();

      final decisions = await playGames(cadence, 6);

      expect(decisions[0], GameEndAdDecision.none); // game 1
      expect(decisions[1], GameEndAdDecision.interstitial); // game 2
      expect(decisions[2], GameEndAdDecision.none); // game 3
      expect(decisions[3], GameEndAdDecision.interstitial); // game 4
      expect(decisions[4], GameEndAdDecision.none); // game 5
      expect(decisions[5], GameEndAdDecision.houseAd); // game 6 = 3rd slot
    });

    test('game count persists in the store', () async {
      final cadence = buildCadence();

      await playGames(cadence, 3);

      expect(await store.getCompletedGameCount(), 3);
    });
  });

  group('GameEndInterstitialCadence - 3 minute minimum gap', () {
    test('slot within 3 minutes of last interstitial is skipped', () async {
      final cadence = buildCadence();

      // Games 1+2: 2nd game shows an interstitial.
      await playGames(cadence, 2);
      // Games 3+4 played fast: only 1 minute between each.
      final decisions =
          await playGames(cadence, 2, gap: const Duration(minutes: 1));

      expect(decisions, [
        GameEndAdDecision.none, // game 3: odd
        GameEndAdDecision.none, // game 4: slot due, but only 2 min elapsed
      ]);
    });

    test('slot exactly at 3 minutes is allowed', () async {
      final cadence = buildCadence();

      await playGames(cadence, 2);
      final decisions =
          await playGames(cadence, 2, gap: const Duration(minutes: 1, seconds: 30));

      // 3 minutes elapsed since the last interstitial by game 4.
      expect(decisions[1], GameEndAdDecision.interstitial);
    });

    test('skipped slot does not consume the house-ad rotation', () async {
      final cadence = buildCadence();

      // Slot 1 at game 2.
      await playGames(cadence, 2);
      // Game 3 + 4 fast: game 4's slot is skipped by the time gap.
      await playGames(cadence, 2, gap: const Duration(minutes: 1));
      // Games 5..8 with wide gaps: slots 2 and 3 land on games 6 and 8.
      final decisions = await playGames(cadence, 4);

      expect(decisions[1], GameEndAdDecision.interstitial); // game 6 = slot 2
      expect(decisions[3], GameEndAdDecision.houseAd); // game 8 = slot 3
    });

    test('gap timer is not reset by games that show nothing', () async {
      final cadence = buildCadence();

      await playGames(cadence, 2); // interstitial at game 2
      // 2 more games, 2 minutes apart => game 4 is 4 minutes after game 2.
      final decisions =
          await playGames(cadence, 2, gap: const Duration(minutes: 2));

      expect(decisions[1], GameEndAdDecision.interstitial);
    });
  });

  group('GameEndInterstitialCadence - every 3rd slot is the house ad', () {
    test('slots 1 and 2 are AdMob, slot 3 is the house ad', () async {
      final cadence = buildCadence();

      final decisions = await playGames(cadence, 6);
      final slots = decisions
          .where((d) => d != GameEndAdDecision.none)
          .toList();

      expect(slots, [
        GameEndAdDecision.interstitial,
        GameEndAdDecision.interstitial,
        GameEndAdDecision.houseAd,
      ]);
    });

    test('rotation continues: slot 6 is the house ad again', () async {
      final cadence = buildCadence();

      final decisions = await playGames(cadence, 12);
      final slots = decisions
          .where((d) => d != GameEndAdDecision.none)
          .toList();

      expect(slots, [
        GameEndAdDecision.interstitial,
        GameEndAdDecision.interstitial,
        GameEndAdDecision.houseAd,
        GameEndAdDecision.interstitial,
        GameEndAdDecision.interstitial,
        GameEndAdDecision.houseAd,
      ]);
    });

    test('slot count persists in the store', () async {
      final cadence = buildCadence();

      await playGames(cadence, 6);

      expect(await store.getInterstitialSlotCount(), 3);
    });
  });

  group('GameEndInterstitialCadence - fatigue interaction', () {
    test('fatigued user gets nothing even when a slot is due', () async {
      final cadence = buildCadence();
      fatigued = true;

      final decisions = await playGames(cadence, 2);

      expect(decisions, [
        GameEndAdDecision.none,
        GameEndAdDecision.none,
      ]);
    });

    test('fatigue does not consume the slot or reset the gap', () async {
      final cadence = buildCadence();

      fatigued = true;
      await playGames(cadence, 2); // slot due at game 2, suppressed

      fatigued = false;
      final decisions = await playGames(cadence, 2);

      // Game 4: slot 1 (first ever consumed) => AdMob interstitial.
      expect(decisions[1], GameEndAdDecision.interstitial);
      expect(await store.getInterstitialSlotCount(), 1);
    });

    test('fatigue check is not consulted when no slot is due', () async {
      var fatigueChecks = 0;
      final cadence = GameEndInterstitialCadence(
        store,
        now: () => currentTime,
        isFatigued: () async {
          fatigueChecks++;
          return false;
        },
      );

      await cadence.onGameCompleted(); // game 1: odd, no slot

      expect(fatigueChecks, 0);
    });
  });

  group('GameEndInterstitialCadence - defaults', () {
    test('constants match the product spec', () {
      expect(GameEndInterstitialCadence.gamesPerInterstitial, 2);
      expect(GameEndInterstitialCadence.minInterval,
          const Duration(minutes: 3));
      expect(GameEndInterstitialCadence.houseAdSlotEvery, 3);
    });

    test('works with default clock and no fatigue callback', () async {
      final cadence = GameEndInterstitialCadence(store);

      expect(await cadence.onGameCompleted(), GameEndAdDecision.none);
      expect(await cadence.onGameCompleted(), GameEndAdDecision.interstitial);
    });
  });
}
