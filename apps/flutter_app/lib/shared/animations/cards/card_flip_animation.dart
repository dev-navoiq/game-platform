import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// 3D perspective card flip animation (face-down ↔ face-up).
///
/// Uses Y-axis rotation with a scale bump at the midpoint.
class CardFlipAnimation extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFaceUp;
  final VoidCallback? onComplete;

  const CardFlipAnimation({
    super.key,
    required this.front,
    required this.back,
    required this.isFaceUp,
    this.onComplete,
  });

  @override
  State<CardFlipAnimation> createState() => _CardFlipAnimationState();
}

class _CardFlipAnimationState extends State<CardFlipAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late bool _showFront;

  @override
  void initState() {
    super.initState();
    _showFront = widget.isFaceUp;

    _controller = AnimationController(
      duration: AnimationDurations.cardFlip,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: AnimationCurves.cardFlip),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.05),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0),
        weight: 0.5,
      ),
    ]).animate(_controller);

    // Switch face at midpoint
    _controller.addListener(() {
      if (_controller.value >= 0.5 && _showFront == widget.isFaceUp) {
        setState(() {
          _showFront = !widget.isFaceUp;
        });
      }
    });
  }

  @override
  void didUpdateWidget(CardFlipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFaceUp != oldWidget.isFaceUp) {
      _showFront = oldWidget.isFaceUp;
      _controller.forward(from: 0).then((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Perspective transform
        final angle = _rotationAnimation.value;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _showFront ? widget.front : widget.back,
          ),
        );
      },
    );
  }
}
