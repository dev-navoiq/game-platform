import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

class MockAdRepository extends Mock implements AdRepository {}

void main() {
  late MockAdRepository mockRepo;
  late AdService service;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(AdType.banner);
    registerFallbackValue(AdPlacement.lobbyBanner);
  });

  setUp(() {
    mockRepo = MockAdRepository();
    service = AdService(mockRepo);
  });

  group('AdService - canShowRewarded', () {
    test('returns true when all conditions met', () async {
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 2);
      when(() => mockRepo.getLastRewardedAdTime('user-1'))
          .thenAnswer((_) async =>
              DateTime.now().subtract(const Duration(minutes: 25)));
      when(() => mockRepo.getCloseCountInWindow('user-1', any()))
          .thenAnswer((_) async => 0);

      final result = await service.canShowRewarded('user-1');

      expect(result, isTrue);
    });

    test('returns true when no previous rewarded ad', () async {
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 0);
      when(() => mockRepo.getLastRewardedAdTime('user-1'))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getCloseCountInWindow('user-1', any()))
          .thenAnswer((_) async => 0);

      final result = await service.canShowRewarded('user-1');

      expect(result, isTrue);
    });

    test('returns false when daily limit (5) reached', () async {
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 5);

      final result = await service.canShowRewarded('user-1');

      expect(result, isFalse);
    });

    test('returns false when on 20-minute cooldown', () async {
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 2);
      when(() => mockRepo.getLastRewardedAdTime('user-1'))
          .thenAnswer((_) async =>
              DateTime.now().subtract(const Duration(minutes: 5)));

      final result = await service.canShowRewarded('user-1');

      expect(result, isFalse);
    });

    test('returns false when in ad fatigue pause (3 closes in 10 min)',
        () async {
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 2);
      when(() => mockRepo.getLastRewardedAdTime('user-1'))
          .thenAnswer((_) async =>
              DateTime.now().subtract(const Duration(minutes: 25)));
      when(() => mockRepo.getCloseCountInWindow('user-1', any()))
          .thenAnswer((_) async => 3);

      final result = await service.canShowRewarded('user-1');

      expect(result, isFalse);
    });
  });

  group('AdService - recordImpression', () {
    test('delegates to repository and returns impression', () async {
      final impression = AdImpression(
        id: 'imp-1',
        userId: 'user-1',
        adType: AdType.banner,
        placement: AdPlacement.lobbyBanner,
        watchedAt: DateTime(2026, 3, 1),
      );
      when(() => mockRepo.recordImpression(
              'user-1', AdType.banner, AdPlacement.lobbyBanner))
          .thenAnswer((_) async => impression);

      final result = await service.recordImpression(
        'user-1',
        AdType.banner,
        AdPlacement.lobbyBanner,
      );

      expect(result.adType, AdType.banner);
      expect(result.placement, AdPlacement.lobbyBanner);
      verify(() => mockRepo.recordImpression(
              'user-1', AdType.banner, AdPlacement.lobbyBanner))
          .called(1);
    });
  });

  group('AdService - claimRewardedAdReward', () {
    test('grants 30 coins when eligible', () async {
      // Set up canShowRewarded to return true
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 1);
      when(() => mockRepo.getLastRewardedAdTime('user-1'))
          .thenAnswer((_) async =>
              DateTime.now().subtract(const Duration(minutes: 25)));
      when(() => mockRepo.getCloseCountInWindow('user-1', any()))
          .thenAnswer((_) async => 0);

      // Record impression
      final impression = AdImpression(
        id: 'imp-2',
        userId: 'user-1',
        adType: AdType.rewarded,
        placement: AdPlacement.rewardedDoubleCoins,
        watchedAt: DateTime.now(),
      );
      when(() => mockRepo.recordImpression(
              'user-1', AdType.rewarded, AdPlacement.rewardedDoubleCoins))
          .thenAnswer((_) async => impression);

      // Add coins
      const updatedBalance = CurrencyBalance(coins: 230, gems: 50);
      when(() => mockRepo.addRewardedAdCoins('user-1', 30))
          .thenAnswer((_) async => updatedBalance);

      final result = await service.claimRewardedAdReward('user-1');

      expect(result.coins, 230);
      verify(() => mockRepo.recordImpression(
              'user-1', AdType.rewarded, AdPlacement.rewardedDoubleCoins))
          .called(1);
      verify(() => mockRepo.addRewardedAdCoins('user-1', 30)).called(1);
    });

    test('throws StateError when not eligible', () async {
      // Daily limit reached
      when(() => mockRepo.getRewardedAdCountToday('user-1'))
          .thenAnswer((_) async => 5);

      expect(
        () => service.claimRewardedAdReward('user-1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AdService - constants', () {
    test('max rewarded per day is 5', () {
      expect(AdService.maxRewardedPerDay, 5);
    });

    test('rewarded cooldown is 20 minutes', () {
      expect(AdService.rewardedCooldown, const Duration(minutes: 20));
    });

    test('rewarded ad coin reward is 30', () {
      expect(AdService.rewardedAdCoinReward, 30);
    });

    test('fatigue threshold is 3 closes in 10 minutes', () {
      expect(AdService.fatigueCloseThreshold, 3);
      expect(AdService.fatigueWindow, const Duration(minutes: 10));
    });
  });
}
