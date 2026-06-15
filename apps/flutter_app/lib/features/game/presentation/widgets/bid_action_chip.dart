import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Tiny chip that floats next to a player's avatar during the bidding
/// phase, surfacing what they just did so a bidder doesn't need to dismiss
/// the bid modal to see what their opponents have called.
///
/// Distinct types render with different colours; pass-through to a plain
/// container is intentional so the chip can sit on top of avatars or in
/// the trick zone without breaking the layout.
enum BidAction { bid, pass, doubled, redoubled, royalWedding }

class BidActionChip extends StatelessWidget {
  final BidAction action;
  final int? value;

  const BidActionChip({super.key, required this.action, this.value});

  String get _label {
    switch (action) {
      case BidAction.bid:
        return value?.toString() ?? '–';
      case BidAction.pass:
        return 'Pass';
      case BidAction.doubled:
        return '×2';
      case BidAction.redoubled:
        return '×4';
      case BidAction.royalWedding:
        return 'K+Q';
    }
  }

  Color get _bg {
    switch (action) {
      case BidAction.bid:
        return AppColors.accent;
      case BidAction.pass:
        return Colors.white.withOpacity(0.18);
      case BidAction.doubled:
        return const Color(0xFFE08A2A);
      case BidAction.redoubled:
        return const Color(0xFFD52F47);
      case BidAction.royalWedding:
        return const Color(0xFF8B5CF6);
    }
  }

  Color get _fg {
    return action == BidAction.pass ? Colors.white70 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: action == BidAction.pass
            ? null
            : [
                BoxShadow(
                  color: _bg.withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        _label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
