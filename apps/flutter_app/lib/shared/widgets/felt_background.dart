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

  /// Optional sponsor name rendered as a faint "Table presented by …" line at
  /// the bottom of the felt, under the content. For sponsorship deals on card
  /// tables — no image assets, matches the drawn-branding approach used by the
  /// Ludo sponsor skins (see `ludo_sponsor_branding.dart`).
  ///
  /// Example usage (not wired anywhere yet — a card-game sponsorship would
  /// pass the active deal's name where the table is built):
  /// ```dart
  /// // FeltBackground(
  /// //   sponsorWatermark: 'Bolt Cola',   // fictional example sponsor
  /// //   child: GameTable(...),
  /// // )
  /// ```
  final String? sponsorWatermark;

  const FeltBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = false,
    this.theme,
    this.sponsorWatermark,
  });

  @override
  Widget build(BuildContext context) {
    final feltMid = theme?.feltColor ?? AppColors.feltMid;
    final feltDark = theme?.feltDarkColor ?? AppColors.feltDark;

    // Watermark sits between the felt and the content, so translucent glass
    // panels above still let it read faintly through.
    final content = sponsorWatermark == null
        ? child
        : Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: IgnorePointer(
                  child: Text(
                    'Table presented by $sponsorWatermark',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
              child,
            ],
          );

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
                content,
              ],
            )
          : content,
    );
  }
}
