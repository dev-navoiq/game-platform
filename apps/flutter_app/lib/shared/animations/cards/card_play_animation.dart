import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Animates a card moving from the player's hand to the trick zone.
class CardPlayAnimation extends StatefulWidget {
  final Widget card;
  final Offset startPosition;
  final Offset endPosition;
  final double startScale;
  final double endScale;
  final VoidCallback? onComplete;
  final bool showTrail;

  const CardPlayAnimation({
    super.key,
    required this.card,
    required this.startPosition,
    required this.endPosition,
    this.startScale = 1.0,
    this.endScale = 1.0,
    this.onComplete,
    this.showTrail = true,
  });

  @override
  State<CardPlayAnimation> createState() => _CardPlayAnimationState();
}

class _CardPlayAnimationState extends State<CardPlayAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _shadowAnimation;

  final List<_TrailParticle> _trailParticles = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.cardPlay,
      vsync: this,
    );

    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.cardPlay,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: widget.startScale, end: widget.startScale * 1.15),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.startScale * 1.15, end: widget.endScale),
        weight: 0.7,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.cardPlay,
    ));

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.1),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.1, end: 0.0),
        weight: 0.7,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _shadowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 4.0, end: 20.0),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 20.0, end: 8.0),
        weight: 0.7,
      ),
    ]).animate(_controller);

    if (widget.showTrail) {
      _controller.addListener(_generateTrail);
    }

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  void _generateTrail() {
    if (_controller.value > 0.1 && _controller.value < 0.9) {
      _trailParticles.add(_TrailParticle(
        position: _positionAnimation.value,
        opacity: (1 - _controller.value) * 0.3,
      ));
    }

    _trailParticles.removeWhere((p) => p.opacity < 0.05);
    if (mounted) setState(() {});
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
        return Stack(
          children: [
            // Trail particles
            if (widget.showTrail)
              for (final particle in _trailParticles)
                Positioned(
                  left: particle.position.dx,
                  top: particle.position.dy,
                  child: Opacity(
                    opacity: particle.opacity,
                    child: Container(
                      width: 20,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),

            // Main card
            Positioned(
              left: _positionAnimation.value.dx,
              top: _positionAnimation.value.dy,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: _shadowAnimation.value,
                          offset: Offset(0, _shadowAnimation.value / 2),
                        ),
                      ],
                    ),
                    child: widget.card,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrailParticle {
  final Offset position;
  double opacity;

  _TrailParticle({required this.position, required this.opacity});
}
