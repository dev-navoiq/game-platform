import 'package:flutter/material.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Bidding panel for Contract Bridge — 7×5 level/denomination grid plus
/// Pass / Double / Redouble actions.
///
/// Single-tap-to-send: tapping a level×denom cell submits the bid immediately.
/// Cells that don't outrank the current high bid are disabled. Pass is always
/// enabled. Double/Redouble are enabled only when legal under the auction
/// history (computed by walking [auctionHistory]).
class BridgeBiddingBox extends StatelessWidget {
  /// Local seat index (0..3) — used to compute double/redouble legality
  /// against the auction history.
  final int seatIndex;
  final List<AuctionCall> auctionHistory;

  final void Function(int level, BridgeDenomination denomination) onBid;
  final VoidCallback onPass;
  final VoidCallback onDouble;
  final VoidCallback onRedouble;

  const BridgeBiddingBox({
    super.key,
    required this.seatIndex,
    required this.auctionHistory,
    required this.onBid,
    required this.onPass,
    required this.onDouble,
    required this.onRedouble,
  });

  static const _denominations = BridgeDenomination.values;

  // ── Auction legality helpers (mirror BridgeRules without taking a dep) ──

  AuctionCall? _lastBid() {
    for (final c in auctionHistory.reversed) {
      if (c.isBid) return c;
    }
    return null;
  }

  /// Returns true if (level, denom) outranks the current high bid (or is
  /// legal at any level when no bid exists yet).
  bool _bidLegal(int level, BridgeDenomination d) {
    final lb = _lastBid();
    if (lb == null) return true;
    if (level > lb.level!) return true;
    if (level == lb.level! && d.index > lb.denomination!.index) return true;
    return false;
  }

  bool get _canDouble {
    for (final c in auctionHistory.reversed) {
      if (c.isPass) continue;
      if (c.isDouble || c.isRedouble) return false;
      if (c.isBid) {
        // Cannot double partner's bid.
        return c.seatIndex % 2 != seatIndex % 2;
      }
    }
    return false;
  }

  bool get _canRedouble {
    for (final c in auctionHistory.reversed) {
      if (c.isPass) continue;
      if (c.isRedouble) return false;
      if (c.isBid) return false;
      if (c.isDouble) {
        // Cannot redouble own side's contract that was just doubled.
        return c.seatIndex % 2 != seatIndex % 2;
      }
    }
    return false;
  }

  // ── Rendering helpers ───────────────────────────────────────────────────

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
    if (d == BridgeDenomination.noTrump) {
      return AppColors.textDark;
    }
    return AppColors.cardBlack;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('bridge-bidding-box'),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.93),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Bid',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            // Denomination header row
            Row(
              children: [
                const SizedBox(width: 22),
                for (final d in _denominations)
                  Expanded(
                    child: Center(
                      child: Text(
                        _denomGlyph(d),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _denomColor(d),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Level rows
            for (var level = 1; level <= 7; level++) _levelRow(level),
            const SizedBox(height: 10),
            // Action row: Pass | Double | Redouble
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    key: const Key('bridge-pass'),
                    label: 'Pass',
                    enabled: true,
                    onTap: onPass,
                    bg: Colors.white.withOpacity(0.6),
                    fg: AppColors.textMuted,
                    borderColor: AppColors.textMuted.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _actionButton(
                    key: const Key('bridge-double'),
                    label: 'X',
                    enabled: _canDouble,
                    onTap: onDouble,
                    bg: AppColors.danger.withOpacity(0.15),
                    fg: AppColors.danger,
                    borderColor: AppColors.danger.withOpacity(0.4),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _actionButton(
                    key: const Key('bridge-redouble'),
                    label: 'XX',
                    enabled: _canRedouble,
                    onTap: onRedouble,
                    bg: AppColors.danger,
                    fg: Colors.white,
                    borderColor: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelRow(int level) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$level',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          for (final d in _denominations)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _bidCell(level, d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bidCell(int level, BridgeDenomination d) {
    final legal = _bidLegal(level, d);
    return GestureDetector(
      key: Key('bridge-bid-$level-${d.name}'),
      onTap: legal ? () => onBid(level, d) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 28,
        decoration: BoxDecoration(
          color: legal
              ? Colors.white.withOpacity(0.7)
              : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: legal
                ? AppColors.accent.withOpacity(0.25)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            '$level${_denomGlyph(d)}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: legal
                  ? _denomColor(d)
                  : AppColors.textMuted.withOpacity(0.35),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required Key key,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    required Color borderColor,
  }) {
    return GestureDetector(
      key: key,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
