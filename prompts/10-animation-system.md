# 09 - Animation System

> Create a comprehensive animation system for immersive gameplay experiences.

## Task

Build animation components for:
- Card dealing and distribution
- Card play and trick collection
- Bidding and trump reveal
- Turn indicators and timers
- Victory/defeat celebrations
- UI transitions and micro-interactions
- Avatar reactions and emojis

---

## Animation Architecture

```
lib/shared/animations/
├── core/
│   ├── animation_controller_mixin.dart
│   ├── animation_constants.dart
│   └── animation_curves.dart
├── cards/
│   ├── card_deal_animation.dart
│   ├── card_play_animation.dart
│   ├── card_flip_animation.dart
│   ├── card_fan_animation.dart
│   ├── trick_collect_animation.dart
│   └── shuffle_animation.dart
├── gameplay/
│   ├── turn_indicator_animation.dart
│   ├── timer_ring_animation.dart
│   ├── bid_counter_animation.dart
│   ├── trump_reveal_animation.dart
│   └── score_update_animation.dart
├── celebrations/
│   ├── confetti_animation.dart
│   ├── fireworks_animation.dart
│   ├── trophy_animation.dart
│   └── particle_system.dart
├── social/
│   ├── emoji_bubble_animation.dart
│   ├── chat_message_animation.dart
│   └── avatar_reaction_animation.dart
└── transitions/
    ├── page_transitions.dart
    ├── modal_transitions.dart
    └── list_item_animations.dart
```

---

## Animation Constants

```dart
// lib/shared/animations/core/animation_constants.dart

class AnimationDurations {
  // Card animations
  static const cardDeal = Duration(milliseconds: 300);
  static const cardDealDelay = Duration(milliseconds: 80);
  static const cardPlay = Duration(milliseconds: 250);
  static const cardFlip = Duration(milliseconds: 400);
  static const trickCollect = Duration(milliseconds: 500);
  static const shuffle = Duration(milliseconds: 800);

  // Gameplay
  static const turnIndicator = Duration(milliseconds: 600);
  static const bidCounter = Duration(milliseconds: 200);
  static const trumpReveal = Duration(milliseconds: 800);
  static const scoreUpdate = Duration(milliseconds: 400);

  // Celebrations
  static const confetti = Duration(seconds: 3);
  static const fireworks = Duration(seconds: 2);
  static const trophy = Duration(milliseconds: 1200);

  // UI
  static const pageFade = Duration(milliseconds: 300);
  static const modalSlide = Duration(milliseconds: 350);
  static const listItem = Duration(milliseconds: 250);
  static const microInteraction = Duration(milliseconds: 150);
}

class AnimationCurves {
  // Card movements
  static const cardDeal = Curves.easeOutCubic;
  static const cardPlay = Curves.easeOutBack;
  static const cardFlip = Curves.easeInOutCubic;
  static const trickCollect = Curves.easeInQuart;

  // Bouncy effects
  static const bounce = Curves.elasticOut;
  static const gentleBounce = Curves.easeOutBack;

  // Smooth transitions
  static const smooth = Curves.easeInOutCubic;
  static const smoothIn = Curves.easeInCubic;
  static const smoothOut = Curves.easeOutCubic;

  // Snappy
  static const snappy = Curves.easeOutQuart;
}
```

---

## Card Deal Animation

