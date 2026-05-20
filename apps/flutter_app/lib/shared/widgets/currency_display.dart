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
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
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
            color: Colors.white.withOpacity(GlassTokens.surfaceOpacity),
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
