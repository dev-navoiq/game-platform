import 'package:game_core/game_core.dart';
import 'package:game_sequence/game_sequence.dart';

import '../core/bot_player.dart';

/// AI player for Sequence — prioritises sequence-completing moves.
class SequenceBot extends BotPlayer<SequenceState, SequenceMove> {
  SequenceBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  SequenceMove? selectMove(
    SequenceState state,
    List<SequenceMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    if (!shouldPlayOptimally()) {
      return selectRandom(validMoves);
    }

    final myColor = state.playerColors[playerId]!;

    // Evaluate each valid move.
    var bestMove = validMoves.first;
    var bestScore = double.negativeInfinity;

    for (final move in validMoves) {
      final score = _evaluateMove(state, move, myColor);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  double _evaluateMove(
    SequenceState state,
    SequenceMove move,
    ChipColor myColor,
  ) {
    var score = 0.0;

    if (move.isRemoval) {
      // One-eyed jack removal — prioritise disrupting opponent sequences.
      score += _evaluateRemoval(state, move, myColor);
    } else {
      // Placement — prioritise completing or extending sequences.
      score += _evaluatePlacement(state, move, myColor);
    }

    return score;
  }

  double _evaluatePlacement(
    SequenceState state,
    SequenceMove move,
    ChipColor myColor,
  ) {
    var score = 0.0;

    // Check how this placement contributes to sequences.
    final friendlyInLine = _countFriendlyInLine(
      state.board,
      move.row,
      move.col,
      myColor,
    );

    // Completing a sequence (5 in a row) is the best.
    if (friendlyInLine >= 4) {
      score += 200;
    } else if (friendlyInLine == 3) {
      score += 80;
    } else if (friendlyInLine == 2) {
      score += 30;
    } else if (friendlyInLine == 1) {
      score += 10;
    }

    // Two-eyed jacks (wild placement) get a small bonus — they're flexible.
    if (_isTwoEyedJack(move.card)) {
      score += 5;
    }

    // Prefer center-ish positions.
    final centerDist = _centerDistance(move.row, move.col);
    score += (5 - centerDist).clamp(0, 5).toDouble();

    return score;
  }

  double _evaluateRemoval(
    SequenceState state,
    SequenceMove move,
    ChipColor myColor,
  ) {
    var score = 50.0; // Base value for removal.

    // Prefer removing chips that are part of a longer opponent run.
    final board = state.board;

    for (final other in ChipColor.values) {
      if (other == myColor) continue;

      final opponentRun = _countFriendlyInLine(
        board,
        move.row,
        move.col,
        other,
      );

      if (opponentRun >= 3) {
        score += 100; // Block a near-complete sequence.
      } else if (opponentRun >= 2) {
        score += 40;
      }
    }

    return score;
  }

  /// Count the maximum number of same-colour chips in a line through (row, col),
  /// including corners which count as wild for everyone.
  int _countFriendlyInLine(
    SequenceBoard board,
    int row,
    int col,
    ChipColor color,
  ) {
    const directions = [
      (0, 1), // horizontal
      (1, 0), // vertical
      (1, 1), // diagonal ↘
      (1, -1), // diagonal ↙
    ];

    var maxCount = 0;

    for (final (dr, dc) in directions) {
      var count = 1; // The cell itself.

      // Count forward.
      for (var i = 1; i < 5; i++) {
        final r = row + dr * i;
        final c = col + dc * i;
        if (r < 0 || r >= 10 || c < 0 || c >= 10) break;
        final cell = board.cellAt(r, c);
        if (cell.isCorner || cell.chip == color) {
          count++;
        } else {
          break;
        }
      }

      // Count backward.
      for (var i = 1; i < 5; i++) {
        final r = row - dr * i;
        final c = col - dc * i;
        if (r < 0 || r >= 10 || c < 0 || c >= 10) break;
        final cell = board.cellAt(r, c);
        if (cell.isCorner || cell.chip == color) {
          count++;
        } else {
          break;
        }
      }

      if (count > maxCount) maxCount = count;
    }

    return maxCount;
  }

  double _centerDistance(int row, int col) {
    final dr = (row - 4.5).abs();
    final dc = (col - 4.5).abs();
    return dr + dc;
  }

  static bool _isTwoEyedJack(PlayingCard card) =>
      card.rank == Rank.jack &&
      (card.suit == Suit.diamonds || card.suit == Suit.clubs);

  @override
  bool isComplexDecision(SequenceState state, SequenceMove move) {
    // One-eyed jack decisions are more complex (removal choices).
    return move.isRemoval;
  }
}
