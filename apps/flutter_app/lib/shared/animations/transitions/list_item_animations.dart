import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Staggered list item entry animation.
///
/// Each item fades in + translateY(-12→0), 250ms with 60ms stagger.
/// Used for lobby room lists, leaderboards, etc.
class ListItemAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const ListItemAnimation({
    super.key,
    required this.child,
    required this.index,
    this.delay = AnimationDurations.listItemStagger,
  });

  @override
  State<ListItemAnimation> createState() => _ListItemAnimationState();
}

class _ListItemAnimationState extends State<ListItemAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.listItem,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.smoothOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6),
    ));

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
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
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
