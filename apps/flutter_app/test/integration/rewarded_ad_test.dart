import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

class MockAdRepository extends Mock implements AdRepository {}

void main() {
  late MockAdRepository mockRepo;
  late AdService adService;

  const userId = 'test-user-123';

  final sampleImpression = AdImpression(
    id: 'imp-1',
    userId: userId,
    adType: AdType.rewarded,
    placement: AdPlacement.rewardedDoubleCoins,
    watchedAt: DateTime.now(),
  );

  setUpAll(() {
    // Register fallback values for mocktail argument matchers.
    registerFallbackValue(AdType.rewarded);
    registerFallbackValue(AdPlacement.rewardedDoubleCoins);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockRepo = MockAdRepository();
    adService = AdService(mockRepo);
  });

  group('AdService — rewarded ad flow', () {
    test('can show rewarded when no ads watched today', () async {
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);

      final result = await adService.canShowRewarded(userId);

      expect(result, isTrue);
      verify(() => mockRepo.getRewardedAdCountToday(userId)).called(1);
      verify(() => mockRepo.getLastRewardedAdTime(userId)).called(1);
      verify(() => mockRepo.getCloseCountInWindow(userId, any())).called(1);
    });

    test('claiming reward grants 30 coins', () async {
      // Make user eligible.
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.recordImpression(userId, any(), any()))
          .thenAnswer((_) async => sampleImpression);
      when(() => mockRepo.addRewardedAdCoins(userId, 30))
          .thenAnswer((_) async => const CurrencyBalance(coins: 30, gems: 0));

      final balance = await adService.claimRewardedAdReward(userId);

      expect(balance.coins, equals(30));
      verify(() => mockRepo.addRewardedAdCoins(userId, 30)).called(1);
      verify(() => mockRepo.recordImpression(
            userId,
            AdType.rewarded,
            AdPlacement.rewardedDoubleCoins,
          )).called(1);
    });

    test('cannot show rewarded after reaching daily limit (5)', () async {
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 5);
      // These should not be called once daily limit is hit, but stub them
      // in case the implementation checks all conditions.
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);

      final result = await adService.canShowRewarded(userId);

      expect(result, isFalse);
    });

    test('cannot show rewarded during cooldown (within 20 minutes)', () async {
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 1);
      // Last watch was 5 minutes ago — well within the 20-minute cooldown.
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => DateTime.now().subtract(
                const Duration(minutes: 5),
              ));
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);

      final result = await adService.canShowRewarded(userId);

      expect(result, isFalse);
    });

    test('can show rewarded after cooldown expires', () async {
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 1);
      // Last watch was 25 minutes ago — cooldown has passed.
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => DateTime.now().subtract(
                const Duration(minutes: 25),
              ));
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);

      final result = await adService.canShowRewarded(userId);

      expect(result, isTrue);
    });

    test('fatigue pause triggered after 3 closes in 10-min window', () async {
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 1);
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => DateTime.now().subtract(
                const Duration(minutes: 25),
              ));
      // 3 closes within the fatigue window.
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 3);

      final result = await adService.canShowRewarded(userId);

      expect(result, isFalse);
    });

    test('constants have correct values', () {
      expect(AdService.maxRewardedPerDay, equals(5));
      expect(AdService.rewardedCooldown, equals(const Duration(minutes: 20)));
      expect(AdService.rewardedAdCoinReward, equals(30));
      expect(AdService.fatigueCloseThreshold, equals(3));
      expect(AdService.fatigueWindow, equals(const Duration(minutes: 10)));
      expect(
          AdService.fatiguePauseDuration, equals(const Duration(minutes: 30)));
    });

    test(
        'full flow: watch → coins credited → cooldown blocks → '
        'cooldown expires → second watch → cumulative coins', () async {
      // ── First watch: eligible, claim reward ───────────────────────────
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.recordImpression(userId, any(), any()))
          .thenAnswer((_) async => sampleImpression);
      when(() => mockRepo.addRewardedAdCoins(userId, 30))
          .thenAnswer((_) async => const CurrencyBalance(coins: 30, gems: 0));

      final firstBalance = await adService.claimRewardedAdReward(userId);
      expect(firstBalance.coins, equals(30));

      // ── Second watch attempt: blocked by cooldown ─────────────────────
      // Now count is 1, and last watch was just moments ago.
      when(() => mockRepo.getRewardedAdCountToday(userId))
          .thenAnswer((_) async => 1);
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => DateTime.now());

      final canShowDuringCooldown = await adService.canShowRewarded(userId);
      expect(canShowDuringCooldown, isFalse);

      // Attempting to claim during cooldown throws StateError.
      await expectLater(
        adService.claimRewardedAdReward(userId),
        throwsStateError,
      );

      // ── After cooldown expires: second watch succeeds ─────────────────
      when(() => mockRepo.getLastRewardedAdTime(userId))
          .thenAnswer((_) async => DateTime.now().subtract(
                const Duration(minutes: 21),
              ));
      when(() => mockRepo.getCloseCountInWindow(userId, any()))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.addRewardedAdCoins(userId, 30))
          .thenAnswer((_) async => const CurrencyBalance(coins: 60, gems: 0));

      final secondBalance = await adService.claimRewardedAdReward(userId);
      expect(secondBalance.coins, equals(60));

      // Verify cumulative: two successful claims were made.
      verify(() => mockRepo.addRewardedAdCoins(userId, 30)).called(2);
    });
  });
}
