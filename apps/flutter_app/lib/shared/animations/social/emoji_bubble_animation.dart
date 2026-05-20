import 'package:flutter/material.dart';

import '../core/animation_constants.dart';

/// Emoji reaction floating up from a player's avatar position.
///
/// Duration matches `_context.md`: 1400ms.
/// Note: For in-game floating chat bubbles, see
/// `lib/shared/widgets/floating_chat_bubble.dart` (built in Session 8).
class EmojiBubbleAnimation extends StatefulWidget {
  final String emoji;
  final Offset startPosition;
  final VoidCallback? onComplete;

  const EmojiBubbleAnimation({
    super.key,
    required this.emoji,
    required this.startPosition,
    this.onComplete,
  });

  @override
  State<EmojiBubbleAnimation> createState() => _EmojiBubbleAnimationState();
}

class _EmojiBubbleAnimationState extends State<EmojiBubbleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.emojiFloat,
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3),
        weight: 0.15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 0.1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.5),
        weight: 0.25,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.ease,
    ));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 0.1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 0.6),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 0.3),
    ]).animate(_controller);

    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.startPosition + const Offset(0, -140),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.ease,
    ));

    _controller.forward().then((_) => widget.onComplete?.call());
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
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
