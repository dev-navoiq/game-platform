import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

class MockChallengeRepository extends Mock implements ChallengeRepository {}

void main() {
  late MockChallengeRepository mockRepo;
  late ChallengeService service;

  final now = DateTime.now();

  final dailyChallenge = Challenge(
    id: 'ch-1',
    title: 'Win 3 games',
    description: 'Win 3 games of any type',
    type: ChallengeType.daily,
    target: 3,
    rewardCoins: 50,
    createdAt: now,
  );

  final weeklyChallenge = Challenge(
    id: 'ch-2',
    title: 'Play 20 games',
    description: 'Play 20 games of any type',
    type: ChallengeType.weekly,
    target: 20,
    rewardCoins: 200,
    rewardGems: 20,
    createdAt: now,
  );

  final userDaily = UserChallenge(
    challengeId: 'ch-1',
    userId: 'user-1',
    current: 1,
    challenge: dailyChallenge,
  );

  final userWeekly = UserChallenge(
    challengeId: 'ch-2',
    userId: 'user-1',
    current: 5,
    challenge: weeklyChallenge,
  );

  setUp(() {
    mockRepo = MockChallengeRepository();
    service = ChallengeService(mockRepo);
  });

  group('ChallengeService', () {
    // ── getActiveChallenges ─────────────────────────────────────────────

    test('getActiveChallenges delegates to repository', () async {
      final challenges = [userDaily, userWeekly];
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => challenges);

      final result = await service.getActiveChallenges('user-1');

      expect(result, hasLength(2));
      verify(() => mockRepo.getActiveChallenges('user-1')).called(1);
    });

    // ── updateProgress ──────────────────────────────────────────────────

    test('updateProgress increments and returns updated challenge', () async {
      final updated = userDaily.copyWith(current: 2);
      when(() => mockRepo.updateProgress('user-1', 'ch-1', 1))
          .thenAnswer((_) async => updated);

      final result = await service.updateProgress('user-1', 'ch-1', 1);

      expect(result.current, 2);
      verify(() => mockRepo.updateProgress('user-1', 'ch-1', 1)).called(1);
    });

    test('updateProgress throws ArgumentError for zero incrementBy', () {
      expect(
        () => service.updateProgress('user-1', 'ch-1', 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('updateProgress throws ArgumentError for negative incrementBy', () {
      expect(
        () => service.updateProgress('user-1', 'ch-1', -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── rerollChallenge ─────────────────────────────────────────────────

    test('rerollChallenge succeeds when user has coins and challenge is rerollable',
        () async {
      const balance = CurrencyBalance(coins: 100, gems: 0);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => [userDaily]);
      when(() => mockRepo.deductCoins('user-1', 25))
          .thenAnswer((_) async => const CurrencyBalance(coins: 75, gems: 0));

      final rerolled = UserChallenge(
        challengeId: 'ch-3',
        userId: 'user-1',
        current: 0,
        challenge: Challenge(
          id: 'ch-3',
          title: 'Play 5 chess games',
          description: 'Play 5 chess games',
          type: ChallengeType.daily,
          target: 5,
          rewardCoins: 60,
          createdAt: now,
        ),
      );
      when(() => mockRepo.rerollChallenge('user-1', 'ch-1'))
          .thenAnswer((_) async => rerolled);

      final result = await service.rerollChallenge('user-1', 'ch-1');

      expect(result.challengeId, 'ch-3');
      verify(() => mockRepo.deductCoins('user-1', 25)).called(1);
      verify(() => mockRepo.rerollChallenge('user-1', 'ch-1')).called(1);
    });

    test('rerollChallenge throws StateError when insufficient coins', () async {
      const balance = CurrencyBalance(coins: 10, gems: 0);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);

      expect(
        () => service.rerollChallenge('user-1', 'ch-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('rerollChallenge throws StateError when canReroll is false', () async {
      const balance = CurrencyBalance(coins: 100, gems: 0);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);

      final nonRerollable = userDaily.copyWith(canReroll: false);
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => [nonRerollable]);

      expect(
        () => service.rerollChallenge('user-1', 'ch-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('rerollChallenge throws StateError when challenge not found', () async {
      const balance = CurrencyBalance(coins: 100, gems: 0);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => []);

      expect(
        () => service.rerollChallenge('user-1', 'nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    // ── claimReward ─────────────────────────────────────────────────────

    test('claimReward succeeds when challenge is completed', () async {
      final completed = userDaily.copyWith(current: 3, isCompleted: true);
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => [completed, userWeekly]);
      when(() => mockRepo.claimReward('user-1', 'ch-1'))
          .thenAnswer((_) async => const CurrencyBalance(coins: 250, gems: 0));

      final result = await service.claimReward('user-1', 'ch-1');

      expect(result.coins, 250);
      verify(() => mockRepo.claimReward('user-1', 'ch-1')).called(1);
    });

    test('claimReward throws StateError when challenge is not completed',
        () async {
      when(() => mockRepo.getActiveChallenges('user-1'))
          .thenAnswer((_) async => [userDaily]);

      expect(
        () => service.claimReward('user-1', 'ch-1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ChallengeService - constants', () {
    test('daily challenge count is 3', () {
      expect(ChallengeService.dailyChallengeCount, 3);
    });

    test('weekly challenge count is 5', () {
      expect(ChallengeService.weeklyChallengeCount, 5);
    });

    test('reroll costs 25 coins', () {
      expect(ChallengeService.rerollCostCoins, 25);
    });
  });

  group('UserChallenge', () {
    test('progressPercent calculates correctly', () {
      expect(userDaily.progressPercent, closeTo(0.333, 0.01));
      expect(userWeekly.progressPercent, 0.25);
    });

    test('progressPercent clamps to 1.0 when over target', () {
      final over = userDaily.copyWith(current: 5);
      expect(over.progressPercent, 1.0);
    });

    test('progressPercent returns 0 when no challenge attached', () {
      const noCh = UserChallenge(
        challengeId: 'x',
        userId: 'u',
        current: 3,
      );
      expect(noCh.progressPercent, 0);
    });
  });
}
