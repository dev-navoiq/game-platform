import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Slim top-of-table ribbon shown between rounds.
///
/// Communicates *what just happened* (the result message) and offers two
/// actions: open the scoreboard (lazy bottom sheet) and ready up for the
/// next round. Per-player ready state lives on each PlayerNode now, so
/// this widget no longer renders a wide chips row.
class RoundEndRibbon extends StatefulWidget {
  final String message;
  final VoidCallback onShowScoreboard;
  final int? countdownSeconds;
  final VoidCallback? onReadyTap;
  final bool isLocalReady;

  const RoundEndRibbon({
    super.key,
    required this.message,
    required this.onShowScoreboard,
    this.countdownSeconds,
    this.onReadyTap,
    this.isLocalReady = false,
  });

  @override
  State<RoundEndRibbon> createState() => _RoundEndRibbonState();
}

class _RoundEndRibbonState extends State<RoundEndRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slide = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    final clamped = seconds < 0 ? 0 : seconds;
    final padded = clamped.toString().padLeft(2, '0');
    return 'Next round in 00:$padded';
  }

  @override
  Widget build(BuildContext context) {
    final hasReady = widget.onReadyTap != null;
    final hasCountdown = widget.countdownSeconds != null;

    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enableGlow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (hasCountdown) ...[
                      const SizedBox(width: 10),
                      Text(
                        _formatCountdown(widget.countdownSeconds!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    GlassButton(
                      label: 'Scoreboard',
                      onPressed: widget.onShowScoreboard,
                      variant: GlassButtonVariant.ghost,
                      size: GlassButtonSize.small,
                      color: AppColors.accent,
                    ),
                  ],
                ),
                if (hasReady) ...[
                  const SizedBox(height: 8),
                  if (widget.isLocalReady)
                    Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'READY ✓',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    GlassButton(
                      label: "I'M READY",
                      onPressed: widget.onReadyTap,
                      variant: GlassButtonVariant.filled,
                      color: AppColors.accent,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
