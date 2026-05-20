import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

/// In-memory fake [SeasonRepository] that tracks state for realistic
/// integration testing without hitting a real backend.
class InMemorySeasonRepository extends Mock implements SeasonRepository {
  final Season? _activeSeason;
  final Map<String, UserSeasonProgress> _progress = {};
  final Map<String, CurrencyBalance> _balances = {};
  final List<SeasonReward> _rewards;
  final Set<String> _claimedRewards = {};

  InMemorySeasonRepository({
    Season? activeSeason,
    CurrencyBalance defaultBalance = const CurrencyBalance(coins: 0, gems: 0),
    List<SeasonReward> rewards = const [],
  })  : _activeSeason = activeSeason,
        _rewards = rewards {
    // Wire up real implementations using mocktail's fallback mechanism.
    // Each method delegates to the in-memory state.
    when(() => getCurrentSeason()).thenAnswer((_) async => _activeSeason);

    when(() => getProgress(any(), any())).thenAnswer((invocation) async {
      final userId = invocation.positionalArguments[0] as String;
      final seasonId = invocation.positionalArguments[1] as String;
      return _progress.putIfAbsent(
        _progressKey(userId, seasonId),
        () => UserSeasonProgress(userId: userId, seasonId: seasonId),
      );
    });

    when(() => saveProgress(any())).thenAnswer((invocation) async {
      final progress = invocation.positionalArguments[0] as UserSeasonProgress;
      _progress[_progressKey(progress.userId, progress.seasonId)] = progress;
      return progress;
    });

    when(() => getRewards(any())).thenAnswer((_) async => _rewards);

    when(() => claimReward(any(), any(), any())).thenAnswer((invocation) async {
      final userId = invocation.positionalArguments[0] as String;
      final seasonId = invocation.positionalArguments[1] as String;
      final level = invocation.positionalArguments[2] as int;
      final key = '$userId:$seasonId:$level';
      if (_claimedRewards.contains(key)) {
        throw StateError('Reward at level $level already claimed');
      }
      _claimedRewards.add(key);
      final reward = _rewards.firstWhere(
        (r) => r.level == level,
        orElse: () => SeasonReward(level: level, description: 'Reward $level'),
      );
      return reward;
    });

    when(() => getBalance(any())).thenAnswer((invocation) async {
      final userId = invocation.positionalArguments[0] as String;
      return _balances.putIfAbsent(userId, () => defaultBalance);
    });

    when(() => deductGems(any(), any())).thenAnswer((invocation) async {
      final userId = invocation.positionalArguments[0] as String;
      final amount = invocation.positionalArguments[1] as int;
      final current = _balances.putIfAbsent(userId, () => defaultBalance);
      final updated = current.copyWith(gems: current.gems - amount);
      _balances[userId] = updated;
      return updated;
    });
  }

  String _progressKey(String userId, String seasonId) => '$userId:$seasonId';

  /// Seed a user's balance directly (useful for test setup).
  void seedBalance(String userId, CurrencyBalance balance) {
    _balances[userId] = balance;
  }

  /// Read the stored progress for assertions.
  UserSeasonProgress? storedProgress(String userId, String seasonId) =>
      _progress[_progressKey(userId, seasonId)];

  /// Read the stored balance for assertions.
  CurrencyBalance? storedBalance(String userId) => _balances[userId];
}

