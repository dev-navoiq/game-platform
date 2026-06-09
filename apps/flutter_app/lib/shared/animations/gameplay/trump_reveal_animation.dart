import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Trump suit reveal with particle burst and glow effect.
class TrumpRevealAnimation extends StatefulWidget {
  final String suit; // 'hearts', 'diamonds', 'clubs', 'spades'
  final VoidCallback? onComplete;

  const TrumpRevealAnimation({
    super.key,
    required this.suit,
    this.onComplete,
  });

  @override
  State<TrumpRevealAnimation> createState() => _TrumpRevealAnimationState();
}

class _TrumpRevealAnimationState extends State<TrumpRevealAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;

  final Random _random = Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: AnimationDurations.trumpReveal,
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // TweenSequence's domain is strictly [0, 1] — wrapping it in
    // CurvedAnimation with an overshoot curve (elasticOut) feeds it
    // values > 1.0 and TweenSequence throws. The sequence below already
    // provides bounce (0 → 1.5 → 1.0), so use the raw controller.
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.5),
        weight: 0.4,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.0),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 0.3,
      ),
    ]).animate(_mainController);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.3),
        weight: 0.7,
      ),
    ]).animate(_mainController);

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _generateParticles();

    _mainController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onComplete?.call();
      });
    });

    _particleController.repeat();
  }

  void _generateParticles() {
    _particles = List.generate(30, (i) {
      return _Particle(
        angle: _random.nextDouble() * 2 * pi,
        speed: 50 + _random.nextDouble() * 100,
        size: 4 + _random.nextDouble() * 8,
        color: _getSuitColor(),
      );
    });
  }

  Color _getSuitColor() {
    switch (widget.suit) {
      case 'hearts':
      case 'diamonds':
        return AppColors.cardRed;
      case 'clubs':
      case 'spades':
        return AppColors.cardBlack;
      default:
        return AppColors.accent;
    }
  }

  String _getSuitSymbol() {
    switch (widget.suit) {
      case 'hearts':
        return '♥';
      case 'diamonds':
        return '♦';
      case 'clubs':
        return '♣';
      case 'spades':
        return '♠';
      default:
        return '?';
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _particleController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect
            Container(
              width: 200 * _scaleAnimation.value,
              height: 200 * _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        _getSuitColor().withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 50 * _glowAnimation.value,
                    spreadRadius: 20 * _glowAnimation.value,
                  ),
                ],
              ),
            ),

            // Particles
            for (final particle in _particles) _buildParticle(particle),

            // Suit symbol
            Transform.rotate(
              angle: _rotateAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  _getSuitSymbol(),
                  style: TextStyle(
                    fontSize: 80,
                    color: _getSuitColor(),
                    shadows: [
                      Shadow(
                        color: _getSuitColor().withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Label
            Positioned(
              bottom: 0,
              child: Opacity(
                opacity: _mainController.value > 0.5
                    ? (_mainController.value - 0.5) * 2
                    : 0,
                child: Text(
                  'TRUMP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getSuitColor(),
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticle(_Particle particle) {
    final progress = _particleController.value;
    final distance = particle.speed * progress;
    final x = cos(particle.angle) * distance;
    final y = sin(particle.angle) * distance;
    final opacity = (1 - progress) * 0.8;

    final size = MediaQuery.of(context).size;

    return Positioned(
      left: size.width / 2 + x - particle.size / 2,
      top: size.height / 2 + y - particle.size / 2,
      child: Opacity(
        opacity: opacity * _mainController.value,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: particle.color,
            boxShadow: [
              BoxShadow(
                color: particle.color.withOpacity(0.5),
                blurRadius: particle.size,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}
