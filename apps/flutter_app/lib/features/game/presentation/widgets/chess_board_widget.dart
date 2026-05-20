import 'package:flutter/material.dart';
import 'package:game_chess/game_chess.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import 'chess_piece_widget.dart';

/// Interactive 8×8 chess board widget.
///
/// Supports piece selection, valid move highlighting, last-move highlighting,
/// and board flipping for the black player perspective.
class ChessBoardWidget extends StatelessWidget {
  final ChessBoard board;
  final ChessSquare? selectedSquare;
  final Set<ChessSquare> validMoveSquares;
  final ChessSquare? lastMoveFrom;
  final ChessSquare? lastMoveTo;
  final bool flipBoard;
  final ValueChanged<ChessSquare>? onSquareTap;

  const ChessBoardWidget({
    super.key,
    required this.board,
    this.selectedSquare,
    this.validMoveSquares = const {},
    this.lastMoveFrom,
    this.lastMoveTo,
    this.flipBoard = false,
    this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textDark, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: List.generate(8, (visualRank) {
            final rank = flipBoard ? visualRank : 7 - visualRank;
            return Expanded(
              child: Row(
                children: List.generate(8, (visualFile) {
                  final file = flipBoard ? 7 - visualFile : visualFile;
                  final square = ChessSquare(file, rank);
                  return Expanded(
                    child: _buildSquare(square, file, rank),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSquare(ChessSquare square, int file, int rank) {
    final isLight = (file + rank) % 2 != 0;
    final piece = board.pieceAt(square);
    final isSelected = selectedSquare == square;
    final isValidTarget = validMoveSquares.contains(square);
    final isLastMove = lastMoveFrom == square || lastMoveTo == square;

    Color bgColor;
    if (isSelected) {
      bgColor = Colors.amber.withOpacity(0.5);
    } else if (isLastMove) {
      bgColor = Colors.yellow.withOpacity(0.3);
    } else if (isLight) {
      bgColor = const Color(0xFFF0D9B5);
    } else {
      bgColor = const Color(0xFFB58863);
    }

    return GestureDetector(
      onTap: onSquareTap != null ? () => onSquareTap!(square) : null,
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            // Rank label (left edge)
            if (file == (flipBoard ? 7 : 0))
              Positioned(
                top: 1,
                left: 2,
                child: Text(
                  '${rank + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: isLight
                        ? const Color(0xFFB58863)
                        : const Color(0xFFF0D9B5),
                  ),
                ),
              ),

            // File label (bottom edge)
            if (rank == (flipBoard ? 7 : 0))
              Positioned(
                bottom: 1,
                right: 2,
                child: Text(
                  String.fromCharCode('a'.codeUnitAt(0) + file),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: isLight
                        ? const Color(0xFFB58863)
                        : const Color(0xFFF0D9B5),
                  ),
                ),
              ),

            // Piece
            if (piece != null)
              Center(
                child: ChessPieceWidget(
                  piece: piece,
                  isSelected: isSelected,
                ),
              ),

            // Valid move indicator
            if (isValidTarget)
              Center(
                child: piece != null
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.7),
                            width: 2.5,
                          ),
                          shape: BoxShape.circle,
                        ),
                        width: 32,
                        height: 32,
                      )
                    : Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
