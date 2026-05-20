import 'package:flutter/material.dart';

/// Defines the visual theme for the room / table background.
///
/// Each skin changes the felt gradient and accent colour.
/// No image assets required — colours only.
@immutable
class RoomSkinTheme {
  final String id;
  final String displayName;
  final Color feltColor;
  final Color feltDarkColor;
  final Color accentColor;
  final double glassOpacity;
  final int priceCoins;
  final int priceGems;
  final bool isDefault;

  const RoomSkinTheme({
    required this.id,
    required this.displayName,
    required this.feltColor,
    required this.feltDarkColor,
    required this.accentColor,
    this.glassOpacity = 0.52,
    this.priceCoins = 0,
    this.priceGems = 0,
    this.isDefault = false,
  });

  bool get isFree => priceCoins == 0 && priceGems == 0;

  // ── Presets ──────────────────────────────────────────────────────────────

  /// Current felt green with gold accent.
  static const classic = RoomSkinTheme(
    id: 'classic',
    displayName: 'Classic',
    feltColor: Color(0xFF1e5631),
    feltDarkColor: Color(0xFF122e1d),
    accentColor: Color(0xFFC47B2B),
    isDefault: true,
  );

  /// Deep red casino felt with gold accent.
  static const casino = RoomSkinTheme(
    id: 'casino',
    displayName: 'Casino',
    feltColor: Color(0xFF5c1a1a),
    feltDarkColor: Color(0xFF2d0f0f),
    accentColor: Color(0xFFC47B2B),
    priceCoins: 3000,
  );

  /// Forest green with emerald accent.
  static const nature = RoomSkinTheme(
    id: 'nature',
    displayName: 'Nature',
    feltColor: Color(0xFF2d5a1e),
    feltDarkColor: Color(0xFF1a3a10),
    accentColor: Color(0xFF27ae60),
    priceCoins: 3000,
  );

  /// Deep blue space with cyan accent.
  static const space = RoomSkinTheme(
    id: 'space',
    displayName: 'Space',
    feltColor: Color(0xFF0a1628),
    feltDarkColor: Color(0xFF050d1a),
    accentColor: Color(0xFF00E5FF),
    glassOpacity: 0.45,
    priceGems: 300,
  );
}
