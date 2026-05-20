import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';

/// Circular countdown timer ring.
///
/// Spec from `_context.md` TurnTimer:
/// - Size: 38×38px
/// - Track: white 10% opacity, stroke 3
/// - Fill: accent colour, stroke 3, round cap
/// - Number: Poppins 12px white centre
class TimerRingAnimation extends StatefulWidget {
  final int seconds;
  final VoidCallback? onExpired;

  const TimerRingAnimation({
    super.key,
    required this.seconds,
    this.onExpired,
  });

  @override
  State<TimerRingAnimation> createState() => _TimerRingAnimationState();
}

class _TimerRingAnimationState extends State<TimerRingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: widget.seconds),
      vsync: this,
    );

    _controller.forward().then((_) {
      if (mounted) widget.onExpired?.call();
    });
  }

  @override
  void didUpdateWidget(TimerRingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds != oldWidget.seconds) {
      _controller.duration = Duration(seconds: widget.seconds);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final remaining =
            (widget.seconds * (1 - _controller.value)).ceil();

        return SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(38, 38),
                painter: _TimerRingPainter(
                  progress: 1 - _controller.value,
                  trackColor: Colors.white.withOpacity(0.10),
                  fillColor: AppColors.accent,
                  strokeWidth: 3,
                ),
              ),
              Text(
                '$remaining',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      2 * pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
