import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// What the character is doing this frame — lets a skin add phase-specific FX
/// (e.g. a wobble while crashing) without the driver knowing skin internals.
enum RiderPhase { idle, driving, crashing, finished }

/// Per-frame transform + state the board hands a skin to paint one rider.
class RiderFrame {
  final Offset center; // pixel position
  final double sizePx; // ≈ cell size; the skin scales itself to this
  final double angle; // heading (radians)
  final double scale; // pulse / squash
  final double alpha; // 0..1 (fades during knockback)
  final Color color; // player color
  final bool active; // whose turn it is (subtle glow)
  final bool selected; // tapped, awaiting confirm
  final bool movable; // legal to move this turn (highlight ring)
  final RiderPhase phase;

  const RiderFrame({
    required this.center,
    required this.sizePx,
    required this.angle,
    required this.color,
    this.scale = 1,
    this.alpha = 1,
    this.active = false,
    this.selected = false,
    this.movable = false,
    this.phase = RiderPhase.idle,
  });
}

/// A pluggable Ludo token character. Swap implementations to change the look
/// (scooter ↔ car ↔ animal) without touching the engine, geometry, or driver.
///
/// A future `RiveRiderSkin` would implement this by positioning a Rive artboard
/// at [RiderFrame.center] and driving its state machine from [RiderFrame.phase]
/// — the rest of the pipeline stays identical.
abstract class LudoRiderSkin {
  void paint(Canvas canvas, RiderFrame f);
}

/// Vector scooter rider, ported from the HTML prototype. Pure canvas — no
/// assets, no dependencies. Faces along its heading; leans/wobbles on crash.
class ScooterSkin implements LudoRiderSkin {
  const ScooterSkin();

  @override
  void paint(Canvas canvas, RiderFrame f) {
    canvas.save();
    canvas.translate(f.center.dx, f.center.dy);

    // Movable / selected highlight ring sits under the rider, unrotated.
    if (f.selected || f.movable || f.active) {
      final ringColor = f.selected
          ? const Color(0xFFFFFFFF)
          : (f.movable ? const Color(0xFFE8A84F) : f.color);
      final t = (f.scale - 1).clamp(0.0, 0.2);
      canvas.drawCircle(
        Offset.zero,
        f.sizePx * (0.62 + t),
        Paint()
          ..color = ringColor.withOpacity((f.selected ? 0.9 : 0.45) * f.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.selected ? 2.6 : 1.8,
      );
    }

    canvas.rotate(f.angle);
    canvas.scale(f.scale);

    final u = f.sizePx * 0.82;
    final a = f.alpha;
    final body = f.color;

    // shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: u * 1.1, height: u * 0.64),
      Paint()..color = Colors.black.withOpacity(0.30 * a),
    );

    // wheels
    final wheelPaint = Paint()..color = const Color(0xFF0D0F15).withOpacity(a);
    for (final wy in [-u * 0.34, u * 0.34]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, wy), width: u * 0.28, height: u * 0.44),
        wheelPaint,
      );
    }

    // body (rounded, gradient)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-u * 0.26, -u * 0.4, u * 0.52, u * 0.8),
      Radius.circular(u * 0.22),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -u * 0.4),
          Offset(0, u * 0.4),
          [body.withOpacity(a), _shade(body, -25).withOpacity(a)],
        ),
    );

    // seat
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, u * 0.06), width: u * 0.34, height: u * 0.4),
      Paint()..color = _shade(body, -45).withOpacity(a),
    );
    // helmet
    canvas.drawCircle(
      Offset(0, -u * 0.04),
      u * 0.14,
      Paint()..color = const Color(0xFFF4F6FF).withOpacity(a),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -u * 0.04), radius: u * 0.14),
      math.pi * 0.15,
      math.pi * 0.7,
      true,
      Paint()..color = _shade(body, -30).withOpacity(a),
    );

    // handlebars
    canvas.drawLine(
      Offset(-u * 0.2, -u * 0.34),
      Offset(u * 0.2, -u * 0.34),
      Paint()
        ..color = const Color(0xFF11131A).withOpacity(a)
        ..strokeWidth = u * 0.07
        ..strokeCap = StrokeCap.round,
    );

    // headlight beam (cast forward, -y is the front)
    final beam = Path()
      ..moveTo(-u * 0.15, -u * 0.46)
      ..lineTo(u * 0.15, -u * 0.46)
      ..lineTo(u * 0.4, -u * 1.0)
      ..lineTo(-u * 0.4, -u * 1.0)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..color = const Color(0xFFFFF3B0).withOpacity(0.5 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // bright headlight lamp at the front
    final lamp = Offset(0, -u * 0.46);
    canvas.drawCircle(
      lamp,
      u * 0.2,
      Paint()..color = const Color(0xFFFFF3B0).withOpacity(0.55 * a),
    );
    canvas.drawCircle(
      lamp,
      u * 0.12,
      Paint()..color = const Color(0xFFFFFDE7).withOpacity(a),
    );

    canvas.restore();
  }

  static Color _shade(Color c, int amt) {
    int ch(int v) => (v + amt).clamp(0, 255);
    return Color.fromARGB(c.alpha, ch(c.red), ch(c.green), ch(c.blue));
  }
}

/// The classic flat token (a colored disc), as a fallback / alternate skin.
class ClassicSkin implements LudoRiderSkin {
  const ClassicSkin();

  @override
  void paint(Canvas canvas, RiderFrame f) {
    final r = f.sizePx * 0.4 * f.scale;
    if (f.selected || f.movable) {
      canvas.drawCircle(
        f.center,
        r + 4,
        Paint()
          ..color = (f.selected ? Colors.white : const Color(0xFFE8A84F))
              .withOpacity(0.5 * f.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    canvas.drawCircle(f.center, r, Paint()..color = f.color.withOpacity(f.alpha));
    canvas.drawCircle(
      f.center,
      r * 0.4,
      Paint()..color = Colors.white.withOpacity(f.alpha),
    );
  }
}
