import 'dart:math';

import 'package:game_chess/game_chess.dart';

import '../core/bot_player.dart';
import '../core/difficulty.dart';

/// AI player for Chess — uses minimax with alpha-beta pruning.
class ChessBot extends BotPlayer<ChessState, ChessMove> {
  final Map<String, double> _transpositionTable = {};

  ChessBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  ChessMove? selectMove(
    ChessState state,
    List<ChessMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    // At lower difficulties, sometimes make a random move.
    if (!shouldPlayOptimally() && validMoves.length > 1) {
      return selectRandom(validMoves);
    }

    // Filter to only ChessMoveAction (don't resign).
    final actionMoves = validMoves.whereType<ChessMoveAction>().toList();
    if (actionMoves.isEmpty) return validMoves.first;

    _transpositionTable.clear();

    final depth = difficulty.searchDepth;
    final isMaximizing = _isMaximizing(state);

    ChessMoveAction? bestMove;
    var bestScore =
        isMaximizing ? double.negativeInfinity : double.infinity;
    var alpha = double.negativeInfinity;
    var beta = double.infinity;

    // Sort moves for better pruning (captures first).
    final sortedMoves = _sortMoves(state, actionMoves);

    for (final move in sortedMoves) {
      final result = ChessRules().applyMove(state, move);
      if (!result.isValid) continue;

      final score = _minimax(
        result.newState,
        depth - 1,
        alpha,
        beta,
        !isMaximizing,
      );

      if (isMaximizing) {
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
        alpha = max(alpha, score);
      } else {
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
        beta = min(beta, score);
      }
    }

    return bestMove ?? actionMoves.first;
  }

  bool _isMaximizing(ChessState state) {
    // Bot is maximizing when it's white; minimizing when black.
    return state.playerIds.indexOf(playerId) == 0;
  }

  List<ChessMoveAction> _sortMoves(
    ChessState state,
    List<ChessMoveAction> moves,
  ) {
    return moves.toList()
      ..sort((a, b) {
        final aCapture = state.board.pieceAt(a.to) != null ? 1 : 0;
        final bCapture = state.board.pieceAt(b.to) != null ? 1 : 0;
        return bCapture.compareTo(aCapture);
      });
  }

  double _minimax(
    ChessState state,
    int depth,
    double alpha,
    double beta,
    bool isMaximizing,
  ) {
    final key = '${state.board.toFEN()}_$depth';
    if (_transpositionTable.containsKey(key)) {
      return _transpositionTable[key]!;
    }

    if (depth == 0 || state.isGameOver) {
      final score = _evaluate(state);
      _transpositionTable[key] = score;
      return score;
    }

    final currentPlayerId = state.currentPlayerId;
    final rules = ChessRules();
    final moves = rules.getValidMoves(state, currentPlayerId);

    if (moves.isEmpty) {
      final score = _evaluate(state);
      _transpositionTable[key] = score;
      return score;
    }

    if (isMaximizing) {
      var maxEval = double.negativeInfinity;
      for (final move in moves) {
        final result = rules.applyMove(state, move);
        if (!result.isValid) continue;
        final eval =
            _minimax(result.newState, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      _transpositionTable[key] = maxEval;
      return maxEval;
    } else {
      var minEval = double.infinity;
      for (final move in moves) {
        final result = rules.applyMove(state, move);
        if (!result.isValid) continue;
        final eval =
            _minimax(result.newState, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      _transpositionTable[key] = minEval;
      return minEval;
    }
  }

  double _evaluate(ChessState state) {
    if (state.result != null) {
      if (state.result!.winnerId == playerId) return 10000;
      if (state.result!.winnerId != null) return -10000;
      return 0; // Draw
    }

    final myColor = state.playerIds.indexOf(playerId) == 0
        ? ChessColor.white
        : ChessColor.black;

    var score = 0.0;

    // Material count.
    for (final entry in state.board.pieces) {
      final piece = entry.value;
      final value = _pieceValue(piece.type);
      if (piece.color == myColor) {
        score += value;
      } else {
        score -= value;
      }
    }

    // Positional bonuses.
    score += _evaluatePosition(state, myColor);

    // King safety.
    score += _evaluateKingSafety(state, myColor);

    // Center control.
    score += _evaluateCenterControl(state, myColor);

    return score;
  }

  double _pieceValue(ChessPieceType type) => switch (type) {
        ChessPieceType.pawn => 100,
        ChessPieceType.knight => 320,
        ChessPieceType.bishop => 330,
        ChessPieceType.rook => 500,
        ChessPieceType.queen => 900,
        ChessPieceType.king => 0,
      };

  double _evaluatePosition(ChessState state, ChessColor color) {
    var score = 0.0;

    for (final entry in state.board.pieces) {
      if (entry.value.color != color) continue;

      final square = entry.key;
      final piece = entry.value;

      // Knights/bishops in center are strong.
      if (piece.type == ChessPieceType.knight ||
          piece.type == ChessPieceType.bishop) {
        if (square.file >= 2 &&
            square.file <= 5 &&
            square.rank >= 2 &&
            square.rank <= 5) {
          score += 20;
        }
      }

      // Rooks on open files.
      if (piece.type == ChessPieceType.rook) {
        if (_isOpenFile(state.board, square.file)) {
          score += 25;
        }
      }
    }

    return score;
  }

  bool _isOpenFile(ChessBoard board, int file) {
    for (var rank = 0; rank < 8; rank++) {
      final piece = board.pieceAt(ChessSquare(file, rank));
      if (piece?.type == ChessPieceType.pawn) return false;
    }
    return true;
  }

  double _evaluateKingSafety(ChessState state, ChessColor color) {
    final kingSquare = state.board.findKing(color);
    if (kingSquare == null) return 0;

    var safety = 0.0;

    // Castled king is safer.
    final homeRank = color == ChessColor.white ? 0 : 7;
    if (kingSquare.rank == homeRank) {
      if (kingSquare.file >= 5) safety += 30; // Kingside castled
      if (kingSquare.file <= 2) safety += 30; // Queenside castled
    }

    // Pawn shield.
    final pawnDir = color == ChessColor.white ? 1 : -1;
    for (final df in [-1, 0, 1]) {
      final sq = kingSquare.offset(df, pawnDir);
      if (!sq.isValid) continue;
      final piece = state.board.pieceAt(sq);
      if (piece?.type == ChessPieceType.pawn && piece?.color == color) {
        safety += 10;
      }
    }

    return safety;
  }

  double _evaluateCenterControl(ChessState state, ChessColor color) {
    var control = 0.0;
    const centerSquares = [
      ChessSquare(3, 3),
      ChessSquare(3, 4),
      ChessSquare(4, 3),
      ChessSquare(4, 4),
    ];

    for (final sq in centerSquares) {
      final piece = state.board.pieceAt(sq);
      if (piece != null && piece.color == color) {
        control += 15;
      }
    }

    return control;
  }

  @override
  bool isComplexDecision(ChessState state, ChessMove move) {
    // Mid-game is most complex for chess.
    final pieceCount = state.board.pieces.length;
    return pieceCount >= 10 && pieceCount <= 24;
  }
}
