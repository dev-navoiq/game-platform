import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';
import 'glass_container.dart';

/// Displays season pass level progression with a horizontal progress bar
/// and dual-track visual indicators (free + premium).
class SeasonPassProgressBar extends StatelessWidget {
  final int currentLevel;
  final int currentXp;
  final int xpToNextLevel;
  final bool isPremium;
  final int maxLevel;

  const SeasonPassProgressBar({
    super.key,
    required this.currentLevel,
    required this.currentXp,
    required this.xpToNextLevel,
    this.isPremium = false,
    this.maxLevel = 50,
  });

  @override
  Widget build(BuildContext context) {
    final xpProgress =
        xpToNextLevel > 0 ? (currentXp / xpToNextLevel).clamp(0.0, 1.0) : 0.0;
    final levelProgress =
        maxLevel > 0 ? (currentLevel / maxLevel).clamp(0.0, 1.0) : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: GlassTokens.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Season Pass',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              if (isPremium)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSoft],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                'Lv $currentLevel / $maxLevel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Level progress bar
          Stack(
            children: [
              // Track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: levelProgress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPremium
                          ? [AppColors.accent, AppColors.accentSoft]
                          : [AppColors.success, AppColors.success],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // XP within current level
          Row(
            children: [
              Text(
                'XP: $currentXp / $xpToNextLevel',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              // Mini XP bar
              SizedBox(
                width: 80,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    backgroundColor:
                        AppColors.textMuted.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
            ],
          ),

          // Dual track labels
          if (isPremium) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _TrackLabel(
                  label: 'Free',
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _TrackLabel(
                  label: 'Premium',
                  color: AppColors.accent,
                  isPremium: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPremium;

  const _TrackLabel({
    required this.label,
    required this.color,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isPremium
                ? Border.all(color: AppColors.accent, width: 1)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
