import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';

/// Bid selection panel for trick-taking card games.
///
/// Renders bid buttons with keys `Key('bid-$i')` for each valid bid value.
/// Supports forbidden bid for Oh Hell dealer constraint.
/// Designed as a compact floating panel — does NOT cover the card hand area.
class BiddingModal extends StatefulWidget {
  final int minBid;
  final int maxBid;
  final int? forbiddenBid;
  final bool showPassButton;
  final bool showDoubleButton;
  final bool showRedoubleButton;

  /// When the grid should be suppressed because the contract has been locked
  /// by a double or redouble — only Pass / Redouble remain.
  final bool bidGridEnabled;
  final String? trumpInfo;
  final void Function(int bid) onBidSelected;
  final VoidCallback? onPass;
  final VoidCallback? onDouble;
  final VoidCallback? onRedouble;

  const BiddingModal({
    super.key,
    this.minBid = 0,
    required this.maxBid,
    this.forbiddenBid,
    this.showPassButton = false,
    this.showDoubleButton = false,
    this.showRedoubleButton = false,
    this.bidGridEnabled = true,
    this.trumpInfo,
    required this.onBidSelected,
    this.onPass,
    this.onDouble,
    this.onRedouble,
  });

  @override
  State<BiddingModal> createState() => _BiddingModalState();
}

class _BiddingModalState extends State<BiddingModal> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ModalEntryTransition(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'Place Your Bid',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),

              Text(
                'How many tricks will you win?',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),

              if (widget.trumpInfo != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Trump: ${widget.trumpInfo}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Forbidden bid warning
              if (widget.forbiddenBid != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.15)),
                  ),
                  child: Text(
                    'Cannot bid ${widget.forbiddenBid} (dealer constraint)',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Bid grid
              if (widget.bidGridEnabled) _buildBidGrid(),

              // Double / Redouble row
              if (widget.showDoubleButton || widget.showRedoubleButton) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.showDoubleButton)
                      Expanded(
                        child: GestureDetector(
                          key: const Key('bid-double'),
                          onTap: widget.onDouble,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accent.withOpacity(0.4),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Double',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.showDoubleButton && widget.showRedoubleButton)
                      const SizedBox(width: 8),
                    if (widget.showRedoubleButton)
                      Expanded(
                        child: GestureDetector(
                          key: const Key('bid-redouble'),
                          onTap: widget.onRedouble,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Redouble',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // Pass button
              if (widget.showPassButton) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  key: const Key('bid-pass'),
                  onTap: widget.onPass,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.textMuted.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Pass',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (widget.bidGridEnabled) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _selected == null
                      ? null
                      : () => widget.onBidSelected(_selected!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selected == null
                          ? AppColors.accent.withOpacity(0.4)
                          : AppColors.accent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: _selected == null
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        'Confirm Bid',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidGrid() {
    final rawCount = widget.maxBid - widget.minBid + 1;
    final bidCount = rawCount.clamp(0, 30);

    if (bidCount <= 0) {
      return const Text('No valid bids', style: TextStyle(color: Colors.grey));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: bidCount,
      itemBuilder: (_, index) {
        final bidValue = widget.minBid + index;
        final isForbidden = bidValue == widget.forbiddenBid;
        final isSelected = _selected == bidValue;

        return GestureDetector(
          key: Key('bid-$bidValue'),
          onTap: isForbidden
              ? null
              : () => setState(() => _selected = bidValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.accent.withOpacity(0.18),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$bidValue',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isForbidden
                      ? AppColors.textMuted.withOpacity(0.35)
                      : isSelected
                          ? Colors.white
                          : AppColors.textDark,
                  decoration:
                      isForbidden ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
