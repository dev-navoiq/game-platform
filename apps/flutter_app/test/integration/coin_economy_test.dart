import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

/// In-memory mock of [CurrencyRepository] that tracks balance state
/// across calls, enabling realistic integration testing without Supabase.
class MockCurrencyRepository extends Mock implements CurrencyRepository {
  CurrencyBalance _balance = const CurrencyBalance.zero();
  final List<CurrencyTransaction> _transactions = [];

  void _setupDefaults() {
    when(() => getBalance(any())).thenAnswer((_) async => _balance);

    when(() => addCurrency(any(), any(), any(), any()))
        .thenAnswer((invocation) async {
      final type = invocation.positionalArguments[1] as CurrencyType;
      final amount = invocation.positionalArguments[2] as int;
      final reason = invocation.positionalArguments[3] as String;
      final userId = invocation.positionalArguments[0] as String;

      _balance = type == CurrencyType.coins
          ? _balance.copyWith(coins: _balance.coins + amount)
          : _balance.copyWith(gems: _balance.gems + amount);

      _transactions.add(CurrencyTransaction(
        id: 'txn-${_transactions.length + 1}',
        userId: userId,
        type: type,
        amount: amount,
        reason: reason,
        createdAt: DateTime.now(),
      ));

      return _balance;
    });

    when(() => deductCurrency(any(), any(), any(), any()))
        .thenAnswer((invocation) async {
      final type = invocation.positionalArguments[1] as CurrencyType;
      final amount = invocation.positionalArguments[2] as int;
      final reason = invocation.positionalArguments[3] as String;
      final userId = invocation.positionalArguments[0] as String;

      _balance = type == CurrencyType.coins
          ? _balance.copyWith(coins: _balance.coins - amount)
          : _balance.copyWith(gems: _balance.gems - amount);

      _transactions.add(CurrencyTransaction(
        id: 'txn-${_transactions.length + 1}',
        userId: userId,
        type: type,
        amount: -amount,
        reason: reason,
        createdAt: DateTime.now(),
      ));

      return _balance;
    });

    when(() => getTransactions(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => List.unmodifiable(_transactions.reversed));
  }
}

void main() {
  const userId = 'test-user-123';

  late MockCurrencyRepository mockRepo;
  late CurrencyService service;

  setUpAll(() {
    registerFallbackValue(CurrencyType.coins);
  });

  setUp(() {
    mockRepo = MockCurrencyRepository().._setupDefaults();
    service = CurrencyService(mockRepo);
  });

  group('Coin Economy Integration', () {
    test('daily bonus earns 200 coins', () async {
      final balance = await service.earn(
        userId,
        CurrencyType.coins,
        200,
        'daily_bonus',
      );

      expect(balance.coins, 200);
      expect(balance.gems, 0);
      verify(() => mockRepo.addCurrency(
            userId,
            CurrencyType.coins,
            200,
            'daily_bonus',
          )).called(1);
    });

    test('game win earns 50 coins', () async {
      final balance = await service.earn(
        userId,
        CurrencyType.coins,
        50,
        'game_win',
      );

      expect(balance.coins, 50);
      expect(balance.gems, 0);
      verify(() => mockRepo.addCurrency(
            userId,
            CurrencyType.coins,
            50,
            'game_win',
          )).called(1);
    });

    test('cumulative balance grows correctly after multiple earns', () async {
      await service.earn(userId, CurrencyType.coins, 200, 'daily_bonus');
      final balance =
          await service.earn(userId, CurrencyType.coins, 50, 'game_win');

      expect(balance.coins, 250);
      expect(balance.gems, 0);
    });

    test('tournament entry spends 100 coins', () async {
      // Seed balance first
      await service.earn(userId, CurrencyType.coins, 200, 'daily_bonus');

      final balance = await service.spend(
        userId,
        CurrencyType.coins,
        100,
        'tournament_entry',
      );

      expect(balance.coins, 100);
      verify(() => mockRepo.deductCurrency(
            userId,
            CurrencyType.coins,
            100,
            'tournament_entry',
          )).called(1);
    });

    test(
        'insufficient funds throws InsufficientFundsException '
        'when spending more than balance', () async {
      // Start with 50 coins
      await service.earn(userId, CurrencyType.coins, 50, 'game_win');

      expect(
        () => service.spend(
          userId,
          CurrencyType.coins,
          100,
          'tournament_entry',
        ),
        throwsA(isA<InsufficientFundsException>()
            .having((e) => e.currency, 'currency', CurrencyType.coins)
            .having((e) => e.required, 'required', 100)
            .having((e) => e.available, 'available', 50)),
      );

      // Verify deductCurrency was never called
      verifyNever(
          () => mockRepo.deductCurrency(any(), any(), any(), any()));
    });

    test('full E2E flow: daily bonus → game win → tournament → verify balance',
        () async {
      // Step 1: Claim daily bonus (+200 coins)
      var balance = await service.earn(
        userId,
        CurrencyType.coins,
        200,
        'daily_bonus',
      );
      expect(balance.coins, 200);

      // Step 2: Win a game (+50 coins)
      balance = await service.earn(
        userId,
        CurrencyType.coins,
        50,
        'game_win',
      );
      expect(balance.coins, 250);

      // Step 3: Enter a tournament (-100 coins)
      balance = await service.spend(
        userId,
        CurrencyType.coins,
        100,
        'tournament_entry',
      );
      expect(balance.coins, 150);

      // Step 4: Verify final balance via getBalance
      final finalBalance = await service.getBalance(userId);
      expect(finalBalance.coins, 150);
      expect(finalBalance.gems, 0);

      // Verify transaction history
      verify(() => mockRepo.addCurrency(
            userId,
            CurrencyType.coins,
            200,
            'daily_bonus',
          )).called(1);
      verify(() => mockRepo.addCurrency(
            userId,
            CurrencyType.coins,
            50,
            'game_win',
          )).called(1);
      verify(() => mockRepo.deductCurrency(
            userId,
            CurrencyType.coins,
            100,
            'tournament_entry',
          )).called(1);
    });
  });
}