void main() {
  setUpAll(() {
    registerFallbackValue(const UserSeasonProgress(
      userId: '',
      seasonId: '',
    ));
  });

  late InMemorySeasonRepository repository;
  late SeasonService service;

  const userId = 'user-123';
  const seasonId = 'season-2026-spring';

  final activeSeason = Season(
    id: seasonId,
    name: 'Spring 2026',
    startDate: DateTime(2026, 3, 1),
    endDate: DateTime(2026, 6, 1),
    totalLevels: 50,
  );

  final testRewards = [
    const SeasonReward(
      level: 1,
      description: '100 Coins',
      coinReward: 100,
    ),
    const SeasonReward(
      level: 2,
      description: 'Premium Card Skin',
      skinId: 'skin-gold',
      isPremiumOnly: true,
    ),
    const SeasonReward(
      level: 3,
      description: '50 Gems',
      gemReward: 50,
    ),
    const SeasonReward(
      level: 5,
      description: 'Legendary Skin',
      skinId: 'skin-legendary',
      isPremiumOnly: true,
    ),
  ];

  setUp(() {
    repository = InMemorySeasonRepository(
      activeSeason: activeSeason,
      defaultBalance: const CurrencyBalance(coins: 1000, gems: 600),
      rewards: testRewards,
    );
    service = SeasonService(repository);
  });

  group('XP and levelling', () {
    test('XP gain updates progress correctly', () async {
      final progress = await service.addXp(userId, 50);

      expect(progress.currentXp, 50);
      expect(progress.currentLevel, 1);
      expect(progress.xpToNextLevel, 100); // level 1 * 100
    });

    test('level up when XP exceeds threshold (level 1 → 2 needs 100 XP)',
        () async {
      final progress = await service.addXp(userId, 100);

      expect(progress.currentLevel, 2);
      expect(progress.currentXp, 0); // 100 - 100 = 0 remaining
      expect(progress.xpToNextLevel, 200); // level 2 * 100
    });

    test('multiple level ups in one addXp call (350 XP from level 1)',
        () async {
      // Level 1 → 2: costs 100 XP (remaining: 250)
      // Level 2 → 3: costs 200 XP (remaining: 50)
      // Level 3 → 4: costs 300 XP (not enough)
      final progress = await service.addXp(userId, 350);

      expect(progress.currentLevel, 3);
      expect(progress.currentXp, 50);
      expect(progress.xpToNextLevel, 300); // level 3 * 100
    });

    test('XP accumulates across multiple addXp calls', () async {
      await service.addXp(userId, 50);
      final progress = await service.addXp(userId, 60);

      // 50 + 60 = 110 XP; level 1 costs 100 → level 2 with 10 remaining
      expect(progress.currentLevel, 2);
      expect(progress.currentXp, 10);
    });

    test('xpForLevel returns level * 100', () {
      expect(SeasonService.xpForLevel(1), 100);
      expect(SeasonService.xpForLevel(5), 500);
      expect(SeasonService.xpForLevel(50), 5000);
    });
  });

  group('reward claiming', () {
    test('claim free-track reward at reached level', () async {
      // Level up to at least level 1 (already at level 1 by default)
      final reward = await service.claimReward(userId, 1);

      expect(reward.level, 1);
      expect(reward.description, '100 Coins');
      expect(reward.coinReward, 100);
      expect(reward.isPremiumOnly, false);
    });

    test('cannot claim reward at unreached level', () async {
      // User is at level 1, trying to claim level 5 reward
      expect(
        () => service.claimReward(userId, 5),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('cannot claim level 5'),
        )),
      );
    });

    test('claim reward after levelling up', () async {
      await service.addXp(userId, 350); // reaches level 3
      final reward = await service.claimReward(userId, 3);

      expect(reward.level, 3);
      expect(reward.description, '50 Gems');
      expect(reward.gemReward, 50);
    });
  });

  group('premium pass', () {
    test('buy premium pass costs 500 gems', () async {
      final progress = await service.buyPremiumPass(userId);

      expect(progress.hasPremiumPass, true);

      final balance = repository.storedBalance(userId);
      expect(balance, isNotNull);
      // Started with 600 gems, paid 500
      expect(balance!.gems, 100);
    });

    test('cannot buy premium pass with insufficient gems', () async {
      repository.seedBalance(userId, const CurrencyBalance(coins: 500, gems: 100));

      expect(
        () => service.buyPremiumPass(userId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient gems'),
        )),
      );
    });

    test('cannot buy premium pass twice', () async {
      await service.buyPremiumPass(userId);

      expect(
        () => service.buyPremiumPass(userId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already has the premium season pass'),
        )),
      );
    });

    test('premiumPassGemCost is 500', () {
      expect(SeasonService.premiumPassGemCost, 500);
    });
  });

  group('full flow', () {
    test(
      'earn XP → level up to 3 → claim free reward → buy premium → claim premium reward',
      () async {
        // 1. Earn XP to reach level 3
        //    Level 1→2: 100 XP, Level 2→3: 200 XP = 300 total needed
        final progress = await service.addXp(userId, 350);
        expect(progress.currentLevel, 3);
        expect(progress.currentXp, 50);

        // 2. Claim free-track reward at level 1
        final freeReward = await service.claimReward(userId, 1);
        expect(freeReward.level, 1);
        expect(freeReward.coinReward, 100);
        expect(freeReward.isPremiumOnly, false);

        // 3. Claim free-track reward at level 3
        final freeReward3 = await service.claimReward(userId, 3);
        expect(freeReward3.gemReward, 50);

        // 4. Buy premium pass (costs 500 gems from 600 balance)
        final premiumProgress = await service.buyPremiumPass(userId);
        expect(premiumProgress.hasPremiumPass, true);
        expect(premiumProgress.currentLevel, 3); // level preserved

        final balance = repository.storedBalance(userId);
        expect(balance!.gems, 100); // 600 - 500

        // 5. Claim premium-only reward at level 2
        final premiumReward = await service.claimReward(userId, 2);
        expect(premiumReward.level, 2);
        expect(premiumReward.isPremiumOnly, true);
        expect(premiumReward.skinId, 'skin-gold');
      },
    );
  });
}
