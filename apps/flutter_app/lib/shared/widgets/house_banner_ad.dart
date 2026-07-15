import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/house_ads/house_ad_creative.dart';
import '../../core/theme/colors.dart';

/// A house creative rendered in the standard banner slot (320×50-ish glass
/// card): emoji/icon art, headline, ad label, CTA chevron. Tapping navigates
/// to the creative's route (if any) unless [onTap] overrides it.
///
/// Used by `BannerAdWidget` when the ad mode is `house`, and by the
/// `/dev/ads` gallery for previews.
class HouseBannerAd extends StatelessWidget {
  final HouseAdCreative creative;
  final VoidCallback? onTap;

  const HouseBannerAd({super.key, required this.creative, this.onTap});

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    final route = creative.route;
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final accent = creative.accentColor;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.10),
              accent.withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            // Art: emoji (or icon) in an accent-tinted circle.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: creative.emoji != null
                  ? Text(creative.emoji!, style: const TextStyle(fontSize: 18))
                  : Icon(creative.icon ?? Icons.campaign,
                      size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            // Headline + ad label.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creative.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnFelt,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    creative.adLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.3,
                      color: AppColors.textFeltMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // CTA chip with chevron.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: accent.withValues(alpha: 0.22),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    creative.ctaLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(accent, Colors.white, 0.35),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 14, color: Color.lerp(accent, Colors.white, 0.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
