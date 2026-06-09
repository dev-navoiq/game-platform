import 'package:flutter/material.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Overlay shown after each deal (and at game end) summarising the result.
///
/// Reads the latest [BridgeDealResult] and displays contract + made/down line,
/// the per-deal point breakdown, cumulative NS/EW totals, and a Next-Deal
/// button. At game end the button reads "New Game" but still dispatches the
/// same `newDeal` move — the engine handles the restart.
class BridgeRoundEndOverlay extends StatelessWidget {
  final BridgeDealResult result;
  final Map<String, int> cumulativeScores;
  final bool isGameEnd;
  final VoidCallback onNext;

  const BridgeRoundEndOverlay({
    super.key,
    required this.result,
    required this.cumulativeScores,
    required this.isGameEnd,
    required this.onNext,
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

  String _resultLine() {
    if (result.contract == null) return 'Passed out';
    if (result.made) {
      return result.overtricks == 0
          ? 'Made exactly'
          : 'Made +${result.overtricks}';
    }
    return 'Down ${result.undertricks}';
  }

  String _winnerLine() {
    final ns = cumulativeScores['NS'] ?? 0;
    final ew = cumulativeScores['EW'] ?? 0;
    if (ns == ew) return 'Tie $ns-$ew';
    final winner = ns > ew ? 'NS' : 'EW';
    return '$winner won $ns-$ew';
  }

  @override
  Widget build(BuildContext context) {
    final ns = cumulativeScores['NS'] ?? 0;
    final ew = cumulativeScores['EW'] ?? 0;
    final contract = result.contract;

    return Container(
      key: const Key('bridge-round-end-overlay'),
      color: Colors.black.withOpacity(0.62),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  isGameEnd ? 'Game Over' : 'Deal ${result.dealNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Contract + result line
              if (contract != null) ...[
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      children: [
                        TextSpan(text: '${contract.level}'),
                        TextSpan(
                          text: _denomGlyph(contract.denomination),
                          style: TextStyle(
                              color: _denomColor(contract.denomination)),
                        ),
                        TextSpan(
                          text: '  by ${_seatLabels[contract.declarerSeat % 4]}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ] else
                Center(
                  child: Text(
                    'No bid — deal scratched',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

              Center(
                child: Text(
                  _resultLine(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: result.made
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
              if (contract != null) ...[
                const SizedBox(height: 2),
                Center(
                  child: Text(
                    '${result.declarerTricks}/${contract.tricksRequired} tricks',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Per-deal point breakdown
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _scoreCol('NS this deal', result.nsPoints),
                    _scoreCol('EW this deal', result.ewPoints),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Cumulative scores
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _totalCol('NS', ns),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.textMuted.withOpacity(0.3),
                    ),
                    _totalCol('EW', ew),
                  ],
                ),
              ),

              if (isGameEnd) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _winnerLine(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              GestureDetector(
                key: const Key('bridge-next-deal'),
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isGameEnd ? 'New Game' : 'Next Deal',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCol(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _totalCol(String team, int value) {
    return Column(
      children: [
        Text(
          team,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
