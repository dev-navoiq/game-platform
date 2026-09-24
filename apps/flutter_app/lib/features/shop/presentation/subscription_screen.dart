import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/monetization_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/services/native_purchase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/under_construction_banner.dart';
import 'web_checkout.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTier = ref.watch(currentTierProvider);
    final nativeService = ref.watch(nativePurchaseServiceProvider);
    // Web subscribes via Stripe; native needs a configured RevenueCat build.
    final purchasesAvailable = kIsWeb || (nativeService?.isEnabled ?? false);

    return FeltBackground(
      showAmbientGlow: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Choose Your Plan'),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 40,
          ),
          children: [
            if (!purchasesAvailable)
              const UnderConstructionBanner(
                message:
                    'Subscriptions are not enabled in this build — the store is not configured yet.',
              ),
            Text(
              'Unlock the full experience',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textOnFelt,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Free tier
            _TierCard(
              tierName: 'Free',
              price: '\$0',
              period: 'forever',
              isCurrentTier: currentTier == SubscriptionTier.free,
              features: const [
                'Play all 7 games',
                'Basic matchmaking',
                '200 daily coins',
                'Ads between games',
                '20 friends max',
              ],
              onSubscribe: null,
            ),
            const SizedBox(height: 12),

            // Pro tier
            _TierCard(
              tierName: 'Pro',
              price: '\$3.99',
              period: '/month',
              isRecommended: true,
              isCurrentTier: currentTier == SubscriptionTier.pro,
              accentColor: AppColors.accent,
              features: const [
                'No ads',
                '800 daily coins',
                '3 challenge re-rolls/day',
                '100 friends',
                'Exclusive card skins',
                'Priority matchmaking',
              ],
              onSubscribe: currentTier == SubscriptionTier.pro
                  ? null
                  : () => _subscribe(context, ref, SubscriptionTier.pro),
            ),
            const SizedBox(height: 12),

            // Max tier
            _TierCard(
              tierName: 'Max',
              price: '\$7.99',
              period: '/month',
              isCurrentTier: currentTier == SubscriptionTier.max,
              accentColor: AppColors.primaryLight,
              features: const [
                'Everything in Pro',
                '2,500 daily coins',
                'Unlimited re-rolls',
                '500 friends',
                'Premium Season Pass',
                'Tournament priority entry',
                'Custom room themes',
              ],
              onSubscribe: currentTier == SubscriptionTier.max
                  ? null
                  : () => _subscribe(context, ref, SubscriptionTier.max),
            ),
            const SizedBox(height: 24),

            // Restore purchases (store accounts only — Stripe has no equivalent)
            if (!kIsWeb)
              Center(
                child: GlassButton(
                  label: 'Restore Purchases',
                  onPressed: () => _restore(context, ref),
                  variant: GlassButtonVariant.ghost,
                  color: AppColors.textOnFelt,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(
    BuildContext context,
    WidgetRef ref,
    SubscriptionTier tier,
  ) async {
    final productKey = NativePurchaseService.subscriptionProductKey(tier.name);
    if (kIsWeb) {
      await startStripeCheckout(context, ref, productKey);
      return;
    }
    await _runNative(
      context,
      ref,
      (service) => service.purchase(productKey),
      successMessage: '🎉 Welcome to ${tier.name[0].toUpperCase()}${tier.name.substring(1)}!',
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await _runNative(
      context,
      ref,
      (service) => service.restore(),
      successMessage: '✅ Purchases restored',
    );
  }

  Future<void> _runNative(
    BuildContext context,
    WidgetRef ref,
    Future<NativePurchaseOutcome> Function(NativePurchaseService) action, {
    required String successMessage,
  }) async {
    final service = ref.read(nativePurchaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (service == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('In-app purchases are not available on this platform.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final outcome = await action(service);

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    // Tier + monthly grant are applied server-side; refetch the profile row.
    ref.invalidate(userProfileProvider);

    if (outcome.isCancelled) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome.isSuccess ? successMessage : '❌ ${outcome.message ?? 'Something went wrong'}',
        ),
        backgroundColor: outcome.isSuccess ? Colors.green : Colors.red,
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String tierName;
  final String price;
  final String period;
  final bool isCurrentTier;
  final bool isRecommended;
  final Color? accentColor;
  final List<String> features;
  final VoidCallback? onSubscribe;

  const _TierCard({
    required this.tierName,
    required this.price,
    required this.period,
    this.isCurrentTier = false,
    this.isRecommended = false,
    this.accentColor,
    required this.features,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.textMuted;

    return GlassCard(
      enableGlow: isRecommended,
      glowColor: color,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                tierName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (isRecommended) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: color.withOpacity(0.15),
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
              if (isCurrentTier) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.success.withOpacity(0.15),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Features
          for (final feature in features) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (onSubscribe != null) ...[
            const SizedBox(height: 12),
            GlassButton(
              label: 'Subscribe',
              onPressed: onSubscribe,
              width: double.infinity,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}
