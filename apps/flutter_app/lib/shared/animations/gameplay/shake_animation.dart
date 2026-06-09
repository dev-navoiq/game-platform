import 'dart:math';

import 'package:flutter/material.dart';

/// Imperatively triggered horizontal shake. Use a [ShakeController] to call
/// `shake()` from any parent state (e.g. when the server rejects a move).
class ShakeController extends ChangeNotifier {
  int _trigger = 0;
  int get trigger => _trigger;

  void shake() {
    _trigger++;
    notifyListeners();
  }
}

class ShakeAnimation extends StatefulWidget {
  final ShakeController controller;
  final Widget child;
  final Duration duration;
  final double amplitude;

  const ShakeAnimation({
    super.key,
    required this.controller,
    required this.child,
    this.duration = const Duration(milliseconds: 360),
    this.amplitude = 12,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: widget.duration);
    widget.controller.addListener(_onShake);
  }

  void _onShake() {
    _ac.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, child) {
        // Damped sine: 4 oscillations fading out across the duration.
        final t = _ac.value;
        final dx = t == 0
            ? 0.0
            : sin(t * pi * 8) * widget.amplitude * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
