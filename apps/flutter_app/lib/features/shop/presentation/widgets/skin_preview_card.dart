import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_button.dart';

/// A glass-styled card showing a skin preview with purchase option.
class SkinPreviewCard extends StatelessWidget {
  final String name;
  final String type;
  final int? priceCoins;
  final int? priceGems;
  final bool isOwned;
  final bool isEquipped;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;

  const SkinPreviewCard({
    super.key,
    required this.name,
    required this.type,
    this.priceCoins,
    this.priceGems,
    this.isOwned = false,
    this.isEquipped = false,
    this.onBuy,
    this.onEquip,
  });

  IconData get _typeIcon {
    switch (type) {
      case 'cardDeck':
        return Icons.style;
      case 'roomBackground':
        return Icons.wallpaper;
      case 'avatarFrame':
        return Icons.face;
      case 'emotePack':
        return Icons.emoji_emotions;
      default:
        return Icons.palette;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Preview placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.accent.withOpacity(0.1),
            ),
            child: Icon(_typeIcon, size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (isEquipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.success.withOpacity(0.15),
              ),
              child: const Text(
                'Equipped',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            )
          else if (isOwned)
            GlassButton(
              label: 'Equip',
              onPressed: onEquip,
              size: GlassButtonSize.small,
              variant: GlassButtonVariant.outlined,
            )
          else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (priceCoins != null) ...[
                  Icon(Icons.circle, size: 10, color: GlassTokens.warning),
                  const SizedBox(width: 2),
                  Text(
                    '$priceCoins',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
                if (priceCoins != null && priceGems != null)
                  const SizedBox(width: 6),
                if (priceGems != null) ...[
                  Icon(Icons.diamond, size: 10, color: GlassTokens.info),
                  const SizedBox(width: 2),
                  Text(
                    '$priceGems',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
