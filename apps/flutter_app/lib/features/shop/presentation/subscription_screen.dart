import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/theme/glass_tokens.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/under_construction_banner.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const UnderConstructionBanner(
              message:
                  'Subscriptions are under construction — the Subscribe and Restore buttons below do not yet contact RevenueCat.',
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
              isCurrentTier: true,
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
              accentColor: AppColors.accent,
              features: const [
                'No ads',
                '800 daily coins',
                '3 challenge re-rolls/day',
                '100 friends',
                'Exclusive card skins',
                'Priority matchmaking',
              ],
              onSubscribe: () {
                // TODO: RevenueCat purchase
              },
            ),
            const SizedBox(height: 12),

            // Max tier
            _TierCard(
              tierName: 'Max',
              price: '\$7.99',
              period: '/month',
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
              onSubscribe: () {
                // TODO: RevenueCat purchase
              },
            ),
            const SizedBox(height: 24),

            // Restore purchases
            Center(
              child: GlassButton(
                label: 'Restore Purchases',
                onPressed: () {
                  // TODO: RevenuCat restore
                },
                variant: GlassButtonVariant.ghost,
                color: AppColors.textOnFelt,
              ),
            ),
          ],
        ),
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
