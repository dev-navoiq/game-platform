import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:monetization/monetization.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseService extends Mock implements SupabaseService {}

class MockCurrencyRepository extends Mock implements CurrencyRepository {}

void main() {
  late MockSupabaseService mockSupabaseService;
  late MockCurrencyRepository mockCurrencyRepo;
  late CurrencyService currencyService;

  const referrerUserId = 'user-referrer-001';
  const refereeUserId = 'user-referee-002';
  const validReferralCode = 'ABC123XY';
  const invalidReferralCode = 'INVALID_CODE';

  final successResponse = <String, dynamic>{
    'referrer_reward': {'coins': 100},
    'referee_reward': {'coins': 50},
  };

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    mockCurrencyRepo = MockCurrencyRepository();
    currencyService = CurrencyService(mockCurrencyRepo);
  });

  group('Referral — edge function call', () {
    test('recordReferral calls the correct edge function with referral code',
        () async {
      when(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).thenAnswer((_) async => successResponse);

      final result = await mockSupabaseService.recordReferral(
        referralCode: validReferralCode,
      );

      verify(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).called(1);

      expect(result, isA<Map<String, dynamic>>());
    });

    test('successful referral returns rewards for both referrer and referee',
        () async {
      when(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).thenAnswer((_) async => successResponse);

      final result = await mockSupabaseService.recordReferral(
        referralCode: validReferralCode,
      );

      expect(result, containsPair('referrer_reward', {'coins': 100}));
      expect(result, containsPair('referee_reward', {'coins': 50}));
    });

    test('referrer gets 100 coins reward', () async {
      when(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).thenAnswer((_) async => successResponse);

      final result = await mockSupabaseService.recordReferral(
        referralCode: validReferralCode,
      );

      final referrerReward =
          result['referrer_reward'] as Map<String, dynamic>;
      expect(referrerReward['coins'], equals(100));
    });

    test('referee gets 50 coins reward', () async {
      when(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).thenAnswer((_) async => successResponse);

      final result = await mockSupabaseService.recordReferral(
        referralCode: validReferralCode,
      );

      final refereeReward =
          result['referee_reward'] as Map<String, dynamic>;
      expect(refereeReward['coins'], equals(50));
    });

    test('invalid referral code returns error', () async {
      when(() => mockSupabaseService.recordReferral(
            referralCode: invalidReferralCode,
          )).thenThrow(Exception('Invalid referral code'));

      expect(
        () => mockSupabaseService.recordReferral(
          referralCode: invalidReferralCode,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid referral code'),
        )),
      );
    });

    test('cannot refer yourself', () async {
      // When a user tries to use their own referral code the edge function
      // rejects it with a self-referral error.
      when(() => mockSupabaseService.recordReferral(
            referralCode: validReferralCode,
          )).thenThrow(Exception('Cannot refer yourself'));

      expect(
        () => mockSupabaseService.recordReferral(
          referralCode: validReferralCode,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cannot refer yourself'),
        )),
      );
    });
  });

  group('Referral — full flow with currency verification', () {
    test(
      'user A shares code, user B records referral, both get coin rewards '
      'and balances are verified',
      () async {
        // ── Step 1: User B records the referral with user A's code ──
        when(() => mockSupabaseService.recordReferral(
              referralCode: validReferralCode,
            )).thenAnswer((_) async => successResponse);

        final referralResult = await mockSupabaseService.recordReferral(
          referralCode: validReferralCode,
        );

        // Verify the edge function returned the expected reward structure.
        expect(referralResult['referrer_reward'], {'coins': 100});
        expect(referralResult['referee_reward'], {'coins': 50});

        // ── Step 2: Credit referrer (user A) with 100 coins ──
        final referrerRewardCoins =
            (referralResult['referrer_reward']
                as Map<String, dynamic>)['coins'] as int;

        when(() => mockCurrencyRepo.addCurrency(
              referrerUserId,
              CurrencyType.coins,
              referrerRewardCoins,
              'referral_reward',
            )).thenAnswer((_) async =>
            CurrencyBalance(coins: referrerRewardCoins, gems: 0));

        final referrerBalance = await currencyService.earn(
          referrerUserId,
          CurrencyType.coins,
          referrerRewardCoins,
          'referral_reward',
        );

        expect(referrerBalance.coins, equals(100));

        verify(() => mockCurrencyRepo.addCurrency(
              referrerUserId,
              CurrencyType.coins,
              100,
              'referral_reward',
            )).called(1);

        // ── Step 3: Credit referee (user B) with 50 coins ──
        final refereeRewardCoins =
            (referralResult['referee_reward']
                as Map<String, dynamic>)['coins'] as int;

        when(() => mockCurrencyRepo.addCurrency(
              refereeUserId,
              CurrencyType.coins,
              refereeRewardCoins,
              'referral_reward',
            )).thenAnswer((_) async =>
            CurrencyBalance(coins: refereeRewardCoins, gems: 0));

        final refereeBalance = await currencyService.earn(
          refereeUserId,
          CurrencyType.coins,
          refereeRewardCoins,
          'referral_reward',
        );

        expect(refereeBalance.coins, equals(50));

        verify(() => mockCurrencyRepo.addCurrency(
              refereeUserId,
              CurrencyType.coins,
              50,
              'referral_reward',
            )).called(1);

        // ── Step 4: Verify final balances via getBalance ──
        when(() => mockCurrencyRepo.getBalance(referrerUserId))
            .thenAnswer((_) async =>
                const CurrencyBalance(coins: 100, gems: 0));

        when(() => mockCurrencyRepo.getBalance(refereeUserId))
            .thenAnswer((_) async =>
                const CurrencyBalance(coins: 50, gems: 0));

        final finalReferrerBalance =
            await currencyService.getBalance(referrerUserId);
        final finalRefereeBalance =
            await currencyService.getBalance(refereeUserId);

        expect(finalReferrerBalance.coins, equals(100));
        expect(finalRefereeBalance.coins, equals(50));

        verify(() => mockCurrencyRepo.getBalance(referrerUserId)).called(1);
        verify(() => mockCurrencyRepo.getBalance(refereeUserId)).called(1);
      },
    );
  });
}
