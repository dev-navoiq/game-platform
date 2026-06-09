import 'package:flutter/material.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Auction history laid out as a 4-column NESW grid.
///
/// The grid is filled chronologically starting from [dealerIndex]; each row
/// represents one full circuit around the table. Cells are auto-wrapped onto
/// new rows once column W is filled.
class BridgeAuctionStrip extends StatelessWidget {
  final List<AuctionCall> auctionHistory;
  final int dealerIndex;

  const BridgeAuctionStrip({
    super.key,
    required this.auctionHistory,
    required this.dealerIndex,
  });

  static const _seatLabels = ['N', 'E', 'S', 'W'];

  String _denomGlyph(BridgeDenomination d) {
    switch (d) {
      case BridgeDenomination.clubs:
        return '♣';
      case BridgeDenomination.diamonds:
        return '♦';
      case BridgeDenomination.hearts:
        return '♥';
      case BridgeDenomination.spades:
        return '♠';
      case BridgeDenomination.noTrump:
        return 'NT';
    }
  }

  Color _denomColor(BridgeDenomination d) {
    if (d == BridgeDenomination.hearts || d == BridgeDenomination.diamonds) {
      return AppColors.cardRed;
    }
    return AppColors.cardBlack;
  }

  Widget _renderCall(AuctionCall call) {
    if (call.isPass) {
      return Text(
        'P',
        key: const Key('auction-pass'),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      );
    }
    if (call.isDouble) {
      return Text(
        'X',
        key: const Key('auction-double'),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      );
    }
    if (call.isRedouble) {
      return Text(
        'XX',
        key: const Key('auction-redouble'),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      );
    }
    // bid
    final denom = call.denomination!;
    return RichText(
      key: const Key('auction-bid'),
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        children: [
          TextSpan(text: '${call.level}'),
          TextSpan(
            text: _denomGlyph(denom),
            style: TextStyle(color: _denomColor(denom)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fill grid in clockwise seat order starting from dealer column.
    // Each call occupies a cell at its seatIndex column.
    final cells = <int, Widget>{}; // cellIndex (rowMajor) -> widget
    final firstCol = dealerIndex % 4;
    for (var i = 0; i < auctionHistory.length; i++) {
      final cellIndex = firstCol + i;
      cells[cellIndex] = _renderCall(auctionHistory[i]);
    }
    final maxIndex = cells.isEmpty ? 0 : cells.keys.reduce((a, b) => a > b ? a : b);
    final rowCount = ((maxIndex + 1) / 4).ceil().clamp(1, 99);

    return GlassContainer(
      key: const Key('bridge-auction-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 140, maxWidth: 180),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(4, (col) {
                  final isDealer = col == firstCol;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _seatLabels[col],
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDealer
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Container(height: 0.5, color: AppColors.textMuted.withOpacity(0.3)),
              const SizedBox(height: 4),
              for (var row = 0; row < rowCount; row++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    children: List.generate(4, (col) {
                      final idx = row * 4 + col;
                      return Expanded(
                        child: Center(
                          child: cells[idx] ??
                              const SizedBox(width: 1, height: 14),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
