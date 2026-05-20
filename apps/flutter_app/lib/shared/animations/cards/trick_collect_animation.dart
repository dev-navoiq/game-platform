import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Animates trick cards gathering to center then sliding to the winner.
class TrickCollectAnimation extends StatefulWidget {
  final List<Widget> cards;
  final List<Offset> cardPositions;
  final int winnerSeatIndex;
  final int currentPlayerSeat;
  final VoidCallback? onComplete;

  const TrickCollectAnimation({
    super.key,
    required this.cards,
    required this.cardPositions,
    required this.winnerSeatIndex,
    required this.currentPlayerSeat,
    this.onComplete,
  });

  @override
  State<TrickCollectAnimation> createState() => _TrickCollectAnimationState();
}

class _TrickCollectAnimationState extends State<TrickCollectAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gatherAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.trickCollect,
      vsync: this,
    );

    // Phase 1: Gather to center
    _gatherAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
    );

    // Phase 2: Slide to winner
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.4, 0.8, curve: AnimationCurves.trickCollect),
    );

    // Phase 3: Fade out
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: pi * 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  Offset _getWinnerOffset() {
    final seatOffset =
        (widget.winnerSeatIndex - widget.currentPlayerSeat + 4) % 4;
    switch (seatOffset) {
      case 0:
        return const Offset(0, 150);
      case 1:
        return const Offset(200, 0);
      case 2:
        return const Offset(0, -150);
      case 3:
        return const Offset(-200, 0);
      default:
        return Offset.zero;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winnerOffset = _getWinnerOffset();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(widget.cards.length, (index) {
            final cardPos = index < widget.cardPositions.length
                ? widget.cardPositions[index]
                : Offset.zero;

            final gatheredPos = Offset.lerp(
              cardPos,
              Offset.zero,
              _gatherAnimation.value,
            )!;

            final finalPos = Offset.lerp(
              gatheredPos,
              winnerOffset,
              _slideAnimation.value,
            )!;

            final scale = 1.0 - (_slideAnimation.value * 0.3);

            return Transform.translate(
              offset: finalPos,
              child: Transform.rotate(
                angle: _rotateAnimation.value,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 1.0 - _fadeAnimation.value,
                    child: widget.cards[index],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
