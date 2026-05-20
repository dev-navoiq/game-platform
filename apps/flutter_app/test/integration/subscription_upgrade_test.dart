import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/subscription_service.dart';
import 'package:flutter_app/core/services/mock_revenue_cat.dart';
import 'package:flutter_app/core/models/subscription_tier.dart';

void main() {
  late MockRevenueCat mockRevenueCat;
  late SubscriptionService subscriptionService;

  setUp(() {
    mockRevenueCat = MockRevenueCat();
    subscriptionService = SubscriptionService(revenueCat: mockRevenueCat);
  });

  tearDown(() {
    mockRevenueCat.reset();
  });

  group('Subscription upgrade flow', () {
    test('default tier is free with ads', () async {
      final tier = await subscriptionService.getCurrentTier();

      expect(tier, equals(SubscriptionTier.free));
      expect(tier.hasAds, isTrue);
    });

    test('free tier has ads and limited voice (2 min)', () async {
      final tier = await subscriptionService.getCurrentTier();

      expect(tier, equals(SubscriptionTier.free));
      expect(tier.hasAds, isTrue);
      expect(tier.voiceMinutes, equals(2));
    });

    test('purchase pro → tier becomes pro', () async {
      final success = await subscriptionService
          .purchaseSubscription(SubscriptionTier.pro);
      expect(success, isTrue);

      final tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.pro));
    });

    test('pro tier has no ads', () async {
      await subscriptionService.purchaseSubscription(SubscriptionTier.pro);

      final tier = await subscriptionService.getCurrentTier();
      expect(tier.hasAds, isFalse);
    });

    test('pro tier has unlimited voice', () async {
      await subscriptionService.purchaseSubscription(SubscriptionTier.pro);

      final tier = await subscriptionService.getCurrentTier();
      expect(tier.voiceMinutes, isNull);
    });

    test('purchase max → tier becomes max', () async {
      final success = await subscriptionService
          .purchaseSubscription(SubscriptionTier.max);
      expect(success, isTrue);

      final tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.max));
    });

    test('cancel subscription → back to free with ads', () async {
      await subscriptionService.purchaseSubscription(SubscriptionTier.pro);
      var tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.pro));

      mockRevenueCat.simulateCancel('pro');

      tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.free));
      expect(tier.hasAds, isTrue);
    });

    test('full flow: free → pro → max → cancel → free', () async {
      // Start as free
      var tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.free));
      expect(tier.hasAds, isTrue);
      expect(tier.voiceMinutes, equals(2));
      expect(tier.monthlyCoins, equals(200));

      // Upgrade to pro
      var success = await subscriptionService
          .purchaseSubscription(SubscriptionTier.pro);
      expect(success, isTrue);

      tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.pro));
      expect(tier.hasAds, isFalse);
      expect(tier.voiceMinutes, isNull); // unlimited
      expect(tier.monthlyCoins, equals(800));

      // Upgrade to max
      success = await subscriptionService
          .purchaseSubscription(SubscriptionTier.max);
      expect(success, isTrue);

      tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.max));
      expect(tier.hasAds, isFalse);
      expect(tier.voiceMinutes, isNull); // unlimited
      expect(tier.monthlyCoins, equals(2500));

      // Cancel max → back to free
      mockRevenueCat.simulateCancel('max');

      tier = await subscriptionService.getCurrentTier();
      expect(tier, equals(SubscriptionTier.free));
      expect(tier.hasAds, isTrue);
      expect(tier.voiceMinutes, equals(2));
      expect(tier.monthlyCoins, equals(200));
    });
  });
}
