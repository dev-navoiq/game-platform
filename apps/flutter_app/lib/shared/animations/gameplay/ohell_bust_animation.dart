import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-bleed "OH HELL" bust overlay that plays when a player wins more
/// tricks than they bid.
///
/// Two layers:
/// 1. Fire — orange/red/yellow particles rising from [emissionCenter] with
///    upward velocity + flicker.
/// 2. Smoke text — translucent "OH HELL" rendered with a multi-pass blur,
///    drifting up + fading.
class OhellBustAnimation extends StatefulWidget {
  final bool isPlaying;

  /// Origin point of the flames in local widget coordinates. The overlay
  /// is expected to be sized to fill its parent (Stack.fill), and the
  /// caller is responsible for computing this offset (e.g., from a seat
  /// alignment).
  final Offset emissionCenter;

  final VoidCallback? onComplete;

  const OhellBustAnimation({
    super.key,
    required this.isPlaying,
    required this.emissionCenter,
    this.onComplete,
  });

  @override
  State<OhellBustAnimation> createState() => _OhellBustAnimationState();
}

class _OhellBustAnimationState extends State<OhellBustAnimation>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2200);
  static const _fireColors = [
    Color(0xFFFFE082), // soft yellow
    Color(0xFFFFB74D), // amber
    Color(0xFFFF7043), // deep orange
    Color(0xFFE53935), // red
  ];

  late final AnimationController _controller;
  final Random _random = Random();
  final List<_FireParticle> _flames = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    if (widget.isPlaying) _start();
  }

  @override
  void didUpdateWidget(OhellBustAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _start();
    }
  }

  void _start() {
    _flames
      ..clear()
      ..addAll(List.generate(48, (_) => _spawnParticle()));
    _controller
      ..reset()
      ..forward().then((_) => widget.onComplete?.call());
  }

  _FireParticle _spawnParticle() {
    final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 0.8;
    final speed = 90 + _random.nextDouble() * 160;
    final size = 6 + _random.nextDouble() * 14;
    final lifetime = 0.7 + _random.nextDouble() * 1.0;
    return _FireParticle(
      offset: Offset(
        (_random.nextDouble() - 0.5) * 24,
        (_random.nextDouble() - 0.5) * 16,
      ),
      vx: cos(angle) * speed,
      vy: sin(angle) * speed,
      size: size,
      lifetime: lifetime,
      delay: _random.nextDouble() * 0.45,
      color: _fireColors[_random.nextInt(_fireColors.length)],
      flicker: _random.nextDouble() * 2 * pi,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _FirePainter(
                  particles: _flames,
                  progress: t,
                  totalDuration: _duration.inMilliseconds / 1000.0,
                  center: widget.emissionCenter,
                ),
              ),
              _buildSmokeText(t),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmokeText(double t) {
    // Text rises from just above the flames, drifts up, fades out.
    final entry = Curves.easeOut.transform((t * 1.4).clamp(0.0, 1.0));
    final exit = Curves.easeIn.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
    final opacity = (entry - exit).clamp(0.0, 1.0);
    final rise = -60.0 * t;
    final scale = 0.85 + 0.25 * entry;
    final blurStrength = 4.0 + 10.0 * t;

    return Positioned(
      left: widget.emissionCenter.dx - 180,
      top: widget.emissionCenter.dy - 110 + rise,
      width: 360,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: _SmokeText(blurStrength: blurStrength),
        ),
      ),
    );
  }
}

class _SmokeText extends StatelessWidget {
  final double blurStrength;

  const _SmokeText({required this.blurStrength});

  @override
  Widget build(BuildContext context) {
    // Layered text: large soft white halo behind, slightly tinted body in
    // front, gives a smoke-with-glow effect without needing a shader.
    final baseStyle = GoogleFonts.poppins(
      fontSize: 64,
      fontWeight: FontWeight.w900,
      letterSpacing: 6,
      height: 1,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'OH HELL',
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: Colors.white.withOpacity(0.18),
            shadows: [
              Shadow(
                color: Colors.white.withOpacity(0.35),
                blurRadius: blurStrength + 8,
              ),
            ],
          ),
        ),
        Text(
          'OH HELL',
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: Colors.white.withOpacity(0.75),
            shadows: [
              Shadow(
                color: const Color(0xFFFF7043).withOpacity(0.55),
                blurRadius: blurStrength,
                offset: const Offset(0, 2),
              ),
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: blurStrength * 1.4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FireParticle {
  final Offset offset;
  final double vx;
  final double vy;
  final double size;
  final double lifetime;
  final double delay;
  final Color color;
  final double flicker;

  _FireParticle({
    required this.offset,
    required this.vx,
    required this.vy,
    required this.size,
    required this.lifetime,
    required this.delay,
    required this.color,
    required this.flicker,
  });
}

class _FirePainter extends CustomPainter {
  final List<_FireParticle> particles;
  final double progress;
  final double totalDuration;
  final Offset center;

  _FirePainter({
    required this.particles,
    required this.progress,
    required this.totalDuration,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tSeconds = progress * totalDuration;

    for (final p in particles) {
      final local = tSeconds - p.delay;
      if (local < 0 || local > p.lifetime) continue;

      final lifeT = local / p.lifetime;
      // Gentle drift up — small negative gravity term keeps flames floating.
      final x = center.dx + p.offset.dx + p.vx * local;
      final y = center.dy + p.offset.dy + p.vy * local - 20 * local * local;

      // Flicker on size, fade quickly near end-of-life.
      final flicker = 0.85 + 0.15 * sin(p.flicker + local * 12);
      final radius = p.size * (1.0 - lifeT * 0.45) * flicker;
      final opacity = (1.0 - lifeT) * 0.9;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Hot inner core for a brighter centre.
      final corePaint = Paint()
        ..color = Colors.white.withOpacity((1.0 - lifeT) * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius * 0.45, corePaint);
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) =>
      progress != old.progress || center != old.center;
}
