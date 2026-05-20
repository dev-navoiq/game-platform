import 'package:flutter/material.dart';

/// Defines the visual theme for playing cards.
///
/// Each skin changes card face/back colours — card rendering remains
/// programmatic (Unicode symbols), no image assets required.
@immutable
class CardSkinTheme {
  final String id;
  final String displayName;
  final Color redSuitColor;
  final Color blackSuitColor;
  final Color cardFaceColor;
  final Color cardBorderColor;
  final LinearGradient cardBackGradient;
  final int priceCoins;
  final int priceGems;
  final bool isDefault;

  const CardSkinTheme({
    required this.id,
    required this.displayName,
    required this.redSuitColor,
    required this.blackSuitColor,
    required this.cardFaceColor,
    required this.cardBorderColor,
    required this.cardBackGradient,
    this.priceCoins = 0,
    this.priceGems = 0,
    this.isDefault = false,
  });

  bool get isFree => priceCoins == 0 && priceGems == 0;

  // ── Presets ──────────────────────────────────────────────────────────────

  /// White face, red/black suits, blue gradient back.
  static const classic = CardSkinTheme(
    id: 'classic',
    displayName: 'Classic',
    redSuitColor: Color(0xFFc0392b),
    blackSuitColor: Color(0xFF1a1a2a),
    cardFaceColor: Color(0xFFFFFFFF),
    cardBorderColor: Color(0xFFE0E0E0),
    cardBackGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1a237e), Color(0xFF283593)],
    ),
    isDefault: true,
  );

  /// Light grey face, crimson/navy suits, dark gradient back.
  static const modern = CardSkinTheme(
    id: 'modern',
    displayName: 'Modern',
    redSuitColor: Color(0xFFDC143C),
    blackSuitColor: Color(0xFF1B2A4A),
    cardFaceColor: Color(0xFFF5F5F5),
    cardBorderColor: Color(0xFFBDBDBD),
    cardBackGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
    ),
    priceCoins: 2000,
  );

  /// Dark face, neon pink/cyan suits, neon gradient back.
  static const neon = CardSkinTheme(
    id: 'neon',
    displayName: 'Neon',
    redSuitColor: Color(0xFFFF007F),
    blackSuitColor: Color(0xFF00E5FF),
    cardFaceColor: Color(0xFF1a1a2e),
    cardBorderColor: Color(0xFF3D3D5C),
    cardBackGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6A0DAD), Color(0xFF00E5FF)],
    ),
    priceGems: 200,
  );

  /// Cream face, burgundy/dark brown suits, gold gradient back.
  static const gold = CardSkinTheme(
    id: 'gold',
    displayName: 'Gold',
    redSuitColor: Color(0xFF800020),
    blackSuitColor: Color(0xFF3E2723),
    cardFaceColor: Color(0xFFFAF3E0),
    cardBorderColor: Color(0xFFD4A574),
    cardBackGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC47B2B), Color(0xFFE8A84F)],
    ),
    priceGems: 400,
  );
}
