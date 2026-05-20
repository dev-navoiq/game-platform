import 'package:game_core/game_core.dart';

import 'chess_board.dart';
import 'chess_config.dart';
import 'chess_move.dart';
import 'chess_piece.dart';
import 'chess_state.dart';

class ChessRules extends GameRules<ChessState, ChessMove> {
  ChessConfig _config;

  ChessRules([ChessConfig? config]) : _config = config ?? const ChessConfig();

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  List<int> get validPlayerCounts => const [2];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _config = ChessConfig.fromJson(config);
  }

  @override
  ChessState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    assert(playerIds.length == 2, 'Chess requires exactly 2 players');
    if (serverConfig != null) applyServerConfig(serverConfig);
    // dealerIndex is ignored — white (playerIds[0]) always moves first.
    return ChessState.initial(
      whitePlayerId: playerIds[0],
      blackPlayerId: playerIds[1],
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  @override
  String? validateMove(ChessState state, ChessMove move) {
    if (state.isGameOver) return 'game_over';
    if (move is ChessResign) return null; // Always valid
    if (state.currentPlayerId != move.playerId) return 'not_your_turn';
    if (move is ChessMoveAction) {
      final legal = _legalPieceMoves(state, move.playerId);
      final isLegal = legal.any((m) =>
          m.from == move.from &&
          m.to == move.to &&
          m.promotion == move.promotion);
      if (!isLegal) return 'illegal_move';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Valid moves
  // ---------------------------------------------------------------------------

  @override
  List<ChessMove> getValidMoves(ChessState state, String playerId) {
    final moves = <ChessMove>[];
    if (state.isGameOver) return moves;
    moves.add(ChessResign(playerId: playerId));
    if (state.currentPlayerId != playerId) return moves;
    moves.addAll(_legalPieceMoves(state, playerId));
    return moves;
  }

  /// Legal piece moves for the current player (excludes resign).
  List<ChessMoveAction> _legalPieceMoves(ChessState state, String playerId) {
    final color = state.activeColor;
    final candidates = <ChessMoveAction>[];
    for (final entry in state.board.pieces) {
      if (entry.value.color != color) continue;
      candidates.addAll(_candidatesForPiece(state, entry.key, entry.value, playerId));
    }
    return candidates.where((m) => !_wouldLeaveKingInCheck(state, m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Apply move
  // ---------------------------------------------------------------------------

  @override
  MoveResult<ChessState> applyMove(ChessState state, ChessMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    if (move is ChessResign) return _applyResign(state, move);
    if (move is ChessMoveAction) return _applyMoveAction(state, move);
    return MoveResult.invalid(error: 'unknown_move_type');
  }

  MoveResult<ChessState> _applyResign(ChessState state, ChessResign move) {
    final winnerId = move.playerId == state.playerIds[0]
        ? state.playerIds[1]
        : state.playerIds[0];
    final newState = state.copyWith(
      result: ChessResult(
          winnerId: winnerId, type: ChessResultType.win, reason: 'Resignation'),
      phase: GamePhase.gameEnd,
    );
    return MoveResult.valid(newState: newState, events: [
      GameEvent(
          type: GameEventType.gameEnded,
          data: {'reason': 'resignation', 'winnerId': winnerId}),
    ]);
  }

  MoveResult<ChessState> _applyMoveAction(
      ChessState state, ChessMoveAction move) {
    var board = state.board;
    var castling = state.castlingRights;
    ChessSquare? newEnPassant;
    var halfmove = state.halfmoveClock + 1;
    var fullmove = state.fullmoveNumber;

    final piece = board.pieceAt(move.from);
    if (piece == null) return MoveResult.invalid(error: 'no_piece_at_from');

    final events = <GameEvent>[];

    if (move.isCastling) {
      board = _applyCastling(board, move);
      castling = _removeCastlingForColor(castling, piece.color);
    } else {
      final captured = board.pieceAt(move.to);

      if (move.isEnPassant) {
        board = board.withoutPiece(ChessSquare(move.to.file, move.from.rank));
      }

      board = board.withMove(move.from, move.to);

      if (move.promotion != null) {
        board = board.withPiece(
          move.to,
          ChessPiece(type: move.promotion!, color: piece.color, hasMoved: true),
        );
        events.add(GameEvent(type: GameEventType.piecePromoted, data: {
          'playerId': move.playerId,
          'to': move.to.notation,
          'promotion': move.promotion!.name,
        }));
      }

      if (captured != null || move.isEnPassant) {
        events.add(GameEvent(type: GameEventType.pieceCaptured, data: {
          'playerId': move.playerId,
          'at': move.to.notation,
        }));
      }

      // Double pawn push sets en passant square.
      if (piece.type == ChessPieceType.pawn &&
          (move.from.rank - move.to.rank).abs() == 2) {
        newEnPassant =
            ChessSquare(move.from.file, (move.from.rank + move.to.rank) ~/ 2);
      }

      // Reset 50-move clock on pawn move or capture.
      if (piece.type == ChessPieceType.pawn ||
          captured != null ||
          move.isEnPassant) {
        halfmove = 0;
      }

      castling = _updateCastlingRights(castling, move, piece);
    }

    events.add(GameEvent(type: GameEventType.pieceMoved, data: {
      'playerId': move.playerId,
      'from': move.from.notation,
      'to': move.to.notation,
    }));

    if (state.activeColor == ChessColor.black) fullmove++;

    final newPositionHistory = Map<String, int>.from(state.positionHistory);
    final fenKey = board.toFEN();
    newPositionHistory[fenKey] = (newPositionHistory[fenKey] ?? 0) + 1;

    var newState = state.copyWith(
      board: board,
      activeColor: state.activeColor.opposite,
      castlingRights: castling,
      enPassantSquare: newEnPassant,
      clearEnPassant: newEnPassant == null,
      halfmoveClock: halfmove,
      fullmoveNumber: fullmove,
      moveHistory: [...state.moveHistory, move],
      positionHistory: newPositionHistory,
      turnNumber: state.turnNumber + 1,
    );

    // ---- Game-end detection ----
    final nextColor = newState.activeColor;
    final kingSquare = newState.board.findKing(nextColor);
    final inCheck = kingSquare != null &&
        _isSquareAttacked(newState.board, kingSquare, nextColor.opposite);

    if (inCheck) {
      events.add(GameEvent(type: GameEventType.check,
          data: {'playerId': newState.currentPlayerId}));
    }

    final hasLegal = _hasAnyLegalMove(newState, newState.currentPlayerId);

    if (!hasLegal) {
      if (inCheck) {
        events.add(GameEvent(type: GameEventType.checkmate, data: {}));
        events.add(GameEvent(type: GameEventType.gameEnded,
            data: {'reason': 'checkmate', 'winnerId': move.playerId}));
        newState = newState.copyWith(
          result: ChessResult(
              winnerId: move.playerId,
              type: ChessResultType.win,
              reason: 'Checkmate'),
          phase: GamePhase.gameEnd,
        );
      } else {
        events.add(GameEvent(type: GameEventType.stalemate, data: {}));
        events.add(GameEvent(
            type: GameEventType.gameEnded, data: {'reason': 'stalemate'}));
        newState = newState.copyWith(
          result: ChessResult(type: ChessResultType.draw, reason: 'Stalemate'),
          phase: GamePhase.gameEnd,
        );
      }
    } else if (newState.halfmoveClock >= 100) {
      events.add(GameEvent(
          type: GameEventType.gameEnded,
          data: {'reason': '50_move_rule'}));
      newState = newState.copyWith(
        result:
            ChessResult(type: ChessResultType.draw, reason: '50-move rule'),
        phase: GamePhase.gameEnd,
      );
    } else if ((newPositionHistory[fenKey] ?? 0) >= 3) {
      events.add(GameEvent(
          type: GameEventType.gameEnded,
          data: {'reason': 'threefold_repetition'}));
      newState = newState.copyWith(
        result: ChessResult(
            type: ChessResultType.draw, reason: 'Threefold repetition'),
        phase: GamePhase.gameEnd,
      );
    } else if (_isInsufficientMaterial(newState.board)) {
      events.add(GameEvent(
          type: GameEventType.gameEnded,
          data: {'reason': 'insufficient_material'}));
      newState = newState.copyWith(
        result: ChessResult(
            type: ChessResultType.draw, reason: 'Insufficient material'),
        phase: GamePhase.gameEnd,
      );
    }

    return MoveResult.valid(newState: newState, events: events);
  }

  // ---------------------------------------------------------------------------
  // Game-over queries
  // ---------------------------------------------------------------------------

  @override
  bool isGameOver(ChessState state) => state.isGameOver;

  @override
  List<String> getWinners(ChessState state) {
    if (!state.isGameOver) return [];
    final r = state.result!;
    if (r.type == ChessResultType.win && r.winnerId != null) {
      return [r.winnerId!];
    }
    return [];
  }

  @override
  Map<String, int> calculateScores(ChessState state) {
    final white = state.playerIds[0];
    final black = state.playerIds[1];
    if (!state.isGameOver) return {white: 0, black: 0};
    final r = state.result!;
    if (r.type == ChessResultType.win) {
      return {
        white: r.winnerId == white ? 1 : 0,
        black: r.winnerId == black ? 1 : 0,
      };
    }
    return {white: 0, black: 0};
  }

  @override
  String? getNextPlayer(ChessState state, List<String> playerIds) {
    if (state.isGameOver) return null;
    return state.currentPlayerId;
  }

  // ---------------------------------------------------------------------------
  // Move generation helpers
  // ---------------------------------------------------------------------------

  List<ChessMoveAction> _candidatesForPiece(
      ChessState state, ChessSquare from, ChessPiece piece, String playerId) {
    switch (piece.type) {
      case ChessPieceType.pawn:
        return _pawnMoves(state, from, piece, playerId);
      case ChessPieceType.knight:
        return _knightMoves(state, from, piece, playerId);
      case ChessPieceType.bishop:
        return _slidingMoves(
            state, from, piece, playerId, [(-1, -1), (-1, 1), (1, -1), (1, 1)]);
      case ChessPieceType.rook:
        return _slidingMoves(state, from, piece, playerId,
            [(-1, 0), (1, 0), (0, -1), (0, 1)]);
      case ChessPieceType.queen:
        return _slidingMoves(state, from, piece, playerId, [
          (-1, -1),
          (-1, 1),
          (1, -1),
          (1, 1),
          (-1, 0),
          (1, 0),
          (0, -1),
          (0, 1)
        ]);
      case ChessPieceType.king:
        return _kingMoves(state, from, piece, playerId);
    }
  }

  List<ChessMoveAction> _pawnMoves(
      ChessState state, ChessSquare from, ChessPiece piece, String playerId) {
    final moves = <ChessMoveAction>[];
    final dir = piece.color == ChessColor.white ? 1 : -1;
    final startRank = piece.color == ChessColor.white ? 1 : 6;
    final promRank = piece.color == ChessColor.white ? 7 : 0;

    // Forward single step
    final fwd = from.offset(0, dir);
    if (fwd.isValid && state.board.isEmpty(fwd)) {
      if (fwd.rank == promRank) {
        for (final p in _promotionTypes) {
          moves.add(ChessMoveAction(
              playerId: playerId, from: from, to: fwd, promotion: p));
        }
      } else {
        moves.add(ChessMoveAction(playerId: playerId, from: from, to: fwd));
        // Double step from start rank
        if (from.rank == startRank) {
          final dbl = from.offset(0, dir * 2);
          if (state.board.isEmpty(dbl)) {
            moves.add(ChessMoveAction(playerId: playerId, from: from, to: dbl));
          }
        }
      }
    }

    // Diagonal captures
    for (final df in [-1, 1]) {
      final cap = from.offset(df, dir);
      if (!cap.isValid) continue;
      final target = state.board.pieceAt(cap);
      final isEP = cap == state.enPassantSquare;
      if ((target != null && target.color != piece.color) || isEP) {
        if (cap.rank == promRank) {
          for (final p in _promotionTypes) {
            moves.add(ChessMoveAction(
                playerId: playerId,
                from: from,
                to: cap,
                promotion: p,
                isEnPassant: isEP));
          }
        } else {
          moves.add(ChessMoveAction(
              playerId: playerId, from: from, to: cap, isEnPassant: isEP));
        }
      }
    }

    return moves;
  }

  List<ChessMoveAction> _knightMoves(
      ChessState state, ChessSquare from, ChessPiece piece, String playerId) {
    const offsets = [
      (-2, -1), (-2, 1), (-1, -2), (-1, 2),
      (1, -2), (1, 2), (2, -1), (2, 1),
    ];
    final moves = <ChessMoveAction>[];
    for (final (df, dr) in offsets) {
      final to = from.offset(df, dr);
      if (!to.isValid) continue;
      final target = state.board.pieceAt(to);
      if (target == null || target.color != piece.color) {
        moves.add(ChessMoveAction(playerId: playerId, from: from, to: to));
      }
    }
    return moves;
  }

  List<ChessMoveAction> _slidingMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
    List<(int, int)> directions,
  ) {
    final moves = <ChessMoveAction>[];
    for (final (df, dr) in directions) {
      var sq = from.offset(df, dr);
      while (sq.isValid) {
        final target = state.board.pieceAt(sq);
        if (target == null) {
          moves.add(ChessMoveAction(playerId: playerId, from: from, to: sq));
        } else {
          if (target.color != piece.color) {
            moves.add(ChessMoveAction(playerId: playerId, from: from, to: sq));
          }
          break;
        }
        sq = sq.offset(df, dr);
      }
    }
    return moves;
  }

  List<ChessMoveAction> _kingMoves(
      ChessState state, ChessSquare from, ChessPiece piece, String playerId) {
    final moves = <ChessMoveAction>[];
    final color = piece.color;

    // Normal one-step moves
    for (var df = -1; df <= 1; df++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final to = from.offset(df, dr);
        if (!to.isValid) continue;
        final target = state.board.pieceAt(to);
        if (target == null || target.color != color) {
          moves.add(ChessMoveAction(playerId: playerId, from: from, to: to));
        }
      }
    }

    // Castling — only if king has not moved and is not in check
    if (!piece.hasMoved &&
        !_isSquareAttacked(state.board, from, color.opposite)) {
      final rights = state.castlingRights;
      final rank = from.rank;

      final kingsideOk = color == ChessColor.white
          ? rights.whiteKingside
          : rights.blackKingside;
      if (kingsideOk && _canCastleKingside(state, rank, color)) {
        moves.add(ChessMoveAction(
            playerId: playerId,
            from: from,
            to: ChessSquare(6, rank),
            isCastling: true));
      }

      final queensideOk = color == ChessColor.white
          ? rights.whiteQueenside
          : rights.blackQueenside;
      if (queensideOk && _canCastleQueenside(state, rank, color)) {
        moves.add(ChessMoveAction(
            playerId: playerId,
            from: from,
            to: ChessSquare(2, rank),
            isCastling: true));
      }
    }

    return moves;
  }

  bool _canCastleKingside(ChessState state, int rank, ChessColor color) {
    // f1/f8 and g1/g8 must be empty
    if (!state.board.isEmpty(ChessSquare(5, rank))) return false;
    if (!state.board.isEmpty(ChessSquare(6, rank))) return false;
    // Check that rook is still there (hasMoved isn't set on board construction)
    final rook = state.board.pieceAt(ChessSquare(7, rank));
    if (rook == null ||
        rook.type != ChessPieceType.rook ||
        rook.color != color ||
        rook.hasMoved) return false;
    // King must not pass through or land on attacked squares
    final opp = color.opposite;
    return !_isSquareAttacked(state.board, ChessSquare(5, rank), opp) &&
        !_isSquareAttacked(state.board, ChessSquare(6, rank), opp);
  }

  bool _canCastleQueenside(ChessState state, int rank, ChessColor color) {
    if (!state.board.isEmpty(ChessSquare(1, rank))) return false;
    if (!state.board.isEmpty(ChessSquare(2, rank))) return false;
    if (!state.board.isEmpty(ChessSquare(3, rank))) return false;
    final rook = state.board.pieceAt(ChessSquare(0, rank));
    if (rook == null ||
        rook.type != ChessPieceType.rook ||
        rook.color != color ||
        rook.hasMoved) return false;
    final opp = color.opposite;
    return !_isSquareAttacked(state.board, ChessSquare(2, rank), opp) &&
        !_isSquareAttacked(state.board, ChessSquare(3, rank), opp);
  }

  // ---------------------------------------------------------------------------
  // Check / threat detection
  // ---------------------------------------------------------------------------

  bool _isSquareAttacked(
      ChessBoard board, ChessSquare square, ChessColor byColor) {
    // Pawn attacks: a pawn of byColor attacking [square] sits one rank "behind"
    // from byColor's forward direction and one file aside.
    final pawnDir = byColor == ChessColor.white ? -1 : 1;
    for (final df in [-1, 1]) {
      final s = square.offset(df, pawnDir);
      if (!s.isValid) continue;
      final p = board.pieceAt(s);
      if (p != null && p.color == byColor && p.type == ChessPieceType.pawn) {
        return true;
      }
    }

    // Knight attacks
    const knightOffsets = [
      (-2, -1), (-2, 1), (-1, -2), (-1, 2),
      (1, -2), (1, 2), (2, -1), (2, 1),
    ];
    for (final (df, dr) in knightOffsets) {
      final s = square.offset(df, dr);
      if (!s.isValid) continue;
      final p = board.pieceAt(s);
      if (p != null && p.color == byColor && p.type == ChessPieceType.knight) {
        return true;
      }
    }

    // King attacks (adjacent squares only)
    for (var df = -1; df <= 1; df++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final s = square.offset(df, dr);
        if (!s.isValid) continue;
        final p = board.pieceAt(s);
        if (p != null && p.color == byColor && p.type == ChessPieceType.king) {
          return true;
        }
      }
    }

    // Bishop / Queen diagonal
    for (final (df, dr) in [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      var s = square.offset(df, dr);
      while (s.isValid) {
        final p = board.pieceAt(s);
        if (p != null) {
          if (p.color == byColor &&
              (p.type == ChessPieceType.bishop ||
                  p.type == ChessPieceType.queen)) return true;
          break;
        }
        s = s.offset(df, dr);
      }
    }

    // Rook / Queen orthogonal
    for (final (df, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      var s = square.offset(df, dr);
      while (s.isValid) {
        final p = board.pieceAt(s);
        if (p != null) {
          if (p.color == byColor &&
              (p.type == ChessPieceType.rook ||
                  p.type == ChessPieceType.queen)) return true;
          break;
        }
        s = s.offset(df, dr);
      }
    }

    return false;
  }

  /// Returns true if applying [move] would leave the active color's king in check.
  bool _wouldLeaveKingInCheck(ChessState state, ChessMoveAction move) {
    var board = state.board;
    final piece = board.pieceAt(move.from);
    if (piece == null) return true;

    if (move.isCastling) {
      board = _applyCastling(board, move);
    } else {
      if (move.isEnPassant) {
        board = board.withoutPiece(ChessSquare(move.to.file, move.from.rank));
      }
      board = board.withMove(move.from, move.to);
      if (move.promotion != null) {
        board = board.withPiece(
            move.to,
            ChessPiece(
                type: move.promotion!, color: piece.color, hasMoved: true));
      }
    }

    final kingSquare = board.findKing(state.activeColor);
    if (kingSquare == null) return true;
    return _isSquareAttacked(board, kingSquare, state.activeColor.opposite);
  }

  bool _hasAnyLegalMove(ChessState state, String playerId) {
    final color = state.activeColor;
    for (final entry in state.board.pieces) {
      if (entry.value.color != color) continue;
      final candidates =
          _candidatesForPiece(state, entry.key, entry.value, playerId);
      for (final m in candidates) {
        if (!_wouldLeaveKingInCheck(state, m)) return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Castling application
  // ---------------------------------------------------------------------------

  ChessBoard _applyCastling(ChessBoard board, ChessMoveAction move) {
    final kingside = move.to.file > move.from.file;
    final rank = move.from.rank;
    var b = board.withMove(move.from, move.to);
    final rookFrom = ChessSquare(kingside ? 7 : 0, rank);
    final rookTo = ChessSquare(kingside ? 5 : 3, rank);
    return b.withMove(rookFrom, rookTo);
  }

  // ---------------------------------------------------------------------------
  // Castling rights maintenance
  // ---------------------------------------------------------------------------

  CastlingRights _updateCastlingRights(
      CastlingRights rights, ChessMoveAction move, ChessPiece piece) {
    var r = rights;
    if (piece.type == ChessPieceType.king) {
      r = _removeCastlingForColor(r, piece.color);
    }
    if (piece.type == ChessPieceType.rook) {
      if (move.from == const ChessSquare(0, 0)) {
        r = r.copyWith(whiteQueenside: false);
      } else if (move.from == const ChessSquare(7, 0)) {
        r = r.copyWith(whiteKingside: false);
      } else if (move.from == const ChessSquare(0, 7)) {
        r = r.copyWith(blackQueenside: false);
      } else if (move.from == const ChessSquare(7, 7)) {
        r = r.copyWith(blackKingside: false);
      }
    }
    // Rook captured at corner
    if (move.to == const ChessSquare(0, 0)) r = r.copyWith(whiteQueenside: false);
    if (move.to == const ChessSquare(7, 0)) r = r.copyWith(whiteKingside: false);
    if (move.to == const ChessSquare(0, 7)) r = r.copyWith(blackQueenside: false);
    if (move.to == const ChessSquare(7, 7)) r = r.copyWith(blackKingside: false);
    return r;
  }

  CastlingRights _removeCastlingForColor(
      CastlingRights rights, ChessColor color) {
    return color == ChessColor.white
        ? rights.copyWith(whiteKingside: false, whiteQueenside: false)
        : rights.copyWith(blackKingside: false, blackQueenside: false);
  }

  // ---------------------------------------------------------------------------
  // Draw conditions
  // ---------------------------------------------------------------------------

  bool _isInsufficientMaterial(ChessBoard board) {
    final white = <ChessPieceType>[];
    final black = <ChessPieceType>[];
    for (final entry in board.pieces) {
      if (entry.value.type == ChessPieceType.king) continue;
      if (entry.value.color == ChessColor.white) {
        white.add(entry.value.type);
      } else {
        black.add(entry.value.type);
      }
    }
    // K vs K
    if (white.isEmpty && black.isEmpty) return true;
    // K+B vs K or K+N vs K
    bool isMinor(List<ChessPieceType> list) =>
        list.length == 1 &&
        (list[0] == ChessPieceType.bishop || list[0] == ChessPieceType.knight);
    if (white.isEmpty && isMinor(black)) return true;
    if (black.isEmpty && isMinor(white)) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const _promotionTypes = [
    ChessPieceType.queen,
    ChessPieceType.rook,
    ChessPieceType.bishop,
    ChessPieceType.knight,
  ];
}
