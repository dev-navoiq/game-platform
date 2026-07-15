import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Visual identity for a game on the home grid / favorites strips.
class GameVisual {
  final String gameType;
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final Color accentColor;
  final String? imageAsset;

  const GameVisual({
    required this.gameType,
    required this.title,
    required this.subtitle,
    required this.fallbackIcon,
    required this.accentColor,
    this.imageAsset,
  });
}

/// Central catalog of per-game art, accents, and fallback icons.
class GameVisuals {
  GameVisuals._();

  static const _assetRoot = 'assets/icons/games';

  static const Map<String, GameVisual> _byType = {
    'twenty_nine': GameVisual(
      gameType: 'twenty_nine',
      title: 'Twenty-Nine',
      subtitle: '4 players',
      fallbackIcon: Icons.style,
      accentColor: AppColors.accent,
      imageAsset: '$_assetRoot/twenty_nine.jpg',
    ),
    'oh_hell': GameVisual(
      gameType: 'oh_hell',
      title: 'Oh Hell',
      subtitle: '3-7 players',
      fallbackIcon: Icons.whatshot,
      accentColor: Color(0xFFE85D04),
      imageAsset: '$_assetRoot/oh_hell.jpg',
    ),
    'hearts': GameVisual(
      gameType: 'hearts',
      title: 'Hearts',
      subtitle: '4 players',
      fallbackIcon: Icons.favorite,
      accentColor: Color(0xFFE11D48),
      imageAsset: '$_assetRoot/hearts.jpg',
    ),
    'spades': GameVisual(
      gameType: 'spades',
      title: 'Spades',
      subtitle: '4 players',
      fallbackIcon: Icons.eco,
      accentColor: Color(0xFF334155),
      imageAsset: '$_assetRoot/spades.jpg',
    ),
    'bridge': GameVisual(
      gameType: 'bridge',
      title: 'Bridge',
      subtitle: '4 players',
      fallbackIcon: Icons.dashboard,
      accentColor: AppColors.accentSoft,
      imageAsset: '$_assetRoot/bridge.jpg',
    ),
    'chess': GameVisual(
      gameType: 'chess',
      title: 'Chess',
      subtitle: '2 players',
      fallbackIcon: Icons.castle,
      accentColor: AppColors.primaryDark,
    ),
    'ludo': GameVisual(
      gameType: 'ludo',
      title: 'Ludo',
      subtitle: '2-4 players',
      fallbackIcon: Icons.grid_view,
      accentColor: Color(0xFF16A34A),
      imageAsset: '$_assetRoot/ludo.jpg',
    ),
    'sequence': GameVisual(
      gameType: 'sequence',
      title: 'Sequence',
      subtitle: '2-4 players',
      fallbackIcon: Icons.apps,
      accentColor: Color(0xFF0891B2),
      imageAsset: '$_assetRoot/sequence.jpg',
    ),
  };

  static GameVisual of(String gameType) {
    return _byType[gameType] ??
        GameVisual(
          gameType: gameType,
          title: gameType,
          subtitle: '',
          fallbackIcon: Icons.games,
          accentColor: AppColors.accent,
        );
  }

  static List<String> get homeGridOrder => const [
        'twenty_nine',
        'oh_hell',
        'hearts',
        'spades',
        'bridge',
        'ludo',
        'sequence',
      ];
}
