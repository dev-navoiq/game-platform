import 'dart:math';

import 'package:flutter/material.dart';

/// Particle type for the [ParticleSystem].
enum ParticleType { point, confetti, spark, glow }

/// Configuration for particle emission.
class ParticleConfig {
  final ParticleType type;
  final int count;
  final double minSpeed;
  final double maxSpeed;
  final double gravity;
  final double minLifetime;
  final double maxLifetime;
  final List<Color> colors;
  final Rect emissionArea;
  final double minSize;
  final double maxSize;

  const ParticleConfig({
    this.type = ParticleType.point,
    this.count = 50,
    this.minSpeed = 50,
    this.maxSpeed = 150,
    this.gravity = 98,
    this.minLifetime = 0.5,
    this.maxLifetime = 2.0,
    this.colors = const [Colors.white],
    this.emissionArea = Rect.zero,
    this.minSize = 2,
    this.maxSize = 6,
  });
}

/// Reusable particle system backed by [CustomPainter].
///
/// Used as the foundation for confetti, fireworks, and sparkle effects.
class ParticleSystem extends StatefulWidget {
  final bool isPlaying;
  final ParticleConfig config;
  final Duration duration;
  final VoidCallback? onComplete;

  const ParticleSystem({
    super.key,
    required this.isPlaying,
    required this.config,
    this.duration = const Duration(seconds: 2),
    this.onComplete,
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

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
      _controller.forward().then((_) => widget.onComplete?.call());
    }
  }

  @override
  void didUpdateWidget(ParticleSystem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _generateParticles();
      _controller.forward(from: 0).then((_) => widget.onComplete?.call());
    }
  }

  void _generateParticles() {
    final cfg = widget.config;
    _particles = List.generate(cfg.count, (_) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = cfg.minSpeed + _random.nextDouble() * (cfg.maxSpeed - cfg.minSpeed);
      final size = cfg.minSize + _random.nextDouble() * (cfg.maxSize - cfg.minSize);
      final lifetime =
          cfg.minLifetime + _random.nextDouble() * (cfg.maxLifetime - cfg.minLifetime);
      final color = cfg.colors[_random.nextInt(cfg.colors.length)];

      return _Particle(
        x: cfg.emissionArea.left +
            _random.nextDouble() * cfg.emissionArea.width,
        y: cfg.emissionArea.top +
            _random.nextDouble() * cfg.emissionArea.height,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: size,
        lifetime: lifetime,
        color: color,
        type: cfg.type,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 8,
      );
    });
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
          painter: _ParticleSystemPainter(
            particles: _particles,
            progress: _controller.value,
            totalDuration: widget.duration.inMilliseconds / 1000.0,
            gravity: widget.config.gravity,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final double lifetime;
  final Color color;
  final ParticleType type;
  final double rotation;
  final double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.lifetime,
    required this.color,
    required this.type,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ParticleSystemPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double totalDuration;
  final double gravity;

  _ParticleSystemPainter({
    required this.particles,
    required this.progress,
    required this.totalDuration,
    required this.gravity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * totalDuration;

    for (final p in particles) {
      if (t > p.lifetime) continue;

      final lifeProgress = t / p.lifetime;
      final x = p.x + p.vx * t;
      final y = p.y + p.vy * t + 0.5 * gravity * t * t;
      final opacity = (1 - lifeProgress).clamp(0.0, 1.0);

      if (x < -50 || x > size.width + 50 || y > size.height + 50) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);

      switch (p.type) {
        case ParticleType.point:
          canvas.drawCircle(Offset.zero, p.size, paint);
          break;
        case ParticleType.confetti:
          canvas.rotate(p.rotation + p.rotationSpeed * t);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 2,
              height: p.size,
            ),
            paint,
          );
          break;
        case ParticleType.spark:
          canvas.rotate(p.rotation + p.rotationSpeed * t);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 0.5,
              height: p.size * 3,
            ),
            paint,
          );
          break;
        case ParticleType.glow:
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);
          canvas.drawCircle(Offset.zero, p.size, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticleSystemPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
