import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/game_end_ad_controller.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/celebrations/confetti_animation.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';

/// End-game modal showing results with confetti for winners.
///
/// Appearing exactly once per finished game, this widget is also the
/// central hook for the game-end interstitial: on first frame it notifies
/// [GameEndAdController], which applies tier + cadence gating (free users
/// only, every 2nd game, 3-minute gap, every 3rd slot = Pro-upsell house
/// ad). The game is already over here, so it can never fire mid-game.
class GameOverDialog extends ConsumerStatefulWidget {
  final bool isWinner;
  final String? winnerName;
  final Map<String, int> finalScores;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeave;

  // Reward display
  final int coinsEarned;
  final int xpEarned;

  /// Gems are never granted at regular game end — this only renders for
  /// flows that do pay gems (e.g. tournament payouts routed through the
  /// dialog). Hidden when 0 (#55).
  final int gemsEarned;
  final VoidCallback? onDoubleCoins;

  /// Optional one-liner under the reward chips (e.g. "Includes first win of
  /// the day 🌟" or "Daily earn limit reached"). Hidden when null.
  final String? rewardNote;

  const GameOverDialog({
    super.key,
    required this.isWinner,
    this.winnerName,
    this.finalScores = const {},
    this.onPlayAgain,
    this.onLeave,
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.gemsEarned = 0,
    this.onDoubleCoins,
    this.rewardNote,
  });

  @override
  ConsumerState<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends ConsumerState<GameOverDialog> {
  @override
  void initState() {
    super.initState();
    // Game-end interstitial (free tier, cadence-gated). Post-frame so the
    // results are on screen before any full-screen ad appears on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gameEndAdControllerProvider).onGameFinished(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = widget.isWinner;
    final winnerName = widget.winnerName;
    final finalScores = widget.finalScores;
    final onPlayAgain = widget.onPlayAgain;
    final onLeave = widget.onLeave;
    final coinsEarned = widget.coinsEarned;
    final xpEarned = widget.xpEarned;
    final onDoubleCoins = widget.onDoubleCoins;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),

        // Dialog
        Center(
          child: ModalEntryTransition(
            child: GlassContainer(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      isWinner ? 'Victory!' : 'Game Over',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color:
                            isWinner ? AppColors.success : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Icon
                    Icon(
                      isWinner
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied,
                      size: 64,
                      color: isWinner ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Text(
                      isWinner
                          ? 'Congratulations!'
                          : winnerName != null
                              ? '$winnerName wins!'
                              : 'Better luck next time!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Reward chips
                    if (coinsEarned > 0 ||
                        xpEarned > 0 ||
                        widget.gemsEarned > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (coinsEarned > 0)
                              _RewardChip(
                                icon: Icons.circle,
                                iconColor: GlassTokens.warning,
                                label: '+$coinsEarned',
                              ),
                            if (widget.gemsEarned > 0)
                              _RewardChip(
                                icon: Icons.diamond,
                                iconColor: const Color(0xFF9C27B0),
                                label: '+${widget.gemsEarned}',
                              ),
                            if (xpEarned > 0)
                              _RewardChip(
                                icon: Icons.bolt,
                                iconColor: AppColors.success,
                                label: '+$xpEarned XP',
                              ),
                          ],
                        ),
                      ),

                    if (widget.rewardNote != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.rewardNote!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),

                    // Scores
                    if (finalScores.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: finalScores.entries.map((e) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    '${e.value}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // Double coins prompt
                    if (onDoubleCoins != null && coinsEarned > 0) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: onDoubleCoins,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: GlassTokens.warning.withOpacity(0.15),
                            border: Border.all(
                              color: GlassTokens.warning.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill,
                                  size: 18, color: GlassTokens.warning),
                              const SizedBox(width: 8),
                              Text(
                                'Double your coins!',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: GlassTokens.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (onLeave != null)
                          GlassButton(
                            label: 'Home',
                            onPressed: onLeave,
                            variant: GlassButtonVariant.ghost,
                            color: AppColors.textMuted,
                          ),
                        if (onPlayAgain != null)
                          GlassButton(
                            label: 'Play Again',
                            onPressed: onPlayAgain,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Confetti
        if (isWinner)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiAnimation(isPlaying: isWinner),
            ),
          ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _RewardChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: iconColor.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
