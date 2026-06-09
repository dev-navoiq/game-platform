import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';

/// Wraps [child] with a pulsing accent glow + brief haptic feedback when
/// it's the local player's turn. Game-agnostic — any card or board screen
/// can drop this around the area that should call attention to itself.
class TurnIndicator extends StatefulWidget {
  final bool isYourTurn;
  final Widget child;

  /// Glow colour. Defaults to the gold accent.
  final Color color;

  /// If true, a `HapticFeedback.mediumImpact` fires on the false→true
  /// transition (i.e. when your turn arrives). Doesn't fire on re-builds
  /// while it's already your turn.
  final bool haptic;

  const TurnIndicator({
    super.key,
    required this.isYourTurn,
    required this.child,
    this.color = AppColors.accent,
    this.haptic = true,
  });

  @override
  State<TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<TurnIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isYourTurn) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TurnIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isYourTurn && !old.isYourTurn) {
      if (widget.haptic) HapticFeedback.mediumImpact();
      _pulse.repeat(reverse: true);
    } else if (!widget.isYourTurn && old.isYourTurn) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isYourTurn) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        // Glow intensity oscillates between 0.35 and 0.7.
        final t = 0.35 + 0.35 * _pulse.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(t),
                blurRadius: 22 + 10 * _pulse.value,
                spreadRadius: 1 + 2 * _pulse.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
