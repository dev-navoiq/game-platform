import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_ludo/game_ludo.dart';

import '../../../../core/theme/colors.dart';
import 'ludo_board_geometry.dart';
import 'ludo_rider_skin.dart';
import 'ludo_sponsor_branding.dart';

/// Dark board surface — scooters and colored cells pop against it.
const _boardBg = Color(0xFF0C0E14);

/// Animated Ludo board: static chrome painted from the real geometry, with
/// rider characters (scooters) driven by a ticker. It watches the authoritative
/// [LudoState] and, on each change, diffs token positions to play drive / crash
/// animations — the engine and server are never involved in presentation.
///
/// Drop-in replacement for the old LudoBoardWidget (same constructor).
class LudoAnimatedBoard extends StatefulWidget {
  final LudoState state;
  final String? selectedTokenId;
  final Set<String> movableTokenIds;
  final ValueChanged<String>? onTokenTap;
  final LudoRiderSkin skin;

  /// When set (a sponsored skin is equipped) the board gets the sponsor's
  /// accent: a faint brand-color wash plus a center-court roundel. Purely
  /// cosmetic and local, like the skin itself.
  final SponsorBranding? sponsor;

  const LudoAnimatedBoard({
    super.key,
    required this.state,
    this.selectedTokenId,
    this.movableTokenIds = const {},
    this.onTokenTap,
    this.skin = const ScooterSkin(),
    this.sponsor,
  });

  @override
  State<LudoAnimatedBoard> createState() => _LudoAnimatedBoardState();
}

