import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';
import 'glass_button.dart';

/// Glass modal prompting the user to watch a rewarded video ad.
///
/// Shows "Watch video → earn 30 coins" with a cooldown timer display.
class RewardedAdModal extends StatelessWidget {
  final int rewardCoins;
  final bool isOnCooldown;
  final int cooldownSeconds;
  final VoidCallback onWatch;
  final VoidCallback onSkip;

  const RewardedAdModal({
    super.key,
    this.rewardCoins = 30,
    this.isOnCooldown = false,
    this.cooldownSeconds = 0,
    required this.onWatch,
    required this.onSkip,
  });

  static Future<bool?> show({
    required BuildContext context,
    int rewardCoins = 30,
    bool isOnCooldown = false,
    int cooldownSeconds = 0,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => RewardedAdModal(
        rewardCoins: rewardCoins,
        isOnCooldown: isOnCooldown,
        cooldownSeconds: cooldownSeconds,
        onWatch: () => Navigator.of(context).pop(true),
        onSkip: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassTokens.radiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassTokens.blurHeavy,
            sigmaY: GlassTokens.blurHeavy,
          ),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GlassTokens.radiusLarge),
              color: Colors.white.withOpacity(GlassTokens.surfaceOpacity),
              border: Border.all(
                color: AppColors.glassBorder,
                width: GlassTokens.borderMedium,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GlassTokens.warning.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 36,
                    color: GlassTokens.warning,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Watch a Video',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Earn ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    Icon(Icons.circle, size: 14, color: GlassTokens.warning),
                    const SizedBox(width: 4),
                    Text(
                      '$rewardCoins coins',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (isOnCooldown) ...[
                  Text(
                    'Available in ${cooldownSeconds ~/ 60}m ${cooldownSeconds % 60}s',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassButton(
                    label: 'Close',
                    onPressed: onSkip,
                    variant: GlassButtonVariant.outlined,
                    width: double.infinity,
                  ),
                ] else ...[
                  GlassButton(
                    label: 'Watch Now',
                    onPressed: onWatch,
                    width: double.infinity,
                    icon: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                    label: 'No Thanks',
                    onPressed: onSkip,
                    variant: GlassButtonVariant.ghost,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
