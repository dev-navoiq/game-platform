import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Trophy reveal with scale bounce, gold glow pulse, and sparkle particles.
class TrophyAnimation extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onComplete;

  const TrophyAnimation({
    super.key,
    required this.isPlaying,
    this.onComplete,
  });

  @override
  State<TrophyAnimation> createState() => _TrophyAnimationState();
}

class _TrophyAnimationState extends State<TrophyAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _sparkleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  final Random _random = Random();
  late List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: AnimationDurations.trophy,
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Scale: 0 → 1.2 → 1.0 (bounce)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.95),
        weight: 0.2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0),
        weight: 0.3,
      ),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOut,
    ));

    // Glow pulse
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.5), weight: 0.3),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.7), weight: 0.3),
    ]).animate(_mainController);

    _sparkles = [];

    if (widget.isPlaying) {
      _generateSparkles();
      _mainController.forward().then((_) => widget.onComplete?.call());
      _sparkleController.repeat();
    }
  }

  void _generateSparkles() {
    _sparkles = List.generate(20, (_) {
      return _Sparkle(
        angle: _random.nextDouble() * 2 * pi,
        distance: 40 + _random.nextDouble() * 50,
        size: 2 + _random.nextDouble() * 4,
        delay: _random.nextDouble(),
      );
    });
  }

  @override
  void didUpdateWidget(TrophyAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _generateSparkles();
      _mainController.forward(from: 0).then((_) => widget.onComplete?.call());
      _sparkleController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _mainController.reset();
      _sparkleController.stop();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _sparkleController]),
      builder: (context, child) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gold glow
              Container(
                width: 120 * _scaleAnimation.value,
                height: 120 * _scaleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent
                          .withOpacity(_glowAnimation.value * 0.5),
                      blurRadius: 40 * _glowAnimation.value,
                      spreadRadius: 10 * _glowAnimation.value,
                    ),
                  ],
                ),
              ),

              // Sparkles
              for (final sparkle in _sparkles) _buildSparkle(sparkle),

              // Trophy icon
              Transform.scale(
                scale: _scaleAnimation.value,
                child: const Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSparkle(_Sparkle sparkle) {
    final progress = (_sparkleController.value + sparkle.delay) % 1.0;
    final x = cos(sparkle.angle) * sparkle.distance;
    final y = sin(sparkle.angle) * sparkle.distance;
    final opacity =
        (sin(progress * pi) * _mainController.value).clamp(0.0, 1.0);

    return Positioned(
      left: 100 + x - sparkle.size / 2,
      top: 100 + y - sparkle.size / 2,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: sparkle.size,
          height: sparkle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentSoft,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentSoft.withOpacity(0.5),
                blurRadius: sparkle.size * 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}