class _LudoAnimatedBoardState extends State<LudoAnimatedBoard>
    with SingleTickerProviderStateMixin {
  static const _geo = LudoBoardGeometry();
  static const _driveSegment = 0.14; // seconds per cell
  static const _crashDuration = 0.55;

  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _clock = 0; // monotonic seconds, handed to skins for idle life

  /// Per-token visual state, keyed by token id.
  final Map<String, _Rider> _riders = {};

  /// Last logical token snapshot, to diff against incoming state.
  final Map<String, LudoToken> _lastLogical = {};

  static const Map<LudoColor, Color> _colors = {
    LudoColor.red: Color(0xFFEF4444),
    LudoColor.blue: Color(0xFF3B82F6),
    LudoColor.green: Color(0xFF22C55E),
    LudoColor.yellow: Color(0xFFF59E0B),
  };

  @override
  void initState() {
    super.initState();
    for (final t in widget.state.tokens) {
      _riders[t.id] = _Rider(_geo.cellForPosition(t));
      _lastLogical[t.id] = t;
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(LudoAnimatedBoard old) {
    super.didUpdateWidget(old);
    _syncFromState();
  }

  /// Diff incoming token positions vs. what we last rendered, enqueueing the
  /// right animation for each token that moved. A captured token waits for the
  /// attacker to actually reach its square before bouncing home.
  void _syncFromState() {
    // Destination cell + travel time of every drive begun this sync, so a
    // capture can be timed to the attacker's arrival.
    final drives = <({Offset dest, double duration})>[];
    final pendingCrashes = <({_Rider rider, Offset to, Offset cell})>[];

    for (final t in widget.state.tokens) {
      final prev = _lastLogical[t.id];
      _lastLogical[t.id] = t;
      final rider = _riders.putIfAbsent(
          t.id, () => _Rider(_geo.cellForPosition(t)));
      if (prev == null) {
        rider.snapTo(_geo.cellForPosition(t));
        continue;
      }
      if (_samePos(prev.position, t.position)) continue;

      final wentHome = t.position.zone == LudoZone.home &&
          (prev.position.zone == LudoZone.main ||
              prev.position.zone == LudoZone.homeStretch);
      if (wentHome) {
        // Captured — defer the bounce-home until the attacker lands on it.
        pendingCrashes.add((
          rider: rider,
          to: _geo.cellForPosition(t),
          cell: _geo.cellForPosition(prev),
        ));
      } else {
        final route = _geo.route(prev, t.position);
        rider.startDrive([rider.pos, ...route]);
        drives.add((
          dest: route.isNotEmpty ? route.last : rider.pos,
          duration: route.length * _driveSegment,
        ));
      }
    }

    for (final c in pendingCrashes) {
      var delay = 0.0;
      for (final d in drives) {
        if ((d.dest - c.cell).distanceSquared < 0.01) {
          delay = d.duration; // hold until the attacker arrives
          break;
        }
      }
      c.rider.startCrash(c.rider.pos, c.to, delay: delay);
    }
  }

  bool _samePos(LudoPosition a, LudoPosition b) =>
      a.zone == b.zone &&
      a.index == b.index &&
      (a.zone == LudoZone.main || a.color == b.color);

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final clamped = dt.clamp(0.0, 0.05); // avoid jumps after a stall
    _clock += clamped;

    final currentColor = widget.state.playerColors[widget.state.currentPlayerId];
    for (final entry in _riders.entries) {
      final token = _lastLogical[entry.key];
      final active = token != null &&
          token.color == currentColor &&
          widget.movableTokenIds.contains(entry.key);
      entry.value.advance(clamped, active: active);
    }
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _handleTap(Offset local, double cell) {
    if (widget.onTokenTap == null) return;
    String? hit;
    var best = double.infinity;
    for (final t in widget.state.tokens) {
      if (!widget.movableTokenIds.contains(t.id)) continue;
      final rider = _riders[t.id];
      if (rider == null) continue;
      final px = _geo.pixelCenter(rider.pos, cell);
      final d = (px - local).distance;
      if (d < cell * 0.7 && d < best) {
        best = d;
        hit = t.id;
      }
    }
    if (hit != null) widget.onTokenTap!(hit);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: _boardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / LudoBoardGeometry.gridSize;
              return GestureDetector(
                onTapDown: (d) => _handleTap(d.localPosition, cell),
                child: CustomPaint(
                  size: Size.square(constraints.maxWidth),
                  painter: _BoardPainter(
                    repaint: _frame,
                    state: widget.state,
                    riders: _riders,
                    geo: _geo,
                    cell: cell,
                    skin: widget.skin,
                    sponsor: widget.sponsor,
                    time: () => _clock,
                    selectedTokenId: widget.selectedTokenId,
                    movableTokenIds: widget.movableTokenIds,
                    colors: _colors,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Mutable per-token visual state + its current animation.
class _Rider {
  Offset pos; // current grid-unit position
  double angle = 0;
  double scale = 1;
  double alpha = 1;
  double spin = 0;
  double lean = 0; // smoothed turn rate, for skins that bank into corners
  RiderPhase phase = RiderPhase.idle;

  // drive
  List<Offset> _route = const [];
  int _seg = 0;
  double _segT = 0;

  // crash
  bool _crashing = false;
  Offset _crashFrom = Offset.zero;
  Offset _crashTo = Offset.zero;
  double _crashT = 0;
  double _crashDelay = 0;

  _Rider(this.pos);

  void snapTo(Offset p) {
    pos = p;
    _route = const [];
    _crashing = false;
    phase = RiderPhase.idle;
  }

  void startDrive(List<Offset> route) {
    _route = route;
    _seg = 0;
    _segT = 0;
    _crashing = false;
    phase = RiderPhase.driving;
  }

  void startCrash(Offset from, Offset to, {double delay = 0}) {
    _crashing = true;
    _crashFrom = from;
    _crashTo = to;
    _crashT = 0;
    _crashDelay = delay;
    _route = const [];
    phase = RiderPhase.crashing;
  }

  void advance(double dt, {required bool active}) {
    if (_crashing) {
      if (_crashDelay > 0) {
        _crashDelay -= dt; // hold on the square until the attacker arrives
        return;
      }
      _crashT = (_crashT + dt / _LudoAnimatedBoardState._crashDuration);
      final t = _crashT.clamp(0.0, 1.0);
      final e = 1 - math.pow(1 - t, 3).toDouble();
      pos = Offset.lerp(_crashFrom, _crashTo, e)!;
      spin = (1 - t) * 8 * math.pi;
      alpha = 0.4 + 0.6 * math.sin(t * math.pi * 2).abs();
      scale = 1 + 0.3 * math.sin(t * math.pi); // knocked-back pop
      if (t >= 1) {
        _crashing = false;
        spin = 0;
        alpha = 1;
        scale = 1;
        pos = _crashTo;
        phase = RiderPhase.idle;
      }
      return;
    }

    if (_route.length >= 2 && _seg < _route.length - 1) {
      _segT += dt / _LudoAnimatedBoardState._driveSegment;
      while (_segT >= 1 && _seg < _route.length - 1) {
        _segT -= 1;
        _seg++;
      }
      if (_seg >= _route.length - 1) {
        pos = _route.last;
        _route = const [];
        _segT = 0;
        phase = RiderPhase.idle;
        scale = 1;
      } else {
        final a = _route[_seg];
        final b = _route[_seg + 1];
        final p = _segT.clamp(0.0, 1.0);
        pos = Offset.lerp(a, b, p)!;
        final target = math.atan2(b.dy - a.dy, b.dx - a.dx) + math.pi / 2;
        final d = _angDiff(angle, target);
        angle += d * 0.35;
        lean += (d.clamp(-1.2, 1.2) - lean) * 0.3;
        scale = 1 + 0.12 * math.sin(p * math.pi); // little hop
      }
      return;
    }

    // idle — gentle pulse on the active player's movable riders
    lean *= 0.82; // straighten up after the last corner
    final pulse = active ? 1 + 0.06 * math.sin(_idleClock += dt * 5) : 1.0;
    scale += (pulse - scale) * 0.25;
  }

  double _idleClock = 0;

  static double _angDiff(double a, double b) {
    var d = b - a;
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return d;
  }
}

class _BoardPainter extends CustomPainter {
  final LudoState state;
  final Map<String, _Rider> riders;
  final LudoBoardGeometry geo;
  final double cell;
  final LudoRiderSkin skin;
  final SponsorBranding? sponsor;

  /// Getter, not a value: the painter instance outlives many ticks (it is only
  /// rebuilt on widget rebuilds) and must read the live clock on each repaint.
  final double Function() time;
  final String? selectedTokenId;
  final Set<String> movableTokenIds;
  final Map<LudoColor, Color> colors;

  _BoardPainter({
    required Listenable repaint,
    required this.state,
    required this.riders,
    required this.geo,
    required this.cell,
    required this.skin,
    this.sponsor,
    required this.time,
    required this.selectedTokenId,
    required this.movableTokenIds,
    required this.colors,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (sponsor != null) _paintSponsorWash(canvas, size);
    _paintChrome(canvas);
    if (sponsor != null) _paintSponsorRoundel(canvas);
    _paintRiders(canvas);
  }

  /// Faint radial wash of the sponsor's primary color, under the cells — the
  /// whole surface reads subtly on-brand without hurting cell contrast.
  void _paintSponsorWash(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.shortestSide * 0.72,
          [
            sponsor!.primary.withValues(alpha: 0.14),
            sponsor!.primary.withValues(alpha: 0.03),
          ],
        ),
    );
  }

  /// Center-court sponsor roundel over the pinwheel — badge text drawn, no
  /// image assets (a real deal could swap in a drawn glyph or Rive artboard).
  void _paintSponsorRoundel(Canvas canvas) {
    final s = sponsor!;
    final center = Offset(7.5 * cell, 7.5 * cell);
    final r = cell * 0.95;
    canvas.drawCircle(
        center, r, Paint()..color = s.primary.withValues(alpha: 0.92));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = s.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.09,
    );
    // Scale the wordmark down for longer badge texts so it stays inside.
    final fontSize = math.min(cell * 0.42, r * 2.6 / s.badgeText.length);
    final text = TextPainter(
      text: TextSpan(
        text: s.badgeText,
        style: TextStyle(
          color: s.secondary,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: cell * 0.03,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
        canvas, center - Offset(text.width / 2, text.height / 2));
  }

  void _paintChrome(Canvas canvas) {
    // main track cells
    for (var i = 0; i < geo.mainPath.length; i++) {
      final (c, r) = geo.mainPath[i];
      final start = _startColorAt(i);
      final fill = start != null
          ? colors[start]!.withOpacity(0.92)
          : const Color(0xFF2A3142);
      _cellRect(canvas, c.toDouble(), r.toDouble(), fill);
      if (LudoPosition.safeSquares.contains(i) && start == null) {
        _star(canvas, c.toDouble(), r.toDouble());
      }
    }

    // home columns
    for (final color in LudoColor.values) {
      for (final (c, r) in geo.homeStretchCells(color)) {
        _cellRect(canvas, c.toDouble(), r.toDouble(),
            colors[color]!.withOpacity(0.55));
      }
    }

    // home bases
    for (final color in LudoColor.values) {
      final (bx, by) = LudoBoardGeometry.baseCorner[color]!;
      final base = colors[color]!;
      final rect = Rect.fromLTWH(bx * cell, by * cell, 6 * cell, 6 * cell);
      canvas.drawRect(rect, Paint()..color = base.withOpacity(0.28));
      canvas.drawRect(
        rect,
        Paint()
          ..color = base
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final padOffset = 1.25 * cell;
      final pad = Rect.fromLTWH(bx * cell + padOffset, by * cell + padOffset,
          6 * cell - 2 * padOffset, 6 * cell - 2 * padOffset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pad, Radius.circular(cell * 0.4)),
        Paint()..color = _boardBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pad, Radius.circular(cell * 0.4)),
        Paint()
          ..color = base.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // centre pinwheel
    final cx = 7.5 * cell, cy = 7.5 * cell;
    // Each wedge matches the color whose home column feeds into it: green
    // enters from the top, yellow from the right, red from the bottom, blue
    // from the left.
    final tri = <(Offset, Offset, LudoColor)>[
      (Offset(6 * cell, 6 * cell), Offset(9 * cell, 6 * cell), LudoColor.green),
      (Offset(9 * cell, 6 * cell), Offset(9 * cell, 9 * cell), LudoColor.yellow),
      (Offset(9 * cell, 9 * cell), Offset(6 * cell, 9 * cell), LudoColor.red),
      (Offset(6 * cell, 9 * cell), Offset(6 * cell, 6 * cell), LudoColor.blue),
    ];
    for (final (a, b, color) in tri) {
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[color]!.withOpacity(0.85));
    }
  }

  void _paintRiders(Canvas canvas) {
    // home/finished riders first (under), moving riders on top
    final ordered = state.tokens.toList()
      ..sort((a, b) {
        int rank(LudoToken t) => t.isInPlay ? 1 : 0;
        return rank(a).compareTo(rank(b));
      });
    final now = time();
    for (final t in ordered) {
      final rider = riders[t.id];
      if (rider == null) continue;
      final center = geo.pixelCenter(rider.pos, cell);
      skin.paint(
        canvas,
        RiderFrame(
          center: center,
          sizePx: cell,
          angle: rider.angle + rider.spin,
          scale: rider.scale,
          alpha: rider.alpha,
          color: colors[t.color]!,
          active: false,
          selected: selectedTokenId == t.id,
          movable: movableTokenIds.contains(t.id),
          phase: rider.phase,
          // Per-token phase offset so idle head-bobs never sync up.
          timeSec: now + (t.id.hashCode % 628) / 100.0,
          lean: rider.lean,
        ),
      );
    }
  }

  LudoColor? _startColorAt(int index) {
    for (final color in LudoColor.values) {
      if (LudoPosition.startPosition(color) == index) return color;
    }
    return null;
  }

  void _cellRect(Canvas canvas, double c, double r, Color fill) {
    final rect = Rect.fromLTWH(c * cell + 1.5, r * cell + 1.5, cell - 3, cell - 3);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
        Paint()..color = fill);
  }

  void _star(Canvas canvas, double c, double r) {
    final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);
    canvas.drawCircle(
      center,
      cell * 0.16,
      Paint()..color = AppColors.accent.withOpacity(0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
