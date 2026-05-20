import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Multi-burst fireworks effect for major wins.
///
/// Uses gold + white palette from `AppColors.accent` and `AppColors.accentSoft`.
class FireworksAnimation extends StatefulWidget {
  final bool isPlaying;
  final int burstCount;
  final VoidCallback? onComplete;

  const FireworksAnimation({
    super.key,
    required this.isPlaying,
    this.burstCount = 3,
    this.onComplete,
  });

  @override
  State<FireworksAnimation> createState() => _FireworksAnimationState();
}

class _FireworksAnimationState extends State<FireworksAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Burst> _bursts;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.fireworks,
      vsync: this,
    );

    _bursts = [];

    if (widget.isPlaying) {
      _generateBursts();
      _controller.forward().then((_) => widget.onComplete?.call());
    }
  }

  void _generateBursts() {
    const colors = [
      AppColors.accent,
      AppColors.accentSoft,
      Colors.white,
    ];

    _bursts = List.generate(widget.burstCount, (i) {
      final particles = List.generate(40, (_) {
        final angle = _random.nextDouble() * 2 * pi;
        final speed = 80 + _random.nextDouble() * 160;
        return _FireworkParticle(
          angle: angle,
          speed: speed,
          size: 2 + _random.nextDouble() * 4,
          color: colors[_random.nextInt(colors.length)],
          trail: _random.nextBool(),
        );
      });

      return _Burst(
        centerX: 0.2 + _random.nextDouble() * 0.6,
        centerY: 0.2 + _random.nextDouble() * 0.4,
        delay: i * 0.25,
        particles: particles,
      );
    });
  }

  @override
  void didUpdateWidget(FireworksAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _generateBursts();
      _controller.forward(from: 0).then((_) => widget.onComplete?.call());
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
          painter: _FireworksPainter(
            bursts: _bursts,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FireworkParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool trail;

  _FireworkParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.trail,
  });
}

class _Burst {
  final double centerX;
  final double centerY;
  final double delay;
  final List<_FireworkParticle> particles;

  _Burst({
    required this.centerX,
    required this.centerY,
    required this.delay,
    required this.particles,
  });
}

class _FireworksPainter extends CustomPainter {
  final List<_Burst> bursts;
  final double progress;

  _FireworksPainter({required this.bursts, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in bursts) {
      final burstProgress =
          ((progress - burst.delay) / (1 - burst.delay)).clamp(0.0, 1.0);
      if (burstProgress <= 0) continue;

      final cx = size.width * burst.centerX;
      final cy = size.height * burst.centerY;
      final gravity = 60.0;

      for (final p in burst.particles) {
        final t = burstProgress * 1.5;
        final x = cx + cos(p.angle) * p.speed * t;
        final y = cy + sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;
        final opacity = (1 - burstProgress).clamp(0.0, 1.0);

        if (y > size.height + 50) continue;

        final paint = Paint()
          ..color = p.color.withOpacity(opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), p.size * (1 - burstProgress * 0.5), paint);

        // Glow
        if (p.trail && burstProgress < 0.5) {
          paint
            ..color = p.color.withOpacity(opacity * 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);
          canvas.drawCircle(Offset(x, y), p.size * 3, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
