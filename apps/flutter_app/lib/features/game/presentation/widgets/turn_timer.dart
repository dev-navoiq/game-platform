import 'package:flutter/material.dart';

import '../../../../shared/animations/gameplay/timer_ring_animation.dart';

/// In-game turn timer wrapping the [TimerRingAnimation].
class TurnTimer extends StatelessWidget {
  final int seconds;
  final VoidCallback? onExpired;
  final bool isVisible;

  const TurnTimer({
    super.key,
    this.seconds = 15,
    this.onExpired,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return TimerRingAnimation(
      seconds: seconds,
      onExpired: onExpired,
    );
  }
}
