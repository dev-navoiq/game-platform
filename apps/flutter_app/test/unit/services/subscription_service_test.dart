import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/core/services/subscription_service.dart';
import 'package:flutter_app/core/models/subscription_tier.dart';

class MockRevenueCat extends Mock implements RevenueCatWrapper {}

void main() {
  late MockRevenueCat mockRevenueCat;
  late SubscriptionService service;

  setUp(() {
    mockRevenueCat = MockRevenueCat();
    service = SubscriptionService(revenueCat: mockRevenueCat);
  });

  group('SubscriptionService', () {
    group('Tier resolution', () {
      test('free user has SubscriptionTier.free', () async {
        when(() => mockRevenueCat.getActiveEntitlements())
            .thenAnswer((_) async => []);

        final tier = await service.getCurrentTier();
        expect(tier, SubscriptionTier.free);
      });

      test('pro entitlement resolves to SubscriptionTier.pro', () async {
        when(() => mockRevenueCat.getActiveEntitlements())
            .thenAnswer((_) async => ['pro']);

        final tier = await service.getCurrentTier();
        expect(tier, SubscriptionTier.pro);
      });

      test('max entitlement resolves to SubscriptionTier.max', () async {
        when(() => mockRevenueCat.getActiveEntitlements())
            .thenAnswer((_) async => ['max']);

        final tier = await service.getCurrentTier();
        expect(tier, SubscriptionTier.max);
      });
    });

    group('Tier pricing', () {
      test('free tier has price \$0', () {
        expect(SubscriptionTier.free.monthlyPrice, 0.0);
      });

      test('pro tier has price \$3.99', () {
        expect(SubscriptionTier.pro.monthlyPrice, 3.99);
      });

      test('max tier has price \$7.99', () {
        expect(SubscriptionTier.max.monthlyPrice, 7.99);
      });
    });

    group('Tier benefits', () {
      test('free tier has ad support', () {
        expect(SubscriptionTier.free.hasAds, isTrue);
      });

      test('pro tier has no ads', () {
        expect(SubscriptionTier.pro.hasAds, isFalse);
      });

      test('max tier has no ads', () {
        expect(SubscriptionTier.max.hasAds, isFalse);
      });

      test('free tier voice is timed (2-min teaser)', () {
        expect(SubscriptionTier.free.voiceMinutes, 2);
      });

      test('pro tier has unlimited voice', () {
        expect(SubscriptionTier.pro.voiceMinutes, isNull); // null = unlimited
      });

      test('free tier gets 200 coins/month', () {
        expect(SubscriptionTier.free.monthlyCoins, 200);
      });
    });

    group('purchaseSubscription', () {
      test('calls revenueCat purchase and returns true on success', () async {
        when(() => mockRevenueCat.purchase(productId: any(named: 'productId')))
            .thenAnswer((_) async => true);

        final result = await service.purchaseSubscription(SubscriptionTier.pro);
        expect(result, isTrue);
      });

      test('returns false when purchase is cancelled', () async {
        when(() => mockRevenueCat.purchase(productId: any(named: 'productId')))
            .thenAnswer((_) async => false);

        final result = await service.purchaseSubscription(SubscriptionTier.pro);
        expect(result, isFalse);
      });
    });
  });
}
