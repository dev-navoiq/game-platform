import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

class MockSeasonRepository extends Mock implements SeasonRepository {}

void main() {
  late MockSeasonRepository mockRepo;
  late SeasonService service;

  final activeSeason = Season(
    id: 'season-1',
    name: 'Season 1',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 6, 30),
    totalLevels: 50,
  );

  const baseProgress = UserSeasonProgress(
    userId: 'user-1',
    seasonId: 'season-1',
    currentLevel: 5,
    currentXp: 300,
    xpToNextLevel: 500,
  );

  setUp(() {
    mockRepo = MockSeasonRepository();
    service = SeasonService(mockRepo);

    registerFallbackValue(baseProgress);
  });

  group('SeasonService', () {
    // ── getCurrentSeason ────────────────────────────────────────────────

    test('getCurrentSeason delegates to repository', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);

      final result = await service.getCurrentSeason();

      expect(result, activeSeason);
      verify(() => mockRepo.getCurrentSeason()).called(1);
    });

    test('getCurrentSeason returns null when no active season', () async {
      when(() => mockRepo.getCurrentSeason()).thenAnswer((_) async => null);

      final result = await service.getCurrentSeason();

      expect(result, isNull);
    });

    // ── getProgress ─────────────────────────────────────────────────────

    test('getProgress returns user progress', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress);

      final result = await service.getProgress('user-1');

      expect(result.currentLevel, 5);
      expect(result.currentXp, 300);
    });

    test('getProgress throws StateError when no active season', () async {
      when(() => mockRepo.getCurrentSeason()).thenAnswer((_) async => null);

      expect(
        () => service.getProgress('user-1'),
        throwsA(isA<StateError>()),
      );
    });

    // ── addXp ───────────────────────────────────────────────────────────

    test('addXp adds XP without level-up', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      // Level 5, 300 XP, xpForLevel(5) = 500. Adding 100 => 400 XP, stays level 5
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress);

      final expected = baseProgress.copyWith(currentXp: 400, xpToNextLevel: 500);
      when(() => mockRepo.saveProgress(any()))
          .thenAnswer((_) async => expected);

      final result = await service.addXp('user-1', 100);

      expect(result.currentLevel, 5);
      expect(result.currentXp, 400);
    });

    test('addXp handles single level-up', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      // Level 1, 50 XP, xpForLevel(1) = 100. Adding 80 => 130. Level up: 130-100 = 30 at level 2
      const progress = UserSeasonProgress(
        userId: 'user-1',
        seasonId: 'season-1',
        currentLevel: 1,
        currentXp: 50,
        xpToNextLevel: 100,
      );
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => progress);

      // 50 + 80 = 130 total. xpForLevel(1) = 100, so 130 - 100 = 30 at level 2
      final expected = progress.copyWith(
        currentLevel: 2,
        currentXp: 30,
        xpToNextLevel: 200,
      );
      when(() => mockRepo.saveProgress(any()))
          .thenAnswer((_) async => expected);

      final result = await service.addXp('user-1', 80);

      // Verify the progress passed to saveProgress
      final captured =
          verify(() => mockRepo.saveProgress(captureAny())).captured;
      final saved = captured.first as UserSeasonProgress;
      expect(saved.currentLevel, 2);
      expect(saved.currentXp, 30);
      expect(saved.xpToNextLevel, 200); // xpForLevel(2) = 200
    });

    test('addXp handles multiple level-ups', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      // Level 1, 0 XP. Adding 350 XP:
      // Level 1 needs 100: 350 - 100 = 250 left, level 2
      // Level 2 needs 200: 250 - 200 = 50 left, level 3
      // Level 3 needs 300: 50 < 300, stays at level 3 with 50 XP
      const progress = UserSeasonProgress(
        userId: 'user-1',
        seasonId: 'season-1',
        currentLevel: 1,
        currentXp: 0,
        xpToNextLevel: 100,
      );
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => progress);

      final expected = progress.copyWith(
        currentLevel: 3,
        currentXp: 50,
        xpToNextLevel: 300,
      );
      when(() => mockRepo.saveProgress(any()))
          .thenAnswer((_) async => expected);

      await service.addXp('user-1', 350);

      final captured =
          verify(() => mockRepo.saveProgress(captureAny())).captured;
      final saved = captured.first as UserSeasonProgress;
      expect(saved.currentLevel, 3);
      expect(saved.currentXp, 50);
    });

    test('addXp throws StateError when no active season', () async {
      when(() => mockRepo.getCurrentSeason()).thenAnswer((_) async => null);

      expect(
        () => service.addXp('user-1', 100),
        throwsA(isA<StateError>()),
      );
    });

    test('addXp throws ArgumentError for zero amount', () {
      expect(
        () => service.addXp('user-1', 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addXp throws ArgumentError for negative amount', () {
      expect(
        () => service.addXp('user-1', -10),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── buyPremiumPass ──────────────────────────────────────────────────

    test('buyPremiumPass succeeds with sufficient gems', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => const CurrencyBalance(coins: 0, gems: 600));
      when(() => mockRepo.deductGems('user-1', 500))
          .thenAnswer((_) async => const CurrencyBalance(coins: 0, gems: 100));

      final premiumProgress = baseProgress.copyWith(hasPremiumPass: true);
      when(() => mockRepo.saveProgress(any()))
          .thenAnswer((_) async => premiumProgress);

      final result = await service.buyPremiumPass('user-1');

      expect(result.hasPremiumPass, isTrue);
      verify(() => mockRepo.deductGems('user-1', 500)).called(1);
    });

    test('buyPremiumPass throws StateError when insufficient gems', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => const CurrencyBalance(coins: 0, gems: 100));

      expect(
        () => service.buyPremiumPass('user-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('buyPremiumPass throws StateError when already premium', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer(
              (_) async => baseProgress.copyWith(hasPremiumPass: true));

      expect(
        () => service.buyPremiumPass('user-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('buyPremiumPass throws StateError when no active season', () async {
      when(() => mockRepo.getCurrentSeason()).thenAnswer((_) async => null);

      expect(
        () => service.buyPremiumPass('user-1'),
        throwsA(isA<StateError>()),
      );
    });

    // ── claimReward ─────────────────────────────────────────────────────

    test('claimReward succeeds when level is reached', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress); // level 5
      const reward = SeasonReward(
        level: 5,
        description: '100 coins',
        coinReward: 100,
      );
      when(() => mockRepo.claimReward('user-1', 'season-1', 5))
          .thenAnswer((_) async => reward);

      final result = await service.claimReward('user-1', 5);

      expect(result.coinReward, 100);
      expect(result.level, 5);
    });

    test('claimReward throws StateError when level not reached', () async {
      when(() => mockRepo.getCurrentSeason())
          .thenAnswer((_) async => activeSeason);
      when(() => mockRepo.getProgress('user-1', 'season-1'))
          .thenAnswer((_) async => baseProgress); // level 5

      expect(
        () => service.claimReward('user-1', 10),
        throwsA(isA<StateError>()),
      );
    });

    test('claimReward throws StateError when no active season', () async {
      when(() => mockRepo.getCurrentSeason()).thenAnswer((_) async => null);

      expect(
        () => service.claimReward('user-1', 5),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SeasonService - xpForLevel', () {
    test('XP curve follows N * 100 formula', () {
      expect(SeasonService.xpForLevel(1), 100);
      expect(SeasonService.xpForLevel(5), 500);
      expect(SeasonService.xpForLevel(10), 1000);
      expect(SeasonService.xpForLevel(50), 5000);
    });
  });

  group('Season model', () {
    test('daysRemaining returns correct value for active season', () {
      final season = Season(
        id: 's',
        name: 'Test',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(season.daysRemaining, greaterThanOrEqualTo(29));
      expect(season.daysRemaining, lessThanOrEqualTo(30));
    });

    test('daysRemaining clamps to 0 for expired season', () {
      final season = Season(
        id: 's',
        name: 'Expired',
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(season.daysRemaining, 0);
    });
  });

  group('UserSeasonProgress model', () {
    test('levelProgress calculates correctly', () {
      const progress = UserSeasonProgress(
        userId: 'u',
        seasonId: 's',
        currentLevel: 5,
        currentXp: 250,
        xpToNextLevel: 500,
      );
      expect(progress.levelProgress, 0.5);
    });

    test('levelProgress clamps to 1.0', () {
      const progress = UserSeasonProgress(
        userId: 'u',
        seasonId: 's',
        currentLevel: 5,
        currentXp: 600,
        xpToNextLevel: 500,
      );
      expect(progress.levelProgress, 1.0);
    });
  });

  group('SeasonReward model', () {
    test('supports both coin and gem rewards', () {
      const reward = SeasonReward(
        level: 10,
        description: 'Level 10 reward',
        coinReward: 500,
        gemReward: 50,
      );
      expect(reward.coinReward, 500);
      expect(reward.gemReward, 50);
      expect(reward.isPremiumOnly, isFalse);
    });

    test('supports premium-only rewards', () {
      const reward = SeasonReward(
        level: 10,
        description: 'Exclusive skin',
        skinId: 'skin-gold',
        isPremiumOnly: true,
      );
      expect(reward.isPremiumOnly, isTrue);
      expect(reward.skinId, 'skin-gold');
    });
  });
}
