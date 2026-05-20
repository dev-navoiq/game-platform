import 'package:flutter/material.dart';

import '../../core/assets/room_skin_theme.dart';
import '../../core/theme/colors.dart';

/// Felt-textured background with radial gradient.
///
/// Extracted from [GameTable] for reuse across non-game screens
/// (login, home, lobby, room, shop, etc.).
class FeltBackground extends StatelessWidget {
  final Widget child;
  final bool showAmbientGlow;
  final RoomSkinTheme? theme;

  const FeltBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = false,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final feltMid = theme?.feltColor ?? AppColors.feltMid;
    final feltDark = theme?.feltDarkColor ?? AppColors.feltDark;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [feltMid, feltDark],
        ),
      ),
      child: showAmbientGlow
          ? Stack(
              children: [
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
            )
          : child,
    );
  }
}
