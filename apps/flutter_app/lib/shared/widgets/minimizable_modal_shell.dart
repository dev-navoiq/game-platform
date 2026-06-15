import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
import '../animations/transitions/modal_transitions.dart';

/// A reusable shell for any in-game modal that the player may want to
/// minimize so they can see the table state behind it (other bids, trump,
/// scoreboard etc.) and then re-open.
///
/// Render the modal body as [child]. The shell adds a small minimize button
/// at the top-right of the body. When minimized, the shell renders a
/// compact tappable chip in the bottom-right of the screen instead.
class MinimizableModalShell extends StatefulWidget {
  /// Body shown when the modal is expanded. Should be sized for itself —
  /// the shell only adds a header with title + minimize button.
  final Widget child;

  /// Title shown in the header.
  final String title;

  /// Label shown on the minimized chip. Keep short ("Place Your Bid").
  final String minimizedLabel;

  /// Optional secondary detail line shown in the minimized chip (e.g.
  /// "Bid 18 to call").
  final String? minimizedDetail;

  /// Icon used on the minimized chip.
  final IconData minimizedIcon;

  /// Initial state — start expanded.
  final bool initiallyExpanded;

  /// Optional padding inside the modal body. Defaults to 18 on all sides.
  final EdgeInsets bodyPadding;

  /// Optional width of the modal. Defaults to 280.
  final double width;

  const MinimizableModalShell({
    super.key,
    required this.child,
    required this.title,
    required this.minimizedLabel,
    this.minimizedDetail,
    this.minimizedIcon = Icons.gavel_rounded,
    this.initiallyExpanded = true,
    this.bodyPadding = const EdgeInsets.all(18),
    this.width = 280,
  });

  @override
  State<MinimizableModalShell> createState() => _MinimizableModalShellState();
}

class _MinimizableModalShellState extends State<MinimizableModalShell> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant MinimizableModalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Allow the parent to re-assert expansion on rebuild (e.g. a fresh
    // bid round starts and the screen wants the modal back).
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 12, 76),
          child: _MinimizedChip(
            label: widget.minimizedLabel,
            detail: widget.minimizedDetail,
            icon: widget.minimizedIcon,
            onTap: () => setState(() => _expanded = true),
          ),
        ),
      );
    }

    return Center(
      child: ModalEntryTransition(
        child: Container(
          width: widget.width,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('modal-minimize'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _expanded = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.unfold_less_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hide',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: widget.bodyPadding.copyWith(top: 4),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimizedChip extends StatelessWidget {
  final String label;
  final String? detail;
  final IconData icon;
  final VoidCallback onTap;

  const _MinimizedChip({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('modal-restore'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_less_rounded,
                  size: 18, color: Colors.white.withOpacity(0.9)),
            ],
          ),
        ),
      ),
    );
  }
}
