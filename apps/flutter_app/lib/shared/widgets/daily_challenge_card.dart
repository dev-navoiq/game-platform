import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';
import 'glass_card.dart';

/// Displays a single daily/weekly challenge with progress bar and rewards.
///
/// States:
/// - **Active**: progress bar filling toward [target]
/// - **Completed**: green checkmark, full bar
/// - **Expired**: greyed out (caller can wrap in Opacity)
class DailyChallengeCard extends StatelessWidget {
  final String title;
  final int current;
  final int target;
  final int rewardCoins;
  final int? rewardGems;
  final bool isCompleted;
  final VoidCallback? onReroll;
  final int? rerollCost;

  const DailyChallengeCard({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    this.rewardCoins = 0,
    this.rewardGems,
    this.isCompleted = false,
    this.onReroll,
    this.rerollCost,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Row(
            children: [
              if (isCompleted)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (onReroll != null && !isCompleted)
                GestureDetector(
                  onTap: onReroll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: AppColors.textMuted),
                      if (rerollCost != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          '$rerollCost',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.textMuted.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(
                  isCompleted ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Progress text + rewards
          Row(
            children: [
              Text(
                isCompleted ? 'Complete!' : '$current / $target',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? AppColors.success : AppColors.textMuted,
                ),
              ),
              const Spacer(),
              // Coin reward
              if (rewardCoins > 0) ...[
                Icon(Icons.circle, size: 10, color: GlassTokens.warning),
                const SizedBox(width: 3),
                Text(
                  '$rewardCoins',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
              // Gem reward
              if (rewardGems != null && rewardGems! > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.diamond, size: 10, color: GlassTokens.info),
                const SizedBox(width: 3),
                Text(
                  '${rewardGems!}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
