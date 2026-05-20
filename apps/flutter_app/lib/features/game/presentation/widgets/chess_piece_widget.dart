import 'package:flutter/material.dart';
import 'package:game_chess/game_chess.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders a chess piece using Unicode symbols.
///
/// Takes a [ChessPiece] and renders its symbol centered in a container.
/// Supports selection highlighting and drag source styling.
class ChessPieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final double size;
  final bool isSelected;
  final bool isDragSource;

  const ChessPieceWidget({
    super.key,
    required this.piece,
    this.size = 40,
    this.isSelected = false,
    this.isDragSource = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isDragSource ? 0.3 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            piece.symbol,
            style: GoogleFonts.notoSans(
              fontSize: size * 0.7,
              height: 1.0,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
