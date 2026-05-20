import 'package:game_ludo/game_ludo.dart';

import '../core/bot_player.dart';
import '../core/personality.dart';

/// AI player for Ludo — prioritises captures, finishing, and safe squares.
class LudoBot extends BotPlayer<LudoState, LudoMove> {
  LudoBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  LudoMove? selectMove(
    LudoState state,
    List<LudoMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    // Dice roll and pass are forced.
    if (validMoves.every((m) => m is LudoRollDice)) {
      return validMoves.first;
    }
    if (validMoves.every((m) => m is LudoPass)) {
      return validMoves.first;
    }

    final tokenMoves = validMoves.whereType<LudoMoveToken>().toList();
    if (tokenMoves.isEmpty) return validMoves.first;

    if (!shouldPlayOptimally()) {
      return tokenMoves[random.nextInt(tokenMoves.length)];
    }

    return _selectBestMove(state, tokenMoves);
  }

  LudoMoveToken _selectBestMove(
    LudoState state,
    List<LudoMoveToken> moves,
  ) {
    var bestMove = moves.first;
    var bestScore = double.negativeInfinity;

    for (final move in moves) {
      final score = _evaluateMove(state, move);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  double _evaluateMove(LudoState state, LudoMoveToken move) {
    var score = 0.0;

    final token = _findToken(state, move.tokenId);
    if (token == null) return score;

    final myColor = state.playerColors[playerId]!;

    // Priority 1: Would this move finish the token?
    if (_wouldFinish(token, move.steps, myColor)) {
      score += 150;
    }

    // Priority 2: Would this move capture an opponent?
    if (_wouldCapture(state, token, move.steps, myColor)) {
      score += 100;
    }

    // Priority 3: Leave home (on 6).
    if (token.isAtHome) {
      score += 80;
    }

    // Priority 4: Enter the home stretch.
    if (_wouldEnterHomeStretch(token, move.steps, myColor)) {
      score += 70;
    }

    // Priority 5: Escape danger (opponent can capture us).
    if (token.isInPlay && _isInDanger(state, token, myColor)) {
      score += 50;
    }

    // Priority 6: Land on a safe square.
    if (_wouldLandOnSafe(token, move.steps, myColor)) {
      score += 30;
    }

    // Progress bonus (prefer advancing).
    score += move.steps.toDouble();

    // Personality adjusts risk appetite.
    score *= (0.8 + personality.riskTolerance * 0.4);

    return score;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  LudoToken? _findToken(LudoState state, String tokenId) {
    return state.tokens.cast<LudoToken?>().firstWhere(
          (t) => t!.id == tokenId,
          orElse: () => null,
        );
  }

  bool _wouldFinish(LudoToken token, int steps, LudoColor color) {
    if (token.position.zone == LudoZone.homeStretch) {
      return token.position.index + steps == LudoPosition.homeStretchLength;
    }
    return false;
  }

  bool _wouldCapture(
    LudoState state,
    LudoToken token,
    int steps,
    LudoColor color,
  ) {
    final newPos = _calculateNewPosition(token, steps, color);
    if (newPos == null || newPos.zone != LudoZone.main) return false;
    if (newPos.isSafe) return false; // Can't capture on safe squares.

    final tokensAtTarget = state.tokensAtMain(newPos.index);
    return tokensAtTarget.any((t) => t.color != color);
  }

  bool _wouldEnterHomeStretch(LudoToken token, int steps, LudoColor color) {
    if (token.position.zone != LudoZone.main) return false;

    final entry = LudoPosition.homeStretchEntry(color);
    final start = LudoPosition.startPosition(color);
    final pos = token.position.index;

    // Calculate distance from start.
    final distFromStart = (pos - start + LudoPosition.mainTrackLength) %
        LudoPosition.mainTrackLength;
    final entryDist =
        (entry - start + LudoPosition.mainTrackLength) %
            LudoPosition.mainTrackLength;

    return distFromStart < entryDist &&
        distFromStart + steps > entryDist;
  }

  bool _wouldLandOnSafe(LudoToken token, int steps, LudoColor color) {
    final newPos = _calculateNewPosition(token, steps, color);
    return newPos != null && newPos.isSafe;
  }

  bool _isInDanger(LudoState state, LudoToken token, LudoColor color) {
    if (token.position.zone != LudoZone.main) return false;
    if (token.position.isSafe) return false;

    // Check if any opponent token could reach us with a roll of 1-6.
    for (final other in state.tokens) {
      if (other.color == color) continue;
      if (other.position.zone != LudoZone.main) continue;

      for (var roll = 1; roll <= 6; roll++) {
        final otherNew = _advanceOnMain(other.position.index, roll);
        if (otherNew == token.position.index) return true;
      }
    }

    return false;
  }

  int _advanceOnMain(int current, int steps) {
    return (current + steps) % LudoPosition.mainTrackLength;
  }

  LudoPosition? _calculateNewPosition(
    LudoToken token,
    int steps,
    LudoColor color,
  ) {
    if (token.isAtHome) {
      // Entering from home → start position.
      return LudoPosition.main(LudoPosition.startPosition(color));
    }

    if (token.position.zone == LudoZone.main) {
      final start = LudoPosition.startPosition(color);
      final pos = token.position.index;
      final distFromStart = (pos - start + LudoPosition.mainTrackLength) %
          LudoPosition.mainTrackLength;
      final entry = (LudoPosition.homeStretchEntry(color) - start +
              LudoPosition.mainTrackLength) %
          LudoPosition.mainTrackLength;

      if (distFromStart + steps > entry) {
        // Enters home stretch.
        final homeIndex = distFromStart + steps - entry - 1;
        if (homeIndex < LudoPosition.homeStretchLength) {
          return LudoPosition.homeStretch(color, homeIndex);
        }
        if (homeIndex == LudoPosition.homeStretchLength) {
          return LudoPosition.finish(color);
        }
        return null; // Overshoots.
      }

      return LudoPosition.main(_advanceOnMain(pos, steps));
    }

    if (token.position.zone == LudoZone.homeStretch) {
      final newIndex = token.position.index + steps;
      if (newIndex == LudoPosition.homeStretchLength) {
        return LudoPosition.finish(color);
      }
      if (newIndex < LudoPosition.homeStretchLength) {
        return LudoPosition.homeStretch(color, newIndex);
      }
      return null; // Overshoots.
    }

    return null;
  }

  @override
  bool isComplexDecision(LudoState state, LudoMove move) {
    // Complex when multiple tokens can move.
    final inPlay =
        state.tokensFor(playerId).where((t) => t.isInPlay).length;
    return inPlay > 1;
  }
}
