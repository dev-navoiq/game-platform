import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// Animated dice widget for Ludo showing dot faces (1-6).
///
/// Displays the [value] face. When [isRolling] is true, shows a
/// spinning animation. Tappable via [onTap] to trigger a roll.
class LudoDiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool isEnabled;
  final VoidCallback? onTap;

  const LudoDiceWidget({
    super.key,
    this.value,
    this.isRolling = false,
    this.isEnabled = true,
    this.onTap,
  });

  @override
  State<LudoDiceWidget> createState() => _LudoDiceWidgetState();
}

class _LudoDiceWidgetState extends State<LudoDiceWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final AnimationController _pulse;
  final _random = math.Random();

  /// True when the die is waiting for a tap to roll.
  bool get _canRoll =>
      widget.isEnabled && widget.onTap != null && !widget.isRolling;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotation = Tween(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (_canRoll) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LudoDiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _controller.repeat();
    } else if (!widget.isRolling && oldWidget.isRolling) {
      _controller.forward(from: _controller.value).then((_) {
        _controller.reset();
      });
    }
    if (_canRoll && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_canRoll && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEnabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pulse]),
        builder: (context, _) {
          final displayValue = widget.isRolling
              ? _random.nextInt(6) + 1
              : (widget.value ?? 1);
          final pulse = _canRoll ? _pulse.value : 0.0;

          return Transform(
            alignment: Alignment.center,
            transform: widget.isRolling
                ? (Matrix4.identity()..rotateZ(_rotation.value))
                : (Matrix4.identity()..scale(1.0 + 0.09 * pulse)),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.isEnabled ? 1.0 : 0.5,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _canRoll
                        ? AppColors.accent.withOpacity(0.85)
                        : AppColors.textDark.withOpacity(0.2),
                    width: _canRoll ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_canRoll)
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.15 + 0.4 * pulse),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _DiceFacePainter(displayValue),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the dot pattern for a die face value (1-6).
class _DiceFacePainter extends CustomPainter {
  final int value;

  _DiceFacePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textDark
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.08;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final offset = size.width * 0.25;

    final dots = _dotsForValue(value, cx, cy, offset);
    for (final dot in dots) {
      canvas.drawCircle(dot, dotRadius, paint);
    }
  }

  List<Offset> _dotsForValue(
      int val, double cx, double cy, double offset) {
    switch (val) {
      case 1:
        return [Offset(cx, cy)];
      case 2:
        return [
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy + offset),
        ];
      case 3:
        return [
          Offset(cx - offset, cy - offset),
          Offset(cx, cy),
          Offset(cx + offset, cy + offset),
        ];
      case 4:
        return [
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ];
      case 5:
        return [
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx, cy),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ];
      case 6:
        return [
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx - offset, cy),
          Offset(cx + offset, cy),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ];
      default:
        return [Offset(cx, cy)];
    }
  }

  @override
  bool shouldRepaint(_DiceFacePainter old) => old.value != value;
}

