import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';

/// Full-screen overlay that bursts a "×2" or "×4" badge from the centre of
/// the table whenever a bid is doubled or redoubled. Renders nothing while
/// no burst is in flight.
///
/// The widget is keyed off [multiplier] + [round]: bump either to trigger
/// a new burst. The animation auto-clears after ~1.4s.
class DoublingBurst extends StatefulWidget {
  /// Current doubling multiplier (1 / 2 / 4).
  final int multiplier;

  /// Round number — included in the trigger key so a fresh round can
  /// restart from `1` without re-firing.
  final int round;

  const DoublingBurst({
    super.key,
    required this.multiplier,
    required this.round,
  });

  @override
  State<DoublingBurst> createState() => _DoublingBurstState();
}

class _DoublingBurstState extends State<DoublingBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _activeMultiplier;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    if (widget.multiplier > 1) {
      _trigger(widget.multiplier);
    }
  }

  @override
  void didUpdateWidget(covariant DoublingBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-trigger when multiplier goes UP, or when a new round starts and
    // the multiplier is already > 1 (defensive).
    final goingUp = widget.multiplier > oldWidget.multiplier;
    final newRound = widget.round != oldWidget.round;
    if ((goingUp || newRound) && widget.multiplier > 1) {
      _trigger(widget.multiplier);
    }
  }

  void _trigger(int multiplier) {
    setState(() {
      _activeMultiplier = multiplier;
    });
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _activeMultiplier = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _activeMultiplier;
    if (m == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Phase the burst in three: grow-in (0→0.35), hold (0.35→0.7),
          // fade-out (0.7→1).
          final growT = (t / 0.35).clamp(0.0, 1.0);
          final fadeT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
          final scale = 0.4 + 1.2 * Curves.easeOutBack.transform(growT);
          final opacity = 1 - fadeT;

          return Stack(
            children: [
              // Ghost cards spiralling outward.
              ..._ghostCards(t, m),
              // Center badge.
              Center(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: _BurstBadge(multiplier: m),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _ghostCards(double t, int multiplier) {
    // Two ghost cards for ×2, four for ×4 (because "redoubled" is a bigger
    // moment).
    final count = multiplier == 4 ? 4 : 2;
    final radius = 90 + 60 * Curves.easeOut.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    return List.generate(count, (i) {
      final angle = (i / count) * math.pi * 2;
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      return Center(
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: fade * 0.85,
            child: Transform.rotate(
              angle: angle + math.pi / 2,
              child: _MiniBurstCard(multiplier: multiplier),
            ),
          ),
        ),
      );
    });
  }
}

class _BurstBadge extends StatelessWidget {
  final int multiplier;

  const _BurstBadge({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final isRedouble = multiplier == 4;
    final label = isRedouble ? 'REDOUBLED' : 'DOUBLED';
    final big = '×$multiplier';
    final base =
        isRedouble ? const Color(0xFFD52F47) : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base,
            base.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(0.55),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            big,
            style: GoogleFonts.poppins(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
              shadows: const [
                Shadow(blurRadius: 12, color: Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBurstCard extends StatelessWidget {
  final int multiplier;
  const _MiniBurstCard({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final isRedouble = multiplier == 4;
    final base =
        isRedouble ? const Color(0xFFD52F47) : AppColors.accent;
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: base, width: 2),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(0.5),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '×$multiplier',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: base,
          ),
        ),
      ),
    );
  }
}
