import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Small circular icon shown above the player's hand between rounds.
///
/// Displays the next-round countdown when the player hasn't readied yet
/// (tap-to-ready), then swaps to a green checkmark once ready. Replaces
/// the wide "I'M READY" button that previously lived in [RoundEndRibbon]
/// — the user complained that button covered too much of the table.
class BetweenRoundsReadyIcon extends StatelessWidget {
  final int secondsLeft;
  final bool isReady;
  final VoidCallback onTap;

  const BetweenRoundsReadyIcon({
    super.key,
    required this.secondsLeft,
    required this.isReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReady ? null : onTap,
      child: GlassContainer(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 56,
          height: 56,
          child: isReady
              ? const Center(
                  child: Icon(
                    Icons.check_circle,
                    size: 30,
                    color: AppColors.success,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${secondsLeft.clamp(0, 99)}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'READY',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
