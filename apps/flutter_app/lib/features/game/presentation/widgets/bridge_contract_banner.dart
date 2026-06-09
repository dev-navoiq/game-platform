import 'package:flutter/material.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Small glass pill summarising the active Bridge contract.
///
/// Shows: level + denomination (e.g. "3NT"), declarer seat ("by N"),
/// double tag ("X" / "XX"), vulnerability tag, and tricks taken vs needed.
class BridgeContractBanner extends StatelessWidget {
  final BridgeContract contract;
  final Vulnerability vulnerability;

  /// Tricks the declaring side has currently taken in the play phase.
  final int declarerTricks;

  const BridgeContractBanner({
    super.key,
    required this.contract,
    required this.vulnerability,
    required this.declarerTricks,
  });

  static const _seatLabels = ['N', 'E', 'S', 'W'];

  String get _levelLabel => '${contract.level}${_denomGlyph(contract.denomination)}';

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

  String? get _doubleTag {
    switch (contract.doubleStatus) {
      case BridgeDoubleStatus.doubled:
        return 'X';
      case BridgeDoubleStatus.redoubled:
        return 'XX';
      case BridgeDoubleStatus.undoubled:
        return null;
    }
  }

  // Vulnerable styling only when declarer's side is at risk this deal.
  bool get _declarerVulnerable {
    switch (vulnerability) {
      case Vulnerability.none:
        return false;
      case Vulnerability.both:
        return true;
      case Vulnerability.ns:
        return contract.declarerTeam == 'NS';
      case Vulnerability.ew:
        return contract.declarerTeam == 'EW';
    }
  }

  @override
  Widget build(BuildContext context) {
    final seatLabel = _seatLabels[contract.declarerSeat % 4];

    return GlassContainer(
      key: const Key('bridge-contract-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 18,
      enableGlow: _declarerVulnerable,
      glowColor: AppColors.danger.withOpacity(0.25),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _levelLabel,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _denomColor(contract.denomination),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'by $seatLabel',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          if (_doubleTag != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _doubleTag!,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
          if (_declarerVulnerable) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                border: Border.all(color: AppColors.danger.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'VUL',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Container(width: 1, height: 14, color: AppColors.textMuted.withOpacity(0.3)),
          const SizedBox(width: 8),
          Text(
            '$declarerTricks/${contract.tricksRequired} tricks',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
