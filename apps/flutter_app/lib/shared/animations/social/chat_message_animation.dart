import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Slide-from-bottom + fade-in animation for chat messages entering a list.
///
/// Stagger delay is based on [index] × 60ms.
class ChatMessageAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;

  const ChatMessageAnimation({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = AnimationDurations.listItemStagger,
  });

  @override
  State<ChatMessageAnimation> createState() => _ChatMessageAnimationState();
}

class _ChatMessageAnimationState extends State<ChatMessageAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.chatBubbleEnter,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.smoothOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    Future.delayed(widget.staggerDelay * widget.index, () {
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
        return SlideTransition(
          position: _slideAnimation,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
