import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_button.dart';

/// A glass-styled card for purchasing a gem pack.
class GemPackCard extends StatelessWidget {
  final String name;
  final int gems;
  final int bonusGems;
  final double priceUsd;
  final bool isPopular;
  final VoidCallback? onBuy;

  const GemPackCard({
    super.key,
    required this.name,
    required this.gems,
    this.bonusGems = 0,
    required this.priceUsd,
    this.isPopular = false,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableGlow: isPopular,
      glowColor: GlassTokens.info,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: GlassTokens.info.withOpacity(0.15),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: GlassTokens.info,
                ),
              ),
            ),
          // Gem icon
          Icon(Icons.diamond, size: 32, color: GlassTokens.info),
          const SizedBox(height: 8),
          // Gem count
          Text(
            '$gems',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          if (bonusGems > 0) ...[
            Text(
              '+$bonusGems bonus',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: '\$${priceUsd.toStringAsFixed(2)}',
            onPressed: onBuy,
            size: GlassButtonSize.small,
            color: GlassTokens.info,
          ),
        ],
      ),
    );
  }
}
