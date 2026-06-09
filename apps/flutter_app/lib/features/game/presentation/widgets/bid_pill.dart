import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Coloured bid status chip showing tricks won vs bid.
///
/// Modes:
/// - Pre-bid ([hasBid] = false): shows "?" so the empty slot is still visible
///   next to the player's avatar during the bidding phase.
/// - Post-bid: shows "$won / $bid" with colour:
///   - Neutral (white) while won < bid
///   - Success (green) on the exact bid
///   - Danger (red) when busted (won > bid)
class BidPill extends StatelessWidget {
  final int won;
  final int bid;
  final bool hasBid;

  const BidPill({
    super.key,
    required this.won,
    required this.bid,
    this.hasBid = true,
  });

  Color get _bgColor {
    if (!hasBid) return Colors.white.withOpacity(0.10);
    if (won > bid) return AppColors.danger.withOpacity(0.28);
    if (won == bid) return AppColors.success.withOpacity(0.28);
    return Colors.white.withOpacity(0.18);
  }

  Color get _textColor {
    if (!hasBid) return Colors.white.withOpacity(0.55);
    if (won > bid) return AppColors.danger;
    if (won == bid) return AppColors.success;
    return Colors.white;
  }

  Color? get _borderColor {
    if (!hasBid) return null;
    if (won > bid) return AppColors.danger.withOpacity(0.6);
    if (won == bid) return AppColors.success.withOpacity(0.6);
    return Colors.white.withOpacity(0.25);
  }

  @override
  Widget build(BuildContext context) {
    final label = hasBid ? '$won / $bid' : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(100),
        border: _borderColor != null
            ? Border.all(color: _borderColor!, width: 1)
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: hasBid ? 11 : 10,
          fontWeight: FontWeight.w800,
          color: _textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
