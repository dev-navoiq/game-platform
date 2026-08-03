import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// Glass pill showing coin + gem balances.
///
/// Used in HomeScreen app bar, ShopScreen, and ProfileScreen.
class CurrencyDisplay extends StatelessWidget {
  final int coins;
  final int gems;
  final bool compact;

  const CurrencyDisplay({
    super.key,
    required this.coins,
    required this.gems,
    this.compact = false,
  });

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    // Below 100K, show the exact number: "4.5K" swallowed ±100 swings —
    // an entire tournament entry fee was invisible on screen (#174).
    if (value >= 100000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 12.0 : 14.0;
    final iconSize = compact ? 14.0 : 16.0;
    final hPadding = compact ? 8.0 : 12.0;
    final vPadding = compact ? 4.0 : 6.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(GlassTokens.radiusRound),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: vPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GlassTokens.radiusRound),
            color: AppColors.glass.withValues(
              alpha: GlassTokens.surfaceOpacity,
            ),
            border: Border.all(
              color: AppColors.glassBorder,
              width: GlassTokens.borderThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coins
              Icon(Icons.circle, size: iconSize, color: GlassTokens.warning),
              const SizedBox(width: 4),
              Text(
                _formatCount(coins),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              // Gems
              Icon(Icons.diamond, size: iconSize, color: GlassTokens.info),
              const SizedBox(width: 4),
              Text(
                _formatCount(gems),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
