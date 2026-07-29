import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/social_mode_indicator.dart';
import '../../providers/game_provider.dart';

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
  /// When non-null, render a scoreboard icon button in the HUD that opens
  /// the score sheet. Replaces the larger "Show scoreboard" button that
  /// used to live in the round-end ribbon.
  final VoidCallback? onScoreboardTap;
  /// When non-null, renders an exit icon button that triggers forfeit /
  /// leave. Moved here from the bottom GameActions row to free up vertical
  /// space near the player's hand.
  final VoidCallback? onForfeitTap;

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
    this.onScoreboardTap,
    this.onForfeitTap,
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

          // Stream health: when the realtime subscription is reconnecting,
          // the table may be stale — say so instead of impersonating a live
          // view (#186). Consumer-scoped so every game's HUD gets it free.
          Consumer(builder: (context, ref, _) {
            final healthy = ref.watch(gameStreamHealthyProvider);
            if (healthy) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accentSoft,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Reconnecting…',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentSoft,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Round info
          if (roundNumber != null)
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // The engine advances roundNumber when a round COMPLETES,
                    // so at round end / game end it reads one past the total
                    // ("Round 8/7"). Clamp for display — there is no round 8.
                    switch ((roundNumber ?? 1, totalRounds)) {
                      (final int round, final int total) =>
                        'Round ${round > total ? total : round}/$total',
                      (final int round, null) => 'Round $round',
                    },
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

          // Scoreboard icon (sibling to the menu button)
          if (onScoreboardTap != null) ...[
            GestureDetector(
              onTap: onScoreboardTap,
              child: GlassContainer(
                borderRadius: 17,
                padding: EdgeInsets.zero,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.leaderboard_outlined,
                    color: AppColors.textDark,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Forfeit / exit icon (sibling to scoreboard + menu)
          if (onForfeitTap != null) ...[
            GestureDetector(
              onTap: onForfeitTap,
              child: GlassContainer(
                borderRadius: 17,
                padding: EdgeInsets.zero,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.exit_to_app,
                    color: AppColors.textDark,
                    size: 18,
                  ),
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
