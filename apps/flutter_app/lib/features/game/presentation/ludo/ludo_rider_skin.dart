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
  final double timeSec; // monotonic clock, for idle life (head-bob, flicker)
  final double lean; // cornering lean, ≈ -1..1 (positive = turning clockwise)

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
    this.timeSec = 0,
    this.lean = 0,
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

/// Movable / selected highlight ring, drawn unrotated under the character.
/// Expects the canvas to already be translated to the rider's center.
void _paintRing(Canvas canvas, RiderFrame f) {
  if (!(f.selected || f.movable || f.active)) return;
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

/// Vector scooter rider, ported from the HTML prototype. Pure canvas — no
/// assets, no dependencies. Faces along its heading; leans/wobbles on crash.
class ScooterSkin implements LudoRiderSkin {
  const ScooterSkin();

  @override
  void paint(Canvas canvas, RiderFrame f) {
    canvas.save();
    canvas.translate(f.center.dx, f.center.dy);
    _paintRing(canvas, f);

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
}

Color _shade(Color c, int amt) {
  int ch(int v) => (v + amt).clamp(0, 255);
  return Color.fromARGB(c.alpha, ch(c.red), ch(c.green), ch(c.blue));
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

/// Scooter with a VISIBLE rider — helmet, jacketed shoulders and arms reaching
/// the handlebars. Leans into corners (rider counterweights against the lean)
/// and head-bobs while driving. Premium skin.
class RiderScooterSkin implements LudoRiderSkin {
  const RiderScooterSkin();

  @override
  void paint(Canvas canvas, RiderFrame f) {
    canvas.save();
    canvas.translate(f.center.dx, f.center.dy);
    _paintRing(canvas, f);

    // Extra yaw into the corner; the rider below sways against it.
    canvas.rotate(f.angle + f.lean * 0.25);
    if (f.phase == RiderPhase.crashing) {
      canvas.rotate(math.sin(f.timeSec * 40) * 0.12); // wobble
    }
    canvas.scale(f.scale);

    final u = f.sizePx * 0.82;
    final a = f.alpha;
    final body = f.color;
    final driving = f.phase == RiderPhase.driving;
    final bob = driving
        ? math.sin(f.timeSec * 16) * u * 0.035
        : math.sin(f.timeSec * 2.2) * u * 0.015;
    final sway = -f.lean.clamp(-1.0, 1.0) * u * 0.10;

    // shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: u * 1.1, height: u * 0.64),
      Paint()..color = Colors.black.withOpacity(0.30 * a),
    );

    // wheels
    final wheelPaint = Paint()..color = const Color(0xFF0D0F15).withOpacity(a);
    for (final wy in [-u * 0.36, u * 0.36]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, wy), width: u * 0.26, height: u * 0.42),
        wheelPaint,
      );
    }

    // deck / body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-u * 0.24, -u * 0.42, u * 0.48, u * 0.84),
      Radius.circular(u * 0.2),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -u * 0.42),
          Offset(0, u * 0.42),
          [body.withOpacity(a), _shade(body, -25).withOpacity(a)],
        ),
    );

    // headlight (under the rider so the figure reads on top)
    final beam = Path()
      ..moveTo(-u * 0.13, -u * 0.44)
      ..lineTo(u * 0.13, -u * 0.44)
      ..lineTo(u * 0.36, -u * 0.95)
      ..lineTo(-u * 0.36, -u * 0.95)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..color = const Color(0xFFFFF3B0).withOpacity(0.45 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(0, -u * 0.44),
      u * 0.1,
      Paint()..color = const Color(0xFFFFFDE7).withOpacity(a),
    );

    // handlebars
    canvas.drawLine(
      Offset(-u * 0.21, -u * 0.30),
      Offset(u * 0.21, -u * 0.30),
      Paint()
        ..color = const Color(0xFF11131A).withOpacity(a)
        ..strokeWidth = u * 0.07
        ..strokeCap = StrokeCap.round,
    );

    // ── the rider ──
    // arms: shoulders → grips (drawn first so the torso overlaps their roots)
    final armPaint = Paint()
      ..color = _shade(body, 35).withOpacity(a)
      ..strokeWidth = u * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sway - u * 0.19, u * 0.10 + bob * 0.4),
        Offset(-u * 0.21, -u * 0.30), armPaint);
    canvas.drawLine(Offset(sway + u * 0.19, u * 0.10 + bob * 0.4),
        Offset(u * 0.21, -u * 0.30), armPaint);
    // gloves
    final glovePaint = Paint()..color = const Color(0xFF11131A).withOpacity(a);
    canvas.drawCircle(Offset(-u * 0.21, -u * 0.30), u * 0.055, glovePaint);
    canvas.drawCircle(Offset(u * 0.21, -u * 0.30), u * 0.055, glovePaint);

    // torso / shoulders (jacket in a lighter shade of the player color)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(sway, u * 0.14 + bob * 0.4),
            width: u * 0.46,
            height: u * 0.32),
        Radius.circular(u * 0.16),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(sway, -u * 0.02),
          Offset(sway, u * 0.30),
          [_shade(body, 70).withOpacity(a), _shade(body, 20).withOpacity(a)],
        ),
    );

    // helmet (bigger than the rider-less skin's — this IS the character)
    final head = Offset(sway * 1.3, -u * 0.02 + bob);
    canvas.drawCircle(
      head,
      u * 0.19,
      Paint()..color = const Color(0xFFF4F6FF).withOpacity(a),
    );
    // rear color stripe
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: u * 0.19),
      math.pi * 0.15,
      math.pi * 0.7,
      true,
      Paint()..color = body.withOpacity(a),
    );
    // visor, facing forward
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: u * 0.155),
      -math.pi * 0.82,
      math.pi * 0.64,
      true,
      Paint()..color = const Color(0xFF11131A).withOpacity(0.85 * a),
    );

    canvas.restore();
  }
}