```dart
// lib/shared/animations/cards/card_deal_animation.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../core/animation_constants.dart';

class CardDealAnimation extends StatefulWidget {
  final int cardCount;
  final int playerCount;
  final int currentPlayerSeat;
  final double cardWidth;
  final double cardHeight;
  final Widget Function(int index) cardBuilder;
  final VoidCallback? onComplete;
  final Duration dealDuration;
  final Duration delayBetweenCards;

  const CardDealAnimation({
    super.key,
    required this.cardCount,
    required this.playerCount,
    required this.currentPlayerSeat,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardBuilder,
    this.onComplete,
    this.dealDuration = AnimationDurations.cardDeal,
    this.delayBetweenCards = AnimationDurations.cardDealDelay,
  });

  @override
  State<CardDealAnimation> createState() => _CardDealAnimationState();
}

class _CardDealAnimationState extends State<CardDealAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _positionAnimations;
  late List<Animation<double>> _rotationAnimations;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startDealingSequence();
  }

  void _initAnimations() {
    _controllers = List.generate(widget.cardCount, (index) {
      return AnimationController(
        duration: widget.dealDuration,
        vsync: this,
      );
    });

    _positionAnimations = [];
    _rotationAnimations = [];
    _scaleAnimations = [];
    _opacityAnimations = [];

    for (var i = 0; i < widget.cardCount; i++) {
      final targetOffset = _calculateTargetOffset(i);

      _positionAnimations.add(
        Tween<Offset>(
          begin: Offset.zero, // Center deck position
          end: targetOffset,
        ).animate(CurvedAnimation(
          parent: _controllers[i],
          curve: AnimationCurves.cardDeal,
        )),
      );

      _rotationAnimations.add(
        Tween<double>(
          begin: 0,
          end: _calculateTargetRotation(i),
        ).animate(CurvedAnimation(
          parent: _controllers[i],
          curve: AnimationCurves.cardDeal,
        )),
      );

      _scaleAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.8, end: 1.1),
            weight: 0.5,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.1, end: 1.0),
            weight: 0.5,
          ),
        ]).animate(CurvedAnimation(
          parent: _controllers[i],
          curve: AnimationCurves.cardDeal,
        )),
      );

      _opacityAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
          parent: _controllers[i],
          curve: const Interval(0, 0.3, curve: Curves.easeIn),
        )),
      );
    }
  }

  Offset _calculateTargetOffset(int cardIndex) {
    final playerIndex = cardIndex % widget.playerCount;
    final cardInHand = cardIndex ~/ widget.playerCount;

    // Calculate position based on player seat (0=bottom, 1=right, 2=top, 3=left)
    final seatOffset = (playerIndex - widget.currentPlayerSeat + 4) % 4;

    switch (seatOffset) {
      case 0: // Bottom (current player)
        return Offset(
          (cardInHand - 3.5) * widget.cardWidth * 0.3,
          200,
        );
      case 1: // Right
        return Offset(250, (cardInHand - 3.5) * widget.cardHeight * 0.2);
      case 2: // Top
        return Offset(
          (cardInHand - 3.5) * widget.cardWidth * 0.3,
          -200,
        );
      case 3: // Left
        return Offset(-250, (cardInHand - 3.5) * widget.cardHeight * 0.2);
      default:
        return Offset.zero;
    }
  }

  double _calculateTargetRotation(int cardIndex) {
    final playerIndex = cardIndex % widget.playerCount;
    final seatOffset = (playerIndex - widget.currentPlayerSeat + 4) % 4;

    // Cards in hand have slight rotation
    final cardInHand = cardIndex ~/ widget.playerCount;
    final fanRotation = (cardInHand - 3.5) * 0.05;

    switch (seatOffset) {
      case 0:
        return fanRotation;
      case 1:
        return pi / 2 + fanRotation;
      case 2:
        return pi + fanRotation;
      case 3:
        return -pi / 2 + fanRotation;
      default:
        return 0;
    }
  }

  void _startDealingSequence() async {
    for (var i = 0; i < widget.cardCount; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      await Future.delayed(widget.delayBetweenCards);
    }

    // Wait for last animation to complete
    await _controllers.last.forward();
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Deck (remaining cards)
        Positioned(
          child: _buildDeckStack(),
        ),

        // Dealt cards
        for (var i = 0; i < widget.cardCount; i++)
          AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, child) {
              return Transform.translate(
                offset: _positionAnimations[i].value,
                child: Transform.rotate(
                  angle: _rotationAnimations[i].value,
                  child: Transform.scale(
                    scale: _scaleAnimations[i].value,
                    child: Opacity(
                      opacity: _opacityAnimations[i].value,
                      child: widget.cardBuilder(i),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDeckStack() {
    return Stack(
      children: List.generate(5, (i) {
        return Transform.translate(
          offset: Offset(i * 0.5, i * 0.5),
          child: Container(
            width: widget.cardWidth,
            height: widget.cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue[900],
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
```

