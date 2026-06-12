import 'package:flutter/material.dart';

class WinnerJumpAnimation extends StatefulWidget {
  final Widget child;

  const WinnerJumpAnimation({super.key, required this.child});

  @override
  State<WinnerJumpAnimation> createState() => _WinnerJumpAnimationState();
}

class _WinnerJumpAnimationState extends State<WinnerJumpAnimation>
    with SingleTickerProviderStateMixin {
  static const _bounceCount = 3;
  static const _bouncePeak = -16.0;
  static const Duration _bounceDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: _bounceDuration * _bounceCount,
      vsync: this,
    );

    final items = <TweenSequenceItem<double>>[];
    for (var i = 0; i < _bounceCount; i++) {
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: _bouncePeak)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 1,
        ),
      );
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: _bouncePeak, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 1,
        ),
      );
    }

    _translateY = TweenSequence<double>(items).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translateY,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
