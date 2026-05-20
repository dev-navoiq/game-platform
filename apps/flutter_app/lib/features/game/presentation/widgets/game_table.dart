import 'package:flutter/material.dart';

import '../../../../core/assets/room_skin_theme.dart';
import '../../../../core/theme/colors.dart';

/// Felt-textured game table background with radial gradient
/// and ambient gold glow at the bottom.
class GameTable extends StatelessWidget {
  final Widget child;
  final RoomSkinTheme? theme;

  const GameTable({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final feltMid = theme?.feltColor ?? AppColors.feltMid;
    final feltDark = theme?.feltDarkColor ?? AppColors.feltDark;

    return Container(
      key: const Key('game-table'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [feltMid, feltDark],
        ),
      ),
      child: Stack(
        children: [
          // Ambient gold glow at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 1.0,
                  colors: [
                    AppColors.accentGlow,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