/// Sport bike with a tucked racer — longer silhouette, stronger cornering
/// lean, flickering exhaust flame while moving. Premium skin.
class RiderBikeSkin implements LudoRiderSkin {
  const RiderBikeSkin();

  @override
  void paint(Canvas canvas, RiderFrame f) {
    canvas.save();
    canvas.translate(f.center.dx, f.center.dy);
    _paintRing(canvas, f);

    canvas.rotate(f.angle + f.lean * 0.4);
    if (f.phase == RiderPhase.crashing) {
      canvas.rotate(math.sin(f.timeSec * 40) * 0.15); // wobble
    }
    canvas.scale(f.scale);
    // Roll illusion: the bike narrows as it banks into a corner.
    canvas.scale(1 - f.lean.abs().clamp(0.0, 1.0) * 0.12, 1);

    final u = f.sizePx * 0.82;
    final a = f.alpha;
    final body = f.color;
    final driving = f.phase == RiderPhase.driving;
    final bob = driving
        ? math.sin(f.timeSec * 16) * u * 0.02
        : math.sin(f.timeSec * 2.2) * u * 0.01;
    final sway = -f.lean.clamp(-1.0, 1.0) * u * 0.08;

    // shadow (elongated along the bike)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: u * 0.72, height: u * 1.2),
      Paint()..color = Colors.black.withOpacity(0.30 * a),
    );

    // wheels
    final wheelPaint = Paint()..color = const Color(0xFF0D0F15).withOpacity(a);
    for (final wy in [-u * 0.44, u * 0.44]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, wy), width: u * 0.20, height: u * 0.36),
        wheelPaint,
      );
    }
    // frame line connecting the wheels
    canvas.drawLine(
      Offset(0, -u * 0.44),
      Offset(0, u * 0.44),
      Paint()
        ..color = const Color(0xFF11131A).withOpacity(a)
        ..strokeWidth = u * 0.10
        ..strokeCap = StrokeCap.round,
    );

    // exhaust flame (rear), only while driving
    if (driving) {
      final flick = 0.6 + 0.4 * math.sin(f.timeSec * 28);
      final flame = Path()
        ..moveTo(-u * 0.06, u * 0.40)
        ..lineTo(u * 0.06, u * 0.40)
        ..lineTo(0, u * (0.40 + 0.30 * flick))
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..color = const Color(0xFFFFB84D).withOpacity(0.8 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(
        flame,
        Paint()..color = const Color(0xFFFFF3B0).withOpacity(0.6 * a * flick),
      );
    }

    // fairing: nose cone → tank → tail
    final fair = Path()
      ..moveTo(0, -u * 0.46)
      ..quadraticBezierTo(u * 0.20, -u * 0.30, u * 0.16, -u * 0.02)
      ..lineTo(u * 0.14, u * 0.30)
      ..quadraticBezierTo(0, u * 0.42, -u * 0.14, u * 0.30)
      ..lineTo(-u * 0.16, -u * 0.02)
      ..quadraticBezierTo(-u * 0.20, -u * 0.30, 0, -u * 0.46)
      ..close();
    canvas.drawPath(
      fair,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -u * 0.46),
          Offset(0, u * 0.42),
          [body.withOpacity(a), _shade(body, -35).withOpacity(a)],
        ),
    );
    // tank highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -u * 0.10), width: u * 0.22, height: u * 0.26),
      Paint()..color = _shade(body, 40).withOpacity(0.7 * a),
    );

    // headlight at the nose
    canvas.drawCircle(
      Offset(0, -u * 0.44),
      u * 0.08,
      Paint()..color = const Color(0xFFFFFDE7).withOpacity(a),
    );

    // ── the rider, tucked over the tank ──
    final armPaint = Paint()
      ..color = _shade(body, 35).withOpacity(a)
      ..strokeWidth = u * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sway - u * 0.13, u * 0.06 + bob),
        Offset(-u * 0.15, -u * 0.16), armPaint);
    canvas.drawLine(Offset(sway + u * 0.13, u * 0.06 + bob),
        Offset(u * 0.15, -u * 0.16), armPaint);

    // back / torso, elongated along the bike (leaning forward)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(sway, u * 0.12 + bob * 0.5),
          width: u * 0.34,
          height: u * 0.50),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(sway, -u * 0.13),
          Offset(sway, u * 0.37),
          [_shade(body, 70).withOpacity(a), _shade(body, 15).withOpacity(a)],
        ),
    );

    // helmet, tucked forward
    final head = Offset(sway * 1.3, -u * 0.14 + bob);
    canvas.drawCircle(
      head,
      u * 0.16,
      Paint()..color = const Color(0xFFF4F6FF).withOpacity(a),
    );
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: u * 0.16),
      math.pi * 0.15,
      math.pi * 0.7,
      true,
      Paint()..color = body.withOpacity(a),
    );
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: u * 0.13),
      -math.pi * 0.82,
      math.pi * 0.64,
      true,
      Paint()..color = const Color(0xFF11131A).withOpacity(0.85 * a),
    );

    canvas.restore();
  }
}
