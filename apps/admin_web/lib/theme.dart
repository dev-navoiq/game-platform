import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Refined Crystal" — felt green + gold accent, matching the consumer app.
class AppColors {
  static const felt = Color(0xFF122E1D);
  static const feltDark = Color(0xFF0C1F14);
  static const feltLight = Color(0xFF1B4029);
  static const gold = Color(0xFFC47B2B);
  static const goldLight = Color(0xFFE0A45A);
  static const surface = Color(0xFF16351F);
  static const danger = Color(0xFFC0453B);
  static const success = Color(0xFF4CAF7D);
  static const textPrimary = Color(0xFFF3EFE6);
  static const textMuted = Color(0xFF9DB0A2);
}

ThemeData buildAdminTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.feltDark,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.gold,
      secondary: AppColors.goldLight,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: textTheme.copyWith(
      titleLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.felt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.feltDark,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
