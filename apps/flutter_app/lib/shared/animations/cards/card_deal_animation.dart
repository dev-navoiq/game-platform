import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Animates dealing cards from a central deck to player positions.
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
          begin: Offset.zero,
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
    final seatOffset =
        (playerIndex - widget.currentPlayerSeat + widget.playerCount) %
            widget.playerCount;

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
    final seatOffset =
        (playerIndex - widget.currentPlayerSeat + widget.playerCount) %
            widget.playerCount;
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

  Future<void> _startDealingSequence() async {
    for (var i = 0; i < widget.cardCount; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      if (i < widget.cardCount - 1) {
        await Future.delayed(widget.delayBetweenCards);
      }
    }

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
        _buildDeckStack(),

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
              color: const Color(0xFF1a1a2a),
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
