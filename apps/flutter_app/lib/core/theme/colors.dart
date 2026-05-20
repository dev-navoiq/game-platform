import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Felt surface (game table background)
  static const feltDark = Color(0xFF122e1d);
  static const feltMid = Color(0xFF1d4a2e);
  static const feltLight = Color(0xFF2a6641);

  // Gold accent
  static const accent = Color(0xFFC47B2B);
  static const accentSoft = Color(0xFFE8A84F);
  static const accentGlow = Color(0x38C47B2B); // 22% opacity

  // Glass morphism
  static const glass = Color(0x85FFFFFF); // 52% opacity
  static const glassBorder = Color(0xB8FFFFFF); // 72% opacity

  // Text on glass
  static const textDark = Color(0xFF241810);
  static const textMuted = Color(0xFF9c7d62);

  // Text on felt
  static const textOnFelt = Color(0xE6FFFFFF); // 90% opacity
  static const textFeltMuted = Color(0x80FFFFFF); // 50% opacity

  // Status
  static const success = Color(0xFF27ae60);
  static const danger = Color(0xFFe74c3c);

  // Cards
  static const cardBg = Color(0xFFFFFFFF);
  static const cardRed = Color(0xFFc0392b);
  static const cardBlack = Color(0xFF1a1a2a);

  // Primary palette (for Material theme)
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4F46E5);

  // Secondary
  static const secondary = Color(0xFF22D3EE);
  static const secondaryLight = Color(0xFF67E8F9);
  static const secondaryDark = Color(0xFF06B6D4);

  // Neutral (light)
  static const surfaceLight = Color(0xFFF8FAFC);
  static const backgroundLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1E293B);
  static const textSecondaryLight = Color(0xFF64748B);

  // Neutral (dark)
  static const surfaceDark = Color(0xFF1E1E2E);
  static const backgroundDark = Color(0xFF11111B);
  static const cardDark = Color(0xFF282839);
  static const textPrimaryDark = Color(0xFFF1F5F9);
  static const textSecondaryDark = Color(0xFF94A3B8);

  // Avatar
  static const avatarBg1 = Color(0xFFF0E8DA);
  static const avatarBg2 = Color(0xFFE5D4BC);

  // Player colours
  static const player1 = Color(0xFFEF4444);
  static const player2 = Color(0xFF3B82F6);
  static const player3 = Color(0xFF22C55E);
  static const player4 = Color(0xFFF59E0B);

  static Color playerColor(int index) {
    const colors = [player1, player2, player3, player4];
    return colors[index % colors.length];
  }
}
