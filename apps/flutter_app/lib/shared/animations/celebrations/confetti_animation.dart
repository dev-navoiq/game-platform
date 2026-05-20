import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';

/// Full-screen confetti celebration.
class ConfettiAnimation extends StatefulWidget {
  final bool isPlaying;
  final int particleCount;
  final Duration duration;
  final List<Color>? colors;

  const ConfettiAnimation({
    super.key,
    required this.isPlaying,
    this.particleCount = 100,
    this.duration = AnimationDurations.confetti,
    this.colors,
  });

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  static const List<Color> _defaultColors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _particles = [];

    if (widget.isPlaying) {
      _generateParticles();
      _controller.forward();
    }
  }

  void _generateParticles() {
    final colors = widget.colors ?? _defaultColors;

    _particles = List.generate(widget.particleCount, (i) {
      return _ConfettiParticle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.5,
        vx: (_random.nextDouble() - 0.5) * 2,
        vy: 2 + _random.nextDouble() * 3,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        width: 8 + _random.nextDouble() * 8,
        height: 6 + _random.nextDouble() * 6,
        color: colors[_random.nextInt(colors.length)],
        delay: _random.nextDouble() * 0.3,
      );
    });
  }

  @override
  void didUpdateWidget(ConfettiAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _generateParticles();
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
    if (!widget.isPlaying) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double rotation;
  final double rotationSpeed;
  final double width;
  final double height;
  final Color color;
  final double delay;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final effectiveProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);

      if (effectiveProgress <= 0) continue;

      final gravity = 0.5;
      final t = effectiveProgress * 3;
      final x = size.width * particle.x + particle.vx * t * 50;
      final y = size.height * particle.y +
          particle.vy * t * 100 +
          gravity * t * t * 100;

      if (y > size.height + 50) continue;

      final rotation = particle.rotation + particle.rotationSpeed * t;

      final opacity =
          effectiveProgress > 0.7 ? (1 - effectiveProgress) / 0.3 : 1.0;

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.height,
      );
      canvas.drawRect(rect, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
