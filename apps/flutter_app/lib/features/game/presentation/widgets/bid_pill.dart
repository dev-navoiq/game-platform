import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Coloured bid status chip showing tricks won vs bid.
///
/// Colour logic:
/// - Neutral (white) when won < bid (still in progress)
/// - Success (green) when won == bid (making it)
/// - Danger (red) when won > bid (busted)
class BidPill extends StatelessWidget {
  final int won;
  final int bid;

  const BidPill({super.key, required this.won, required this.bid});

  Color get _bgColor {
    if (won > bid) return AppColors.danger.withOpacity(0.22);
    if (won == bid) return AppColors.success.withOpacity(0.22);
    return Colors.white.withOpacity(0.15);
  }

  Color get _textColor {
    if (won > bid) return AppColors.danger;
    if (won == bid) return AppColors.success;
    return Colors.white.withOpacity(0.75);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$won / $bid',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );
  }
}
