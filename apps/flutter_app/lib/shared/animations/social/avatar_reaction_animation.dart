import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Quick reaction animation on a player avatar.
///
/// Scale bounces (0.8 → 1.2 → 1.0) with an optional coloured ring pulse.
class AvatarReactionAnimation extends StatefulWidget {
  final Widget child;
  final Color? reactionColor;
  final bool isReacting;

  const AvatarReactionAnimation({
    super.key,
    required this.child,
    this.reactionColor,
    this.isReacting = false,
  });

  @override
  State<AvatarReactionAnimation> createState() =>
      _AvatarReactionAnimationState();
}

class _AvatarReactionAnimationState extends State<AvatarReactionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.avatarReaction,
      vsync: this,
    );

    // TweenSequence domain is [0, 1]; easeOutBack overshoots and would
    // throw at evaluate time. The sequence already provides the bounce
    // (1.0 → 0.8 → 1.2 → 1.0), so drive it from the raw controller.
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8),
        weight: 0.15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.2),
        weight: 0.35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0),
        weight: 0.5,
      ),
    ]).animate(_controller);

    _ringAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 0.3),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 0.7),
    ]).animate(_controller);

    if (widget.isReacting) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AvatarReactionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReacting && !oldWidget.isReacting) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.reactionColor ?? AppColors.accent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ring pulse
            if (_controller.isAnimating || _controller.value > 0)
              Container(
                width: 60 + 20 * _ringAnimation.value,
                height: 60 + 20 * _ringAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor.withOpacity(_ringAnimation.value * 0.6),
                    width: 2,
                  ),
                ),
              ),

            // Avatar
            Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}
