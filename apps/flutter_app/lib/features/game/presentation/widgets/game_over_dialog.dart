import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/celebrations/confetti_animation.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';

/// End-game modal showing results with confetti for winners.
class GameOverDialog extends StatelessWidget {
  final bool isWinner;
  final String? winnerName;
  final Map<String, int> finalScores;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeave;

  // Reward display
  final int coinsEarned;
  final int xpEarned;
  final VoidCallback? onDoubleCoins;

  const GameOverDialog({
    super.key,
    required this.isWinner,
    this.winnerName,
    this.finalScores = const {},
    this.onPlayAgain,
    this.onLeave,
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.onDoubleCoins,
  });

  @override
  Widget build(BuildContext context) {
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
                    if (coinsEarned > 0 || xpEarned > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (coinsEarned > 0)
                              _RewardChip(
                                icon: Icons.circle,
                                iconColor: GlassTokens.warning,
                                label: '+$coinsEarned',
                              ),
                            if (coinsEarned > 0 && xpEarned > 0)
                              const SizedBox(width: 12),
                            if (xpEarned > 0)
                              _RewardChip(
                                icon: Icons.bolt,
                                iconColor: AppColors.success,
                                label: '+$xpEarned XP',
                              ),
                          ],
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
