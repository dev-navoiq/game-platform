import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Pulsing glow and rotating ring around the active player's avatar.
///
/// Pulse duration matches `_context.md`: 1200ms ease-in-out.
class TurnIndicatorAnimation extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color glowColor;
  final Duration pulseDuration;

  const TurnIndicatorAnimation({
    super.key,
    required this.child,
    required this.isActive,
    this.glowColor = AppColors.accent,
    this.pulseDuration = AnimationDurations.turnIndicator,
  });

  @override
  State<TurnIndicatorAnimation> createState() =>
      _TurnIndicatorAnimationState();
}

class _TurnIndicatorAnimationState extends State<TurnIndicatorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TurnIndicatorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating gradient ring
            Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      widget.glowColor.withOpacity(0),
                      widget.glowColor,
                      widget.glowColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Pulsing glow
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // Child content
            widget.child,
          ],
        );
      },
    );
  }
}
