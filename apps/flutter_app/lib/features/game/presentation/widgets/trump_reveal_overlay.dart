import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../../../../shared/animations/gameplay/trump_reveal_animation.dart';

/// Full-screen overlay wrapping [TrumpRevealAnimation] for in-game use.
class TrumpRevealOverlay extends StatelessWidget {
  final Suit trumpSuit;
  final VoidCallback? onComplete;

  const TrumpRevealOverlay({
    super.key,
    required this.trumpSuit,
    this.onComplete,
  });

  String get _suitString => trumpSuit.name;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: TrumpRevealAnimation(
            suit: _suitString,
            onComplete: onComplete,
          ),
        ),
      ),
    );
  }
}
