import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Glass morphism design tokens.
///
/// Colours reference [AppColors] to stay consistent with the project palette.
/// This class provides blur intensities, opacities, radii, and animation
/// durations used by all glass-style widgets.
class GlassTokens {
  GlassTokens._();

  // ── Blur intensities ──────────────────────────────────────────
  static const double blurLight = 10.0;
  static const double blurDefault = 18.0; // matches _context.md glass recipe
  static const double blurMedium = 20.0;
  static const double blurHeavy = 40.0;

  // ── Surface opacities ─────────────────────────────────────────
  static const double surfaceOpacity = 0.52; // standard glass
  static const double surfaceOpacityHover = 0.60;
  static const double surfaceOpacityPressed = 0.68;
  static const double borderOpacity = 0.72; // standard glass border

  // ── Border widths ─────────────────────────────────────────────
  static const double borderThin = 0.5;
  static const double borderMedium = 1.0;
  static const double borderThick = 1.5;

  // ── Glow ──────────────────────────────────────────────────────
  static const double glowRadius = 20.0;
  static const double glowIntensity = 0.5;

  // ── Border radius ─────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;
  static const double radiusRound = 999.0;

  // ── Animation durations ───────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ── Colours (delegated to AppColors) ──────────────────────────

  // Surface
  static const Color surface = AppColors.glass; // white 52%
  static const Color surfaceBorder = AppColors.glassBorder; // white 72%

  // Text on glass
  static const Color textOnGlass = AppColors.textDark; // #241810
  static const Color textOnGlassMuted = AppColors.textMuted; // #9c7d62

  // Text on felt
  static const Color textOnFelt = AppColors.textOnFelt; // white 90%
  static const Color textOnFeltMuted = AppColors.textFeltMuted; // white 50%

  // Accent
  static const Color accentPrimary = AppColors.accent; // #C47B2B
  static const Color accentSoft = AppColors.accentSoft; // #E8A84F
  static const Color accentGlow = AppColors.accentGlow; // gold 22%

  // Dark-mode surface
  static const Color darkSurface = AppColors.feltDark; // #122e1d

  // Status (supplementary)
  static const Color success = AppColors.success; // #27ae60
  static const Color danger = AppColors.danger; // #e74c3c
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info = Color(0xFF3B82F6); // Blue

  // ── Standard box shadow for glass panels ──────────────────────
  static const BoxShadow glassShadow = BoxShadow(
    color: Color(0x1A3C2814),
    blurRadius: 20,
    offset: Offset(0, 4),
  );

  static const BoxShadow glassInnerHighlight = BoxShadow(
    color: Color(0x8CFFFFFF), // 55% white inset
    blurRadius: 3,
    offset: Offset(0, 1),
  );
}
