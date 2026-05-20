import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/social_mode_indicator.dart';

/// Top HUD bar for the game screen.
///
/// Shows game name, round info, social mode indicator, and menu button.
class GameHud extends StatelessWidget {
  final String gameName;
  final int? roundNumber;
  final int? totalRounds;
  final String? trumpInfo;
  final int? cardsDealt;
  final RoomSocialMode socialMode;
  final bool isSpectator;
  final VoidCallback? onMenuTap;

  const GameHud({
    super.key,
    required this.gameName,
    this.roundNumber,
    this.totalRounds,
    this.trumpInfo,
    this.cardsDealt,
    this.socialMode = RoomSocialMode.full,
    this.isSpectator = false,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Game pill
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GameIconBox(),
                const SizedBox(width: 5),
                Text(
                  gameName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Round info
          if (roundNumber != null)
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalRounds != null
                        ? 'Round $roundNumber/$totalRounds'
                        : 'Round $roundNumber',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (trumpInfo != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      trumpInfo!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.cardRed,
                      ),
                    ),
                  ],
                  if (cardsDealt != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      '$cardsDealt cards',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const Spacer(),

          // Social mode (only shown when not Full)
          if (socialMode != RoomSocialMode.full) ...[
            SocialModeIndicator(mode: socialMode),
            const SizedBox(width: 6),
          ],

          // Spectator badge
          if (isSpectator) ...[
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Spectating',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Menu button
          GestureDetector(
            onTap: onMenuTap,
            child: GlassContainer(
              borderRadius: 17,
              padding: EdgeInsets.zero,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.more_horiz,
                  color: AppColors.textDark,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameIconBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentSoft],
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Center(
        child: Text('🃏', style: TextStyle(fontSize: 13)),
      ),
    );
  }
}
