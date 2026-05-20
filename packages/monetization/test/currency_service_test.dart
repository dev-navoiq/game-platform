import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

class MockCurrencyRepository extends Mock implements CurrencyRepository {}

void main() {
  late MockCurrencyRepository mockRepo;
  late CurrencyService service;

  setUp(() {
    mockRepo = MockCurrencyRepository();
    service = CurrencyService(mockRepo);
  });

  group('CurrencyService', () {
    // ── getBalance ─────────────────────────────────────────────────────

    test('getBalance delegates to repository', () async {
      const balance = CurrencyBalance(coins: 200, gems: 100);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);

      final result = await service.getBalance('user-1');

      expect(result, equals(balance));
      expect(result.coins, 200);
      expect(result.gems, 100);
      verify(() => mockRepo.getBalance('user-1')).called(1);
    });

    test('getBalance returns zero balance for new user', () async {
      const balance = CurrencyBalance.zero();
      when(() => mockRepo.getBalance('new-user'))
          .thenAnswer((_) async => balance);

      final result = await service.getBalance('new-user');

      expect(result.coins, 0);
      expect(result.gems, 0);
    });

    // ── earn ────────────────────────────────────────────────────────────

    test('earn coins returns updated balance', () async {
      const updated = CurrencyBalance(coins: 300, gems: 50);
      when(() => mockRepo.addCurrency('user-1', CurrencyType.coins, 100, 'game_win'))
          .thenAnswer((_) async => updated);

      final result = await service.earn(
        'user-1',
        CurrencyType.coins,
        100,
        'game_win',
      );

      expect(result.coins, 300);
      verify(() =>
              mockRepo.addCurrency('user-1', CurrencyType.coins, 100, 'game_win'))
          .called(1);
    });

    test('earn gems returns updated balance', () async {
      const updated = CurrencyBalance(coins: 200, gems: 150);
      when(() => mockRepo.addCurrency('user-1', CurrencyType.gems, 50, 'rewarded_ad'))
          .thenAnswer((_) async => updated);

      final result = await service.earn(
        'user-1',
        CurrencyType.gems,
        50,
        'rewarded_ad',
      );

      expect(result.gems, 150);
      verify(() =>
              mockRepo.addCurrency('user-1', CurrencyType.gems, 50, 'rewarded_ad'))
          .called(1);
    });

    test('earn throws ArgumentError for zero amount', () {
      expect(
        () => service.earn('user-1', CurrencyType.coins, 0, 'test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('earn throws ArgumentError for negative amount', () {
      expect(
        () => service.earn('user-1', CurrencyType.gems, -5, 'test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── spend ───────────────────────────────────────────────────────────

    test('spend coins succeeds when sufficient balance', () async {
      const balance = CurrencyBalance(coins: 500, gems: 100);
      const afterSpend = CurrencyBalance(coins: 300, gems: 100);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);
      when(() => mockRepo.deductCurrency(
              'user-1', CurrencyType.coins, 200, 'skin_purchase'))
          .thenAnswer((_) async => afterSpend);

      final result = await service.spend(
        'user-1',
        CurrencyType.coins,
        200,
        'skin_purchase',
      );

      expect(result.coins, 300);
      verify(() => mockRepo.getBalance('user-1')).called(1);
      verify(() => mockRepo.deductCurrency(
              'user-1', CurrencyType.coins, 200, 'skin_purchase'))
          .called(1);
    });

    test('spend gems succeeds when sufficient balance', () async {
      const balance = CurrencyBalance(coins: 500, gems: 600);
      const afterSpend = CurrencyBalance(coins: 500, gems: 100);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);
      when(() => mockRepo.deductCurrency(
              'user-1', CurrencyType.gems, 500, 'premium_pass'))
          .thenAnswer((_) async => afterSpend);

      final result = await service.spend(
        'user-1',
        CurrencyType.gems,
        500,
        'premium_pass',
      );

      expect(result.gems, 100);
    });

    test('spend coins throws InsufficientFundsException when balance too low',
        () async {
      const balance = CurrencyBalance(coins: 50, gems: 100);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);

      expect(
        () => service.spend('user-1', CurrencyType.coins, 200, 'purchase'),
        throwsA(isA<InsufficientFundsException>()
            .having((e) => e.available, 'available', 50)
            .having((e) => e.required, 'required', 200)
            .having((e) => e.currency, 'currency', CurrencyType.coins)),
      );
    });

    test('spend gems throws InsufficientFundsException when balance too low',
        () async {
      const balance = CurrencyBalance(coins: 500, gems: 10);
      when(() => mockRepo.getBalance('user-1'))
          .thenAnswer((_) async => balance);

      expect(
        () => service.spend('user-1', CurrencyType.gems, 100, 'season_pass'),
        throwsA(isA<InsufficientFundsException>()
            .having((e) => e.currency, 'currency', CurrencyType.gems)
            .having((e) => e.available, 'available', 10)),
      );
    });

    test('spend throws ArgumentError for zero amount', () {
      expect(
        () => service.spend('user-1', CurrencyType.coins, 0, 'test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('spend throws ArgumentError for negative amount', () {
      expect(
        () => service.spend('user-1', CurrencyType.coins, -10, 'test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── getTransactions ─────────────────────────────────────────────────

    test('getTransactions delegates to repository with default limit', () async {
      final txns = [
        CurrencyTransaction(
          id: 'txn-1',
          userId: 'user-1',
          type: CurrencyType.coins,
          amount: 100,
          reason: 'game_win',
          createdAt: DateTime(2026, 3, 1),
        ),
        CurrencyTransaction(
          id: 'txn-2',
          userId: 'user-1',
          type: CurrencyType.gems,
          amount: 50,
          reason: 'rewarded_ad',
          createdAt: DateTime(2026, 3, 1),
        ),
      ];
      when(() => mockRepo.getTransactions('user-1', limit: 50))
          .thenAnswer((_) async => txns);

      final result = await service.getTransactions('user-1');

      expect(result, hasLength(2));
      verify(() => mockRepo.getTransactions('user-1', limit: 50)).called(1);
    });

    test('getTransactions passes custom limit', () async {
      when(() => mockRepo.getTransactions('user-1', limit: 10))
          .thenAnswer((_) async => []);

      final result = await service.getTransactions('user-1', limit: 10);

      expect(result, isEmpty);
      verify(() => mockRepo.getTransactions('user-1', limit: 10)).called(1);
    });

    // ── InsufficientFundsException ──────────────────────────────────────

    test('InsufficientFundsException toString includes details', () {
      const ex = InsufficientFundsException(
        currency: CurrencyType.coins,
        required: 200,
        available: 50,
      );
      expect(ex.toString(), contains('200'));
      expect(ex.toString(), contains('50'));
      expect(ex.toString(), contains('coins'));
    });
  });

  group('CurrencyBalance', () {
    test('Equatable equality works', () {
      const a = CurrencyBalance(coins: 100, gems: 50);
      const b = CurrencyBalance(coins: 100, gems: 50);
      const c = CurrencyBalance(coins: 200, gems: 50);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      const balance = CurrencyBalance(coins: 100, gems: 50);
      final modified = balance.copyWith(coins: 200);

      expect(modified.coins, 200);
      expect(modified.gems, 50);
    });
  });
}