---

## Card Play Animation

```dart
// lib/shared/animations/cards/card_play_animation.dart

import 'package:flutter/material.dart';
import '../core/animation_constants.dart';

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

    // Slight rotation during flight
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

    // Shadow grows during lift
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

    // Remove old particles
    _trailParticles.removeWhere((p) => p.opacity < 0.05);
    setState(() {});
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
```

---

## Trick Collection Animation

```dart
// lib/shared/animations/cards/trick_collect_animation.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../core/animation_constants.dart';

class TrickCollectAnimation extends StatefulWidget {
  final List<Widget> cards;
  final List<Offset> cardPositions;
  final int winnerSeatIndex;
  final int currentPlayerSeat;
  final VoidCallback? onComplete;

  const TrickCollectAnimation({
    super.key,
    required this.cards,
    required this.cardPositions,
    required this.winnerSeatIndex,
    required this.currentPlayerSeat,
    this.onComplete,
  });

  @override
  State<TrickCollectAnimation> createState() => _TrickCollectAnimationState();
}

class _TrickCollectAnimationState extends State<TrickCollectAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gatherAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.trickCollect,
      vsync: this,
    );

    // Phase 1: Gather to center
    _gatherAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
    );

    // Phase 2: Slide to winner
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: AnimationCurves.trickCollect),
    );

    // Phase 3: Fade out
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    // Rotation during slide
    _rotateAnimation = Tween<double>(begin: 0, end: pi * 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getWinnerOffset() {
    final seatOffset = (widget.winnerSeatIndex - widget.currentPlayerSeat + 4) % 4;
    switch (seatOffset) {
      case 0:
        return const Offset(0, 150);
      case 1:
        return const Offset(200, 0);
      case 2:
        return const Offset(0, -150);
      case 3:
        return const Offset(-200, 0);
      default:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final winnerOffset = _getWinnerOffset();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(widget.cards.length, (index) {
            final cardPos = widget.cardPositions[index];

            // Calculate intermediate position (gathered at center)
            final gatheredPos = Offset.lerp(
              cardPos,
              Offset.zero,
              _gatherAnimation.value,
            )!;

            // Calculate final position (sliding to winner)
            final finalPos = Offset.lerp(
              gatheredPos,
              winnerOffset,
              _slideAnimation.value,
            )!;

            // Scale down as it slides away
            final scale = 1.0 - (_slideAnimation.value * 0.3);

            return Transform.translate(
              offset: finalPos,
              child: Transform.rotate(
                angle: _rotateAnimation.value,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 1.0 - _fadeAnimation.value,
                    child: widget.cards[index],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
```

---

## Trump Reveal Animation

```dart
// lib/shared/animations/gameplay/trump_reveal_animation.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../core/animation_constants.dart';

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
  List<_Particle> _particles = [];

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
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: AnimationCurves.bounce,
    ));

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
        widget.onComplete?.call();
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
        return Colors.red.shade400;
      case 'clubs':
      case 'spades':
        return Colors.grey.shade800;
      default:
        return Colors.amber;
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
                    color: _getSuitColor().withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 50 * _glowAnimation.value,
                    spreadRadius: 20 * _glowAnimation.value,
                  ),
                ],
              ),
            ),

            // Particles
            for (final particle in _particles)
              _buildParticle(particle),

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

    return Positioned(
      left: MediaQuery.of(context).size.width / 2 + x - particle.size / 2,
      top: MediaQuery.of(context).size.height / 2 + y - particle.size / 2,
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
```

---

## Turn Indicator Animation

