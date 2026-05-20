import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// Placeholder banner ad widget for free tier users.
///
/// Hidden for Pro/Max subscribers. Replace with real ad SDK integration.
class BannerAdWidget extends StatelessWidget {
  final bool isVisible;

  const BannerAdWidget({super.key, this.isVisible = true});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ad_units, size: 18, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              'Ad Placeholder',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
