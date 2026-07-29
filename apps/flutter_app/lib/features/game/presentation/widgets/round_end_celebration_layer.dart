import 'package:flutter/material.dart';

import '../../../../shared/animations/celebrations/confetti_animation.dart';

class RoundEndCelebrationLayer extends StatelessWidget {
  final Set<String> winnerPlayerIds;
  final Map<String, GlobalKey> seatKeys;
  final Widget child;

  const RoundEndCelebrationLayer({
    super.key,
    required this.winnerPlayerIds,
    required this.seatKeys,
    required this.child,
  });

  Rect? _globalRectOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return null;
    if (!renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: always return the same Stack > Positioned.fill > child
    // shape regardless of whether there are winners. Returning `child`
    // directly when no winners and a Stack when winners exist changes the
    // element-tree shape on the round-end transition, forcing Flutter to
    // unmount + remount the entire game body — including CardHand. That
    // destroyed CardFanAnimation's entry-animation State at every round
    // boundary; cards re-dealt in mid-animation looked like jitter.
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (winnerPlayerIds.isNotEmpty)
          for (final playerId in winnerPlayerIds)
            ..._buildWinnerOverlay(playerId),
      ],
    );
  }

  List<Widget> _buildWinnerOverlay(String playerId) {
    final key = seatKeys[playerId];
    if (key == null) return const [];
    final rect = _globalRectOf(key);
    if (rect == null) return const [];

    const confettiSize = 220.0;
    final confettiLeft = rect.center.dx - confettiSize / 2;
    final confettiTop = rect.top - confettiSize;

    return [
      Positioned(
        left: confettiLeft,
        top: confettiTop,
        width: confettiSize,
        height: confettiSize,
        child: const IgnorePointer(
          child: ConfettiAnimation(
            isPlaying: true,
            particleCount: 40,
          ),
        ),
      ),
      // Trophy cup removed by request — one celebration per seat is enough;
      // the confetti carries the moment without the clutter.
      // TODO(item-4-wiring): wrap the actual PlayerNode for `playerId` with
      // WinnerJumpAnimation (and LoserSadAnimation for non-winners). That
      // requires screen-level integration since seat widgets are owned by
      // each *_game_screen.dart and built inside SeatLayout — not reachable
      // from this overlay layer.
    ];
  }
}
