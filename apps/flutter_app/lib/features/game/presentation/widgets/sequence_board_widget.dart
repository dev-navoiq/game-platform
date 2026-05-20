import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:game_sequence/game_sequence.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// 10×10 Sequence game board with card faces and chip overlays.
///
/// Each cell shows a playing card face. Chips are rendered as colored circles
/// on top. Corner cells (free/wild) show a star icon. Completed sequences
/// get a highlighted border.
class SequenceBoardWidget extends StatelessWidget {
  final SequenceBoard board;
  final Set<(int, int)> validPlacements;
  final Set<(int, int)> removablePositions;
  final ValueChanged<(int, int)>? onCellTap;

  const SequenceBoardWidget({
    super.key,
    required this.board,
    this.validPlacements = const {},
    this.removablePositions = const {},
    this.onCellTap,
  });

  static const _chipColors = {
    ChipColor.red: Color(0xFFEF4444),
    ChipColor.blue: Color(0xFF3B82F6),
    ChipColor.green: Color(0xFF22C55E),
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a5c2e),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.5),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              childAspectRatio: 1,
            ),
            itemCount: 100,
            itemBuilder: (context, index) {
              final row = index ~/ 10;
              final col = index % 10;
              return _buildCell(row, col);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final cell = board.cellAt(row, col);
    final isCorner = board.isCorner(row, col);
    final isValid = validPlacements.contains((row, col));
    final isRemovable = removablePositions.contains((row, col));
    final hasChip = cell.chip != null;
    final isSequence = cell.isPartOfSequence;

    return GestureDetector(
      onTap: (isValid || isRemovable) && onCellTap != null
          ? () => onCellTap!((row, col))
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isCorner
              ? AppColors.accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.9),
          border: Border.all(
            color: isValid
                ? AppColors.accent
                : isRemovable
                    ? AppColors.danger
                    : isSequence
                        ? Colors.amber.withOpacity(0.6)
                        : Colors.grey.withOpacity(0.3),
            width: (isValid || isRemovable) ? 1.5 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Card face
            if (isCorner)
              Center(
                child: Icon(
                  Icons.star,
                  size: 14,
                  color: AppColors.accent,
                ),
              )
            else if (cell.card != null)
              Center(
                child: _CardFace(card: cell.card!),
              ),

            // Chip overlay
            if (hasChip || isCorner)
              if (hasChip)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _chipColors[cell.chip]!,
                        border: Border.all(
                          color: Colors.white,
                          width: isSequence ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _chipColors[cell.chip]!.withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

            // Valid placement glow
            if (isValid)
              Positioned.fill(
                child: Container(
                  color: AppColors.accent.withOpacity(0.15),
                ),
              ),

            // Removable indicator
            if (isRemovable)
              Positioned.fill(
                child: Container(
                  color: AppColors.danger.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      size: 10,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders a compact card face showing rank + suit symbol.
class _CardFace extends StatelessWidget {
  final PlayingCard card;

  const _CardFace({required this.card});

  @override
  Widget build(BuildContext context) {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final color = isRed ? AppColors.cardRed : AppColors.cardBlack;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _rankLabel(card.rank),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
        Text(
          _suitSymbol(card.suit),
          style: TextStyle(
            fontSize: 8,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  static String _rankLabel(Rank rank) {
    switch (rank) {
      case Rank.ace:
        return 'A';
      case Rank.king:
        return 'K';
      case Rank.queen:
        return 'Q';
      case Rank.jack:
        return 'J';
      case Rank.ten:
        return '10';
      case Rank.nine:
        return '9';
      case Rank.eight:
        return '8';
      case Rank.seven:
        return '7';
      case Rank.six:
        return '6';
      case Rank.five:
        return '5';
      case Rank.four:
        return '4';
      case Rank.three:
        return '3';
      case Rank.two:
        return '2';
    }
  }

  static String _suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }
}
