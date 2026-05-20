import 'package:game_spades/game_spades.dart';

import '../core/bot_player.dart';

/// Stub bot for Spades — plays random legal moves.
/// Full strategy implementation deferred to a later session.
class SpadesBot extends BotPlayer<SpadesState, SpadesMove> {
  SpadesBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  SpadesMove? selectMove(
    SpadesState state,
    List<SpadesMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;
    return selectRandom(validMoves);
  }

  @override
  bool isComplexDecision(SpadesState state, SpadesMove move) => false;
}
