import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Compact pill that always shows the trump state in trick-taking games.
///
/// • No trump chosen yet → hidden.
/// • Trump chosen but still face-down → shows a closed card (🂠) plus a label.
/// • Trump revealed → shows the suit symbol in its coloured form.
///
/// When [canReveal] is true and the trump is still closed, the pill becomes
/// tappable and invokes [onReveal].
class TrumpIndicator extends StatelessWidget {
  final Suit? trumpSuit;
  final bool trumpRevealed;
  final int doublingMultiplier;
  final bool canReveal;
  final VoidCallback? onReveal;

  const TrumpIndicator({
    super.key,
    required this.trumpSuit,
    required this.trumpRevealed,
    this.doublingMultiplier = 1,
    this.canReveal = false,
    this.onReveal,
  });

  static String suitSymbol(Suit suit) => switch (suit) {
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
        Suit.spades => '♠',
      };

  @override
  Widget build(BuildContext context) {
    if (trumpSuit == null) return const SizedBox.shrink();

    final isRed = trumpSuit == Suit.hearts || trumpSuit == Suit.diamonds;
    final suitColor = trumpRevealed
        ? (isRed ? AppColors.cardRed : AppColors.textDark)
        : AppColors.textMuted;

    final pill = GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trump',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          if (trumpRevealed)
            Text(
              suitSymbol(trumpSuit!),
              style: TextStyle(fontSize: 18, color: suitColor, height: 1),
            )
          else
            const Text(
              '🂠',
              style: TextStyle(fontSize: 18, color: AppColors.textMuted, height: 1),
            ),
          if (doublingMultiplier > 1) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                doublingMultiplier == 4 ? 'x4' : 'x2',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
          if (!trumpRevealed && canReveal) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.visibility_outlined,
              size: 14,
              color: AppColors.accent,
            ),
          ],
        ],
      ),
    );

    if (!trumpRevealed && canReveal && onReveal != null) {
      return GestureDetector(
        key: const Key('trump-reveal-pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onReveal,
        child: Tooltip(
          message: 'Reveal trump (you must then play a trump card if you hold one)',
          child: pill,
        ),
      );
    }
    return pill;
  }
}
