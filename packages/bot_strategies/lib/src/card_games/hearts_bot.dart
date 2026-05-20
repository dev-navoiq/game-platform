import 'package:game_hearts/game_hearts.dart';

import '../core/bot_player.dart';

/// Stub bot for Hearts — plays random legal moves.
/// Full strategy implementation deferred to a later session.
class HeartsBot extends BotPlayer<HeartsState, HeartsMove> {
  HeartsBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  HeartsMove? selectMove(
    HeartsState state,
    List<HeartsMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;
    return selectRandom(validMoves);
  }

  @override
  bool isComplexDecision(HeartsState state, HeartsMove move) => false;
}
