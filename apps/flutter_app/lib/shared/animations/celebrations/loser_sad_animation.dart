import 'dart:math';

import 'package:flutter/material.dart';

class LoserSadAnimation extends StatefulWidget {
  final Widget child;
  final bool showTear;

  const LoserSadAnimation({
    super.key,
    required this.child,
    this.showTear = false,
  });

  @override
  State<LoserSadAnimation> createState() => _LoserSadAnimationState();
}

class _LoserSadAnimationState extends State<LoserSadAnimation>
    with SingleTickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 900);
  static const double _shakeAngle = 5 * pi / 180;
  static const double _droopY = 6.0;

  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _droop;
  late final Animation<double> _tearOpacity;
  late final Animation<double> _tearTranslate;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: _totalDuration,
      vsync: this,
    );

    _rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: _shakeAngle),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: _shakeAngle, end: -_shakeAngle),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -_shakeAngle, end: _shakeAngle),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: _shakeAngle, end: 0.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 9,
      ),
    ]).animate(_controller);

    _droop = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 4,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: _droopY)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 6,
      ),
    ]).animate(_controller);

    _tearOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 8,
      ),
    ]).animate(_controller);

    _tearTranslate = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -24.0),
        weight: 8,
      ),
    ]).animate(_controller);

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
      animation: _controller,
      builder: (context, child) {
        final body = Transform.translate(
          offset: Offset(0, _droop.value),
          child: Transform.rotate(
            angle: _rotation.value,
            child: child,
          ),
        );

        if (!widget.showTear) return body;

        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            body,
            Positioned(
              top: -8,
              child: Opacity(
                opacity: _tearOpacity.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _tearTranslate.value),
                  child: const Text(
                    '\u{1F4A7}',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