```dart
// lib/shared/animations/gameplay/turn_indicator_animation.dart

import 'dart:math';
import 'package:flutter/material.dart';

class TurnIndicatorAnimation extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color glowColor;
  final Duration pulseDuration;

  const TurnIndicatorAnimation({
    super.key,
    required this.child,
    required this.isActive,
    this.glowColor = Colors.amber,
    this.pulseDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<TurnIndicatorAnimation> createState() => _TurnIndicatorAnimationState();
}

class _TurnIndicatorAnimationState extends State<TurnIndicatorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TurnIndicatorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating ring
            Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.transparent,
                    width: 3,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      widget.glowColor.withOpacity(0),
                      widget.glowColor,
                      widget.glowColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Pulsing glow
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // Child content
            widget.child,
          ],
        );
      },
    );
  }
}
```

---

## Confetti Celebration

```dart
// lib/shared/animations/celebrations/confetti_animation.dart

import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiAnimation extends StatefulWidget {
  final bool isPlaying;
  final int particleCount;
  final Duration duration;
  final List<Color>? colors;

  const ConfettiAnimation({
    super.key,
    required this.isPlaying,
    this.particleCount = 100,
    this.duration = const Duration(seconds: 3),
    this.colors,
  });

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  static const List<Color> _defaultColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _generateParticles();

    if (widget.isPlaying) {
      _controller.forward();
    }
  }

  void _generateParticles() {
    final colors = widget.colors ?? _defaultColors;

    _particles = List.generate(widget.particleCount, (i) {
      return _ConfettiParticle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.5,
        vx: (_random.nextDouble() - 0.5) * 2,
        vy: 2 + _random.nextDouble() * 3,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        width: 8 + _random.nextDouble() * 8,
        height: 6 + _random.nextDouble() * 6,
        color: colors[_random.nextInt(colors.length)],
        delay: _random.nextDouble() * 0.3,
      );
    });
  }

  @override
  void didUpdateWidget(ConfettiAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _generateParticles();
      _controller.forward(from: 0);
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
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double rotation;
  final double rotationSpeed;
  final double width;
  final double height;
  final Color color;
  final double delay;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Apply delay
      final effectiveProgress = ((progress - particle.delay) / (1 - particle.delay))
          .clamp(0.0, 1.0);

      if (effectiveProgress <= 0) continue;

      // Calculate position with gravity
      final gravity = 0.5;
      final t = effectiveProgress * 3; // time factor
      final x = size.width * particle.x + particle.vx * t * 50;
      final y = size.height * particle.y +
          particle.vy * t * 100 +
          gravity * t * t * 100;

      // Skip if off screen
      if (y > size.height + 50) continue;

      // Calculate rotation
      final rotation = particle.rotation + particle.rotationSpeed * t;

      // Fade out near end
      final opacity = effectiveProgress > 0.7
          ? (1 - effectiveProgress) / 0.3
          : 1.0;

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // Draw confetti shape (rectangle or ribbon)
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.height,
      );
      canvas.drawRect(rect, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
```

---

## Emoji Bubble Animation

```dart
// lib/shared/animations/social/emoji_bubble_animation.dart

import 'package:flutter/material.dart';
import '../core/animation_constants.dart';

class EmojiBubbleAnimation extends StatefulWidget {
  final String emoji;
  final Offset startPosition;
  final VoidCallback? onComplete;

  const EmojiBubbleAnimation({
    super.key,
    required this.emoji,
    required this.startPosition,
    this.onComplete,
  });

  @override
  State<EmojiBubbleAnimation> createState() => _EmojiBubbleAnimationState();
}

class _EmojiBubbleAnimationState extends State<EmojiBubbleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3),
        weight: 0.2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 0.1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8),
        weight: 0.2,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 0.1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 0.6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 0.3,
      ),
    ]).animate(_controller);

    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.startPosition + const Offset(0, -80),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) => widget.onComplete?.call());
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
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Expected Output

- Complete animation system with all card animations
- Turn indicator and timer animations
- Trump reveal with particle effects
- Victory celebrations (confetti, fireworks)
- Social animations (emoji bubbles, reactions)
- Page and modal transitions
- Performance-optimized using CustomPainter where appropriate
- Configurable durations and curves
- Integration examples for each animation type
