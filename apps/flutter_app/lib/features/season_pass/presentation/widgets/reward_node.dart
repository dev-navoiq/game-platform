import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';

/// A single reward node in the season pass track.
class RewardNode extends StatelessWidget {
  final int level;
  final String label;
  final int? coins;
  final int? gems;
  final bool isPremium;
  final bool isUnlocked;
  final bool isCurrent;

  const RewardNode({
    super.key,
    required this.level,
    required this.label,
    this.coins,
    this.gems,
    this.isPremium = false,
    this.isUnlocked = false,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPremium ? AppColors.accent : AppColors.success;
    final bgOpacity = isUnlocked ? 0.2 : 0.08;

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(bgOpacity),
        border: Border.all(
          color: isCurrent
              ? color
              : isUnlocked
                  ? color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level badge
          Text(
            'Lv $level',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUnlocked ? color : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          // Reward icon
          Icon(
            isUnlocked ? Icons.lock_open : Icons.lock,
            size: 18,
            color: isUnlocked ? color : AppColors.textMuted.withOpacity(0.4),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isUnlocked ? AppColors.textDark : AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Reward amount
          if (coins != null || gems != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coins != null) ...[
                  Icon(Icons.circle, size: 8, color: GlassTokens.warning),
                  const SizedBox(width: 2),
                  Text(
                    '$coins',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked
                          ? AppColors.textDark
                          : AppColors.textMuted,
                    ),
                  ),
                ],
                if (gems != null) ...[
                  if (coins != null) const SizedBox(width: 4),
                  Icon(Icons.diamond, size: 8, color: GlassTokens.info),
                  const SizedBox(width: 2),
                  Text(
                    '$gems',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked
                          ? AppColors.textDark
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          if (isPremium) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AppColors.accent.withOpacity(0.2),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
