# Board Game Implementations

> **Prompt 6 of 18** | Implements Chess, Ludo, and Sequence board games using the core framework.

## Overview

This prompt creates concrete implementations for board games, leveraging the abstract `GameRules<TState, TMove>` pattern from `game_core`.

---

## Package: `game_chess`

### Directory Structure

```
packages/game_chess/
├── lib/
│   ├── game_chess.dart              # Library exports
│   └── src/
│       ├── chess_config.dart        # Game configuration
│       ├── chess_state.dart         # Game state
│       ├── chess_move.dart          # Move definitions
│       ├── chess_rules.dart         # Rule engine
│       ├── chess_piece.dart         # Piece definitions
│       ├── chess_board.dart         # Board representation
│       └── chess_notation.dart      # PGN/FEN notation
├── test/
│   ├── chess_rules_test.dart
│   ├── chess_moves_test.dart
│   └── chess_notation_test.dart
└── pubspec.yaml
```

### Chess Configuration

```dart
// lib/src/chess_config.dart
import 'package:game_core/game_core.dart';

enum ChessVariant {
  standard,
  chess960,      // Fischer Random
  threeCheck,    // Win by giving 3 checks
  kingOfTheHill, // Win by reaching center
  crazyhouse,    // Place captured pieces
}

enum ChessTimeControl {
  bullet,        // 1-2 minutes
  blitz,         // 3-5 minutes
  rapid,         // 10-30 minutes
  classical,     // 30+ minutes
  correspondence,// Days per move
}

class ChessConfig extends GameConfig {
  final ChessVariant variant;
  final int baseTimeSeconds;
  final int incrementSeconds;
  final bool allowTakeback;
  final bool showLegalMoves;
  final bool premoveEnabled;
  final bool autoQueen;          // Auto-promote to queen

  const ChessConfig({
    required this.variant,
    required this.baseTimeSeconds,
    this.incrementSeconds = 0,
    this.allowTakeback = false,
    this.showLegalMoves = true,
    this.premoveEnabled = true,
    this.autoQueen = false,
  });

  factory ChessConfig.bullet() => ChessConfig(
    variant: ChessVariant.standard,
    baseTimeSeconds: 60,
    incrementSeconds: 0,
  );

  factory ChessConfig.blitz() => ChessConfig(
    variant: ChessVariant.standard,
    baseTimeSeconds: 180,
    incrementSeconds: 2,
  );

  factory ChessConfig.rapid() => ChessConfig(
    variant: ChessVariant.standard,
    baseTimeSeconds: 600,
    incrementSeconds: 5,
  );

  @override
  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'baseTimeSeconds': baseTimeSeconds,
    'incrementSeconds': incrementSeconds,
    'allowTakeback': allowTakeback,
    'showLegalMoves': showLegalMoves,
    'premoveEnabled': premoveEnabled,
    'autoQueen': autoQueen,
  };

  factory ChessConfig.fromJson(Map<String, dynamic> json) {
    return ChessConfig(
      variant: ChessVariant.values.byName(json['variant']),
      baseTimeSeconds: json['baseTimeSeconds'],
      incrementSeconds: json['incrementSeconds'] ?? 0,
      allowTakeback: json['allowTakeback'] ?? false,
      showLegalMoves: json['showLegalMoves'] ?? true,
      premoveEnabled: json['premoveEnabled'] ?? true,
      autoQueen: json['autoQueen'] ?? false,
    );
  }
}
```

### Chess Pieces

```dart
// lib/src/chess_piece.dart
import 'package:game_core/game_core.dart';

enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  final bool hasMoved;

  const ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  ChessPiece withMoved() => ChessPiece(
    type: type,
    color: color,
    hasMoved: true,
  );

  int get value {
    switch (type) {
      case PieceType.pawn: return 1;
      case PieceType.knight: return 3;
      case PieceType.bishop: return 3;
      case PieceType.rook: return 5;
      case PieceType.queen: return 9;
      case PieceType.king: return 0; // Priceless
    }
  }

  String get symbol {
    final symbols = {
      PieceType.king: color == PieceColor.white ? '♔' : '♚',
      PieceType.queen: color == PieceColor.white ? '♕' : '♛',
      PieceType.rook: color == PieceColor.white ? '♖' : '♜',
      PieceType.bishop: color == PieceColor.white ? '♗' : '♝',
      PieceType.knight: color == PieceColor.white ? '♘' : '♞',
      PieceType.pawn: color == PieceColor.white ? '♙' : '♟',
    };
    return symbols[type]!;
  }

  String get notation {
    switch (type) {
      case PieceType.king: return 'K';
      case PieceType.queen: return 'Q';
      case PieceType.rook: return 'R';
      case PieceType.bishop: return 'B';
      case PieceType.knight: return 'N';
      case PieceType.pawn: return '';
    }
  }

  @override
  bool operator ==(Object other) =>
    other is ChessPiece &&
    type == other.type &&
    color == other.color;

  @override
  int get hashCode => Object.hash(type, color);
}
```

### Chess Board

```dart
// lib/src/chess_board.dart
import 'chess_piece.dart';

class ChessSquare {
  final int file; // 0-7 (a-h)
  final int rank; // 0-7 (1-8)

  const ChessSquare(this.file, this.rank);

  factory ChessSquare.fromNotation(String notation) {
    assert(notation.length == 2);
    final file = notation[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(notation[1]) - 1;
    return ChessSquare(file, rank);
  }

  String get notation => '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';

  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  bool get isLightSquare => (file + rank) % 2 == 1;

  ChessSquare offset(int df, int dr) => ChessSquare(file + df, rank + dr);

  @override
  bool operator ==(Object other) =>
    other is ChessSquare && file == other.file && rank == other.rank;

  @override
  int get hashCode => Object.hash(file, rank);

  @override
  String toString() => notation;
}

class ChessBoard {
  final Map<ChessSquare, ChessPiece> _pieces;

  const ChessBoard._(this._pieces);

  factory ChessBoard.initial() {
    final pieces = <ChessSquare, ChessPiece>{};

    // Place pawns
    for (var file = 0; file < 8; file++) {
      pieces[ChessSquare(file, 1)] = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
      );
      pieces[ChessSquare(file, 6)] = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
      );
    }

    // Place back rank pieces
    final backRankOrder = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook,
    ];

    for (var file = 0; file < 8; file++) {
      pieces[ChessSquare(file, 0)] = ChessPiece(
        type: backRankOrder[file],
        color: PieceColor.white,
      );
      pieces[ChessSquare(file, 7)] = ChessPiece(
        type: backRankOrder[file],
        color: PieceColor.black,
      );
    }

    return ChessBoard._(pieces);
  }

  factory ChessBoard.fromFEN(String fen) {
    final pieces = <ChessSquare, ChessPiece>{};
    final ranks = fen.split('/');

    for (var rank = 7; rank >= 0; rank--) {
      var file = 0;
      for (final char in ranks[7 - rank].split('')) {
        if (int.tryParse(char) != null) {
          file += int.parse(char);
        } else {
          final color = char == char.toUpperCase()
            ? PieceColor.white
            : PieceColor.black;
          final type = _pieceTypeFromChar(char.toLowerCase());
          pieces[ChessSquare(file, rank)] = ChessPiece(
            type: type,
            color: color,
          );
          file++;
        }
      }
    }

    return ChessBoard._(pieces);
  }

  static PieceType _pieceTypeFromChar(String char) {
    switch (char) {
      case 'k': return PieceType.king;
      case 'q': return PieceType.queen;
      case 'r': return PieceType.rook;
      case 'b': return PieceType.bishop;
      case 'n': return PieceType.knight;
      case 'p': return PieceType.pawn;
      default: throw ArgumentError('Invalid piece: $char');
    }
  }

  ChessPiece? pieceAt(ChessSquare square) => _pieces[square];

  bool isEmpty(ChessSquare square) => !_pieces.containsKey(square);

  ChessBoard withMove(ChessSquare from, ChessSquare to) {
    final newPieces = Map<ChessSquare, ChessPiece>.from(_pieces);
    final piece = newPieces.remove(from);
    if (piece != null) {
      newPieces[to] = piece.withMoved();
    }
    return ChessBoard._(newPieces);
  }

  ChessBoard withPiece(ChessSquare square, ChessPiece piece) {
    return ChessBoard._({..._pieces, square: piece});
  }

  ChessBoard withoutPiece(ChessSquare square) {
    final newPieces = Map<ChessSquare, ChessPiece>.from(_pieces);
    newPieces.remove(square);
    return ChessBoard._(newPieces);
  }

  ChessSquare? findKing(PieceColor color) {
    for (final entry in _pieces.entries) {
      if (entry.value.type == PieceType.king &&
          entry.value.color == color) {
        return entry.key;
      }
    }
    return null;
  }

  Iterable<MapEntry<ChessSquare, ChessPiece>> get pieces => _pieces.entries;

  String toFEN() {
    final buffer = StringBuffer();

    for (var rank = 7; rank >= 0; rank--) {
      var emptyCount = 0;
      for (var file = 0; file < 8; file++) {
        final piece = pieceAt(ChessSquare(file, rank));
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          var char = _charFromPieceType(piece.type);
          if (piece.color == PieceColor.white) {
            char = char.toUpperCase();
          }
          buffer.write(char);
        }
      }
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }
      if (rank > 0) buffer.write('/');
    }

    return buffer.toString();
  }

  static String _charFromPieceType(PieceType type) {
    switch (type) {
      case PieceType.king: return 'k';
      case PieceType.queen: return 'q';
      case PieceType.rook: return 'r';
      case PieceType.bishop: return 'b';
      case PieceType.knight: return 'n';
      case PieceType.pawn: return 'p';
    }
  }
}
```

### Chess State

```dart
// lib/src/chess_state.dart
import 'package:game_core/game_core.dart';
import 'chess_board.dart';
import 'chess_piece.dart';
import 'chess_move.dart';

class ChessState extends GameState {
  final ChessBoard board;
  final PieceColor activeColor;
  final CastlingRights castlingRights;
  final ChessSquare? enPassantSquare;
  final int halfmoveClock;  // For 50-move rule
  final int fullmoveNumber;
  final List<ChessMove> moveHistory;
  final Map<String, int> positionHistory;  // For threefold repetition
  final GameResult? result;

  ChessState({
    required String gameId,
    required List<String> playerIds,
    required this.board,
    required this.activeColor,
    required this.castlingRights,
    this.enPassantSquare,
    this.halfmoveClock = 0,
    this.fullmoveNumber = 1,
    this.moveHistory = const [],
    this.positionHistory = const {},
    this.result,
    GamePhase phase = GamePhase.playing,
  }) : super(gameId: gameId, playerIds: playerIds, phase: phase);

  factory ChessState.initial({
    required String gameId,
    required String whitePlayerId,
    required String blackPlayerId,
  }) {
    return ChessState(
      gameId: gameId,
      playerIds: [whitePlayerId, blackPlayerId],
      board: ChessBoard.initial(),
      activeColor: PieceColor.white,
      castlingRights: CastlingRights.initial(),
    );
  }

  String get currentPlayerId => activeColor == PieceColor.white
    ? playerIds[0]
    : playerIds[1];

  @override
  bool get isGameOver => result != null;

  bool get isCheck => _isInCheck(activeColor);

  bool get isCheckmate => isCheck && _hasNoLegalMoves();

  bool get isStalemate => !isCheck && _hasNoLegalMoves();

  bool get isDraw =>
    isStalemate ||
    _isInsufficientMaterial() ||
    _isFiftyMoveRule() ||
    _isThreefoldRepetition();

  bool _isInCheck(PieceColor color) {
    final kingSquare = board.findKing(color);
    if (kingSquare == null) return false;
    return _isSquareAttacked(kingSquare, color.opposite);
  }

  bool _isSquareAttacked(ChessSquare square, PieceColor byColor) {
    // Check for attacks from each piece type
    // Implementation details...
    return false; // Placeholder
  }

  bool _hasNoLegalMoves() {
    // Check if any legal move exists
    return false; // Placeholder
  }

  bool _isInsufficientMaterial() {
    // K vs K, K+B vs K, K+N vs K, K+B vs K+B (same color)
    return false; // Placeholder
  }

  bool _isFiftyMoveRule() => halfmoveClock >= 100;

  bool _isThreefoldRepetition() {
    final currentFEN = board.toFEN();
    return (positionHistory[currentFEN] ?? 0) >= 3;
  }

  @override
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'playerIds': playerIds,
    'board': board.toFEN(),
    'activeColor': activeColor.name,
    'castlingRights': castlingRights.toJson(),
    'enPassantSquare': enPassantSquare?.notation,
    'halfmoveClock': halfmoveClock,
    'fullmoveNumber': fullmoveNumber,
    'moveHistory': moveHistory.map((m) => m.toJson()).toList(),
    'result': result?.toJson(),
    'phase': phase.name,
  };

  ChessState copyWith({
    ChessBoard? board,
    PieceColor? activeColor,
    CastlingRights? castlingRights,
    ChessSquare? enPassantSquare,
    bool clearEnPassant = false,
    int? halfmoveClock,
    int? fullmoveNumber,
    List<ChessMove>? moveHistory,
    Map<String, int>? positionHistory,
    GameResult? result,
    GamePhase? phase,
  }) {
    return ChessState(
      gameId: gameId,
      playerIds: playerIds,
      board: board ?? this.board,
      activeColor: activeColor ?? this.activeColor,
      castlingRights: castlingRights ?? this.castlingRights,
      enPassantSquare: clearEnPassant ? null : (enPassantSquare ?? this.enPassantSquare),
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
      moveHistory: moveHistory ?? this.moveHistory,
      positionHistory: positionHistory ?? this.positionHistory,
      result: result ?? this.result,
      phase: phase ?? this.phase,
    );
  }
}

class CastlingRights {
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;

  const CastlingRights({
    required this.whiteKingside,
    required this.whiteQueenside,
    required this.blackKingside,
    required this.blackQueenside,
  });

  factory CastlingRights.initial() => const CastlingRights(
    whiteKingside: true,
    whiteQueenside: true,
    blackKingside: true,
    blackQueenside: true,
  );

  CastlingRights remove({
    bool? whiteKingside,
    bool? whiteQueenside,
    bool? blackKingside,
    bool? blackQueenside,
  }) => CastlingRights(
    whiteKingside: whiteKingside ?? this.whiteKingside,
    whiteQueenside: whiteQueenside ?? this.whiteQueenside,
    blackKingside: blackKingside ?? this.blackKingside,
    blackQueenside: blackQueenside ?? this.blackQueenside,
  );

  Map<String, dynamic> toJson() => {
    'whiteKingside': whiteKingside,
    'whiteQueenside': whiteQueenside,
    'blackKingside': blackKingside,
    'blackQueenside': blackQueenside,
  };
}

extension PieceColorExtension on PieceColor {
  PieceColor get opposite =>
    this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

class GameResult {
  final String? winnerId;
  final GameResultType type;
  final String reason;

  const GameResult({
    this.winnerId,
    required this.type,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'winnerId': winnerId,
    'type': type.name,
    'reason': reason,
  };
}

enum GameResultType { win, draw, abandoned }
```

### Chess Move

```dart
// lib/src/chess_move.dart
import 'package:game_core/game_core.dart';
import 'chess_board.dart';
import 'chess_piece.dart';

class ChessMove extends GameMove {
  final ChessSquare from;
  final ChessSquare to;
  final PieceType? promotion;
  final bool isCastling;
  final bool isEnPassant;

  ChessMove({
    required String playerId,
    required this.from,
    required this.to,
    this.promotion,
    this.isCastling = false,
    this.isEnPassant = false,
  }) : super(playerId: playerId);

  factory ChessMove.castle({
    required String playerId,
    required bool kingside,
    required PieceColor color,
  }) {
    final rank = color == PieceColor.white ? 0 : 7;
    return ChessMove(
      playerId: playerId,
      from: ChessSquare(4, rank),
      to: ChessSquare(kingside ? 6 : 2, rank),
      isCastling: true,
    );
  }

  String toAlgebraic(ChessBoard board) {
    if (isCastling) {
      return to.file > from.file ? 'O-O' : 'O-O-O';
    }

    final piece = board.pieceAt(from);
    if (piece == null) return '';

    final buffer = StringBuffer();

    // Piece notation (except pawn)
    if (piece.type != PieceType.pawn) {
      buffer.write(piece.notation);
    }

    // Capture indicator
    final isCapture = board.pieceAt(to) != null || isEnPassant;
    if (isCapture) {
      if (piece.type == PieceType.pawn) {
        buffer.write(from.notation[0]); // File for pawn captures
      }
      buffer.write('x');
    }

    // Destination square
    buffer.write(to.notation);

    // Promotion
    if (promotion != null) {
      buffer.write('=');
      buffer.write(ChessPiece(type: promotion!, color: piece.color).notation);
    }

    return buffer.toString();
  }

  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'from': from.notation,
    'to': to.notation,
    'promotion': promotion?.name,
    'isCastling': isCastling,
    'isEnPassant': isEnPassant,
  };

  factory ChessMove.fromJson(Map<String, dynamic> json) {
    return ChessMove(
      playerId: json['playerId'],
      from: ChessSquare.fromNotation(json['from']),
      to: ChessSquare.fromNotation(json['to']),
      promotion: json['promotion'] != null
        ? PieceType.values.byName(json['promotion'])
        : null,
      isCastling: json['isCastling'] ?? false,
      isEnPassant: json['isEnPassant'] ?? false,
    );
  }
}
```

### Chess Rules

```dart
// lib/src/chess_rules.dart
import 'package:game_core/game_core.dart';
import 'chess_state.dart';
import 'chess_move.dart';
import 'chess_board.dart';
import 'chess_piece.dart';
import 'chess_config.dart';

class ChessRules extends GameRules<ChessState, ChessMove> {
  final ChessConfig config;

  ChessRules(this.config);

  @override
  ChessState applyMove(ChessState state, ChessMove move) {
    var newBoard = state.board;
    var newCastling = state.castlingRights;
    ChessSquare? newEnPassant;
    var newHalfmove = state.halfmoveClock + 1;
    var newFullmove = state.fullmoveNumber;

    final piece = newBoard.pieceAt(move.from);
    if (piece == null) return state;

    // Handle castling
    if (move.isCastling) {
      newBoard = _applyCastling(newBoard, move);
      newCastling = _updateCastlingAfterKingMove(newCastling, piece.color);
    } else {
      // Regular move
      final capturedPiece = newBoard.pieceAt(move.to);

      // Handle en passant
      if (move.isEnPassant) {
        final capturedPawnSquare = ChessSquare(
          move.to.file,
          move.from.rank,
        );
        newBoard = newBoard.withoutPiece(capturedPawnSquare);
      }

      // Move the piece
      newBoard = newBoard.withMove(move.from, move.to);

      // Handle pawn promotion
      if (move.promotion != null) {
        newBoard = newBoard.withPiece(
          move.to,
          ChessPiece(type: move.promotion!, color: piece.color, hasMoved: true),
        );
      }

      // Set en passant square for double pawn push
      if (piece.type == PieceType.pawn &&
          (move.from.rank - move.to.rank).abs() == 2) {
        newEnPassant = ChessSquare(
          move.from.file,
          (move.from.rank + move.to.rank) ~/ 2,
        );
      }

      // Reset halfmove clock on pawn move or capture
      if (piece.type == PieceType.pawn || capturedPiece != null) {
        newHalfmove = 0;
      }

      // Update castling rights
      newCastling = _updateCastlingRights(newCastling, move, piece);
    }

    // Increment fullmove after black's move
    if (state.activeColor == PieceColor.black) {
      newFullmove++;
    }

    // Update position history
    final newPositionHistory = Map<String, int>.from(state.positionHistory);
    final currentFEN = newBoard.toFEN();
    newPositionHistory[currentFEN] = (newPositionHistory[currentFEN] ?? 0) + 1;

    var newState = state.copyWith(
      board: newBoard,
      activeColor: state.activeColor.opposite,
      castlingRights: newCastling,
      enPassantSquare: newEnPassant,
      clearEnPassant: newEnPassant == null,
      halfmoveClock: newHalfmove,
      fullmoveNumber: newFullmove,
      moveHistory: [...state.moveHistory, move],
      positionHistory: newPositionHistory,
    );

    // Check for game end conditions
    if (newState.isCheckmate) {
      newState = newState.copyWith(
        result: GameResult(
          winnerId: state.currentPlayerId,
          type: GameResultType.win,
          reason: 'Checkmate',
        ),
        phase: GamePhase.finished,
      );
    } else if (newState.isDraw) {
      newState = newState.copyWith(
        result: GameResult(
          type: GameResultType.draw,
          reason: _getDrawReason(newState),
        ),
        phase: GamePhase.finished,
      );
    }

    return newState;
  }

  ChessBoard _applyCastling(ChessBoard board, ChessMove move) {
    final kingside = move.to.file > move.from.file;
    final rank = move.from.rank;

    // Move king
    var newBoard = board.withMove(move.from, move.to);

    // Move rook
    final rookFrom = ChessSquare(kingside ? 7 : 0, rank);
    final rookTo = ChessSquare(kingside ? 5 : 3, rank);
    newBoard = newBoard.withMove(rookFrom, rookTo);

    return newBoard;
  }

  CastlingRights _updateCastlingAfterKingMove(
    CastlingRights rights,
    PieceColor color,
  ) {
    if (color == PieceColor.white) {
      return rights.remove(whiteKingside: false, whiteQueenside: false);
    } else {
      return rights.remove(blackKingside: false, blackQueenside: false);
    }
  }

  CastlingRights _updateCastlingRights(
    CastlingRights rights,
    ChessMove move,
    ChessPiece piece,
  ) {
    var newRights = rights;

    // King moved
    if (piece.type == PieceType.king) {
      newRights = _updateCastlingAfterKingMove(newRights, piece.color);
    }

    // Rook moved or captured
    if (piece.type == PieceType.rook || move.to == ChessSquare(0, 0)) {
      newRights = newRights.remove(whiteQueenside: false);
    }
    if (piece.type == PieceType.rook || move.to == ChessSquare(7, 0)) {
      newRights = newRights.remove(whiteKingside: false);
    }
    if (piece.type == PieceType.rook || move.to == ChessSquare(0, 7)) {
      newRights = newRights.remove(blackQueenside: false);
    }
    if (piece.type == PieceType.rook || move.to == ChessSquare(7, 7)) {
      newRights = newRights.remove(blackKingside: false);
    }

    return newRights;
  }

  String _getDrawReason(ChessState state) {
    if (state.isStalemate) return 'Stalemate';
    if (state._isThreefoldRepetition()) return 'Threefold repetition';
    if (state._isFiftyMoveRule()) return 'Fifty-move rule';
    if (state._isInsufficientMaterial()) return 'Insufficient material';
    return 'Draw';
  }

  @override
  List<ChessMove> getValidMoves(ChessState state, String playerId) {
    if (state.isGameOver) return [];
    if (state.currentPlayerId != playerId) return [];

    final moves = <ChessMove>[];
    final color = state.activeColor;

    for (final entry in state.board.pieces) {
      final square = entry.key;
      final piece = entry.value;

      if (piece.color != color) continue;

      moves.addAll(_getMovesForPiece(state, square, piece, playerId));
    }

    // Filter out moves that leave king in check
    return moves.where((move) => !_wouldLeaveKingInCheck(state, move)).toList();
  }

  List<ChessMove> _getMovesForPiece(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) {
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(state, from, piece, playerId);
      case PieceType.knight:
        return _getKnightMoves(state, from, piece, playerId);
      case PieceType.bishop:
        return _getBishopMoves(state, from, piece, playerId);
      case PieceType.rook:
        return _getRookMoves(state, from, piece, playerId);
      case PieceType.queen:
        return _getQueenMoves(state, from, piece, playerId);
      case PieceType.king:
        return _getKingMoves(state, from, piece, playerId);
    }
  }

  List<ChessMove> _getPawnMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) {
    final moves = <ChessMove>[];
    final direction = piece.color == PieceColor.white ? 1 : -1;
    final startRank = piece.color == PieceColor.white ? 1 : 6;
    final promotionRank = piece.color == PieceColor.white ? 7 : 0;

    // Forward move
    final forward = from.offset(0, direction);
    if (forward.isValid && state.board.isEmpty(forward)) {
      if (forward.rank == promotionRank) {
        for (final type in [PieceType.queen, PieceType.rook,
                           PieceType.bishop, PieceType.knight]) {
          moves.add(ChessMove(
            playerId: playerId,
            from: from,
            to: forward,
            promotion: type,
          ));
        }
      } else {
        moves.add(ChessMove(playerId: playerId, from: from, to: forward));
      }

      // Double push from start
      if (from.rank == startRank) {
        final doubleForward = from.offset(0, direction * 2);
        if (state.board.isEmpty(doubleForward)) {
          moves.add(ChessMove(playerId: playerId, from: from, to: doubleForward));
        }
      }
    }

    // Captures
    for (final df in [-1, 1]) {
      final capture = from.offset(df, direction);
      if (!capture.isValid) continue;

      final targetPiece = state.board.pieceAt(capture);
      final isEnPassant = capture == state.enPassantSquare;

      if ((targetPiece != null && targetPiece.color != piece.color) || isEnPassant) {
        if (capture.rank == promotionRank) {
          for (final type in [PieceType.queen, PieceType.rook,
                             PieceType.bishop, PieceType.knight]) {
            moves.add(ChessMove(
              playerId: playerId,
              from: from,
              to: capture,
              promotion: type,
              isEnPassant: isEnPassant,
            ));
          }
        } else {
          moves.add(ChessMove(
            playerId: playerId,
            from: from,
            to: capture,
            isEnPassant: isEnPassant,
          ));
        }
      }
    }

    return moves;
  }

  List<ChessMove> _getKnightMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) {
    final moves = <ChessMove>[];
    final offsets = [
      (-2, -1), (-2, 1), (-1, -2), (-1, 2),
      (1, -2), (1, 2), (2, -1), (2, 1),
    ];

    for (final (df, dr) in offsets) {
      final to = from.offset(df, dr);
      if (!to.isValid) continue;

      final targetPiece = state.board.pieceAt(to);
      if (targetPiece == null || targetPiece.color != piece.color) {
        moves.add(ChessMove(playerId: playerId, from: from, to: to));
      }
    }

    return moves;
  }

  List<ChessMove> _getSlidingMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
    List<(int, int)> directions,
  ) {
    final moves = <ChessMove>[];

    for (final (df, dr) in directions) {
      var to = from.offset(df, dr);
      while (to.isValid) {
        final targetPiece = state.board.pieceAt(to);
        if (targetPiece == null) {
          moves.add(ChessMove(playerId: playerId, from: from, to: to));
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(ChessMove(playerId: playerId, from: from, to: to));
          }
          break;
        }
        to = to.offset(df, dr);
      }
    }

    return moves;
  }

  List<ChessMove> _getBishopMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) => _getSlidingMoves(state, from, piece, playerId, [
    (-1, -1), (-1, 1), (1, -1), (1, 1),
  ]);

  List<ChessMove> _getRookMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) => _getSlidingMoves(state, from, piece, playerId, [
    (-1, 0), (1, 0), (0, -1), (0, 1),
  ]);

  List<ChessMove> _getQueenMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) => _getSlidingMoves(state, from, piece, playerId, [
    (-1, -1), (-1, 1), (1, -1), (1, 1),
    (-1, 0), (1, 0), (0, -1), (0, 1),
  ]);

  List<ChessMove> _getKingMoves(
    ChessState state,
    ChessSquare from,
    ChessPiece piece,
    String playerId,
  ) {
    final moves = <ChessMove>[];

    // Normal moves
    for (var df = -1; df <= 1; df++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final to = from.offset(df, dr);
        if (!to.isValid) continue;

        final targetPiece = state.board.pieceAt(to);
        if (targetPiece == null || targetPiece.color != piece.color) {
          moves.add(ChessMove(playerId: playerId, from: from, to: to));
        }
      }
    }

    // Castling
    if (!piece.hasMoved && !state.isCheck) {
      final rights = state.castlingRights;
      final rank = piece.color == PieceColor.white ? 0 : 7;

      // Kingside
      if ((piece.color == PieceColor.white && rights.whiteKingside) ||
          (piece.color == PieceColor.black && rights.blackKingside)) {
        if (_canCastleKingside(state, from, piece.color)) {
          moves.add(ChessMove.castle(
            playerId: playerId,
            kingside: true,
            color: piece.color,
          ));
        }
      }

      // Queenside
      if ((piece.color == PieceColor.white && rights.whiteQueenside) ||
          (piece.color == PieceColor.black && rights.blackQueenside)) {
        if (_canCastleQueenside(state, from, piece.color)) {
          moves.add(ChessMove.castle(
            playerId: playerId,
            kingside: false,
            color: piece.color,
          ));
        }
      }
    }

    return moves;
  }

  bool _canCastleKingside(ChessState state, ChessSquare from, PieceColor color) {
    // Check squares are empty
    final rank = from.rank;
    if (!state.board.isEmpty(ChessSquare(5, rank)) ||
        !state.board.isEmpty(ChessSquare(6, rank))) {
      return false;
    }

    // Check squares are not attacked
    return !state._isSquareAttacked(ChessSquare(4, rank), color.opposite) &&
           !state._isSquareAttacked(ChessSquare(5, rank), color.opposite) &&
           !state._isSquareAttacked(ChessSquare(6, rank), color.opposite);
  }

  bool _canCastleQueenside(ChessState state, ChessSquare from, PieceColor color) {
    final rank = from.rank;
    if (!state.board.isEmpty(ChessSquare(1, rank)) ||
        !state.board.isEmpty(ChessSquare(2, rank)) ||
        !state.board.isEmpty(ChessSquare(3, rank))) {
      return false;
    }

    return !state._isSquareAttacked(ChessSquare(2, rank), color.opposite) &&
           !state._isSquareAttacked(ChessSquare(3, rank), color.opposite) &&
           !state._isSquareAttacked(ChessSquare(4, rank), color.opposite);
  }

  bool _wouldLeaveKingInCheck(ChessState state, ChessMove move) {
    // Apply move temporarily and check if king is in check
    final newState = applyMove(state, move);
    return newState._isInCheck(state.activeColor);
  }

  @override
  bool isValidMove(ChessState state, ChessMove move) {
    return getValidMoves(state, move.playerId).any(
      (m) => m.from == move.from && m.to == move.to && m.promotion == move.promotion,
    );
  }
}
```

---

## Package: `game_ludo`

### Directory Structure

```
packages/game_ludo/
├── lib/
│   ├── game_ludo.dart
│   └── src/
│       ├── ludo_config.dart
│       ├── ludo_state.dart
│       ├── ludo_move.dart
│       ├── ludo_rules.dart
│       ├── ludo_board.dart
│       └── ludo_token.dart
├── test/
│   └── ludo_rules_test.dart
└── pubspec.yaml
```

### Ludo Configuration

```dart
// lib/src/ludo_config.dart
import 'package:game_core/game_core.dart';

enum LudoVariant {
  classic,       // Standard Ludo
  quick,         // Start with tokens out
  team,          // 2v2 partners
}

class LudoConfig extends GameConfig {
  final LudoVariant variant;
  final int playerCount;        // 2, 3, or 4
  final bool requireExactFinish;
  final bool doubleRollBonus;   // Roll again on 6
  final bool safeSquaresEnabled;
  final int tokensPerPlayer;

  const LudoConfig({
    required this.variant,
    required this.playerCount,
    this.requireExactFinish = true,
    this.doubleRollBonus = true,
    this.safeSquaresEnabled = true,
    this.tokensPerPlayer = 4,
  }) : assert(playerCount >= 2 && playerCount <= 4);

  @override
  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'playerCount': playerCount,
    'requireExactFinish': requireExactFinish,
    'doubleRollBonus': doubleRollBonus,
    'safeSquaresEnabled': safeSquaresEnabled,
    'tokensPerPlayer': tokensPerPlayer,
  };
}
```

### Ludo Board

```dart
// lib/src/ludo_board.dart
enum LudoColor { red, blue, green, yellow }

class LudoPosition {
  final LudoZone zone;
  final int index;       // Position within zone
  final LudoColor color; // For home/finish zones

  const LudoPosition.home(this.color, this.index) : zone = LudoZone.home;
  const LudoPosition.main(this.index) : zone = LudoZone.main, color = LudoColor.red;
  const LudoPosition.homeStretch(this.color, this.index) : zone = LudoZone.homeStretch;
  const LudoPosition.finish(this.color) : zone = LudoZone.finish, index = 0;

  /// Main track squares (52 total, shared by all players)
  static const int mainTrackLength = 52;

  /// Each player's home stretch (6 squares before finish)
  static const int homeStretchLength = 6;

  /// Starting positions on main track for each color
  static int startPosition(LudoColor color) {
    switch (color) {
      case LudoColor.red: return 0;
      case LudoColor.blue: return 13;
      case LudoColor.green: return 26;
      case LudoColor.yellow: return 39;
    }
  }

  /// Entry to home stretch (one before start position)
  static int homeStretchEntry(LudoColor color) {
    return (startPosition(color) + 50) % mainTrackLength;
  }

  /// Safe squares (cannot be captured)
  static final Set<int> safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  bool get isSafe => zone == LudoZone.main && safeSquares.contains(index);

  @override
  bool operator ==(Object other) =>
    other is LudoPosition &&
    zone == other.zone &&
    index == other.index &&
    (zone == LudoZone.main || color == other.color);

  @override
  int get hashCode => Object.hash(zone, index, zone == LudoZone.main ? 0 : color);
}

enum LudoZone { home, main, homeStretch, finish }
```

### Ludo Token

```dart
// lib/src/ludo_token.dart
import 'ludo_board.dart';

class LudoToken {
  final String id;
  final LudoColor color;
  final LudoPosition position;

  const LudoToken({
    required this.id,
    required this.color,
    required this.position,
  });

  bool get isAtHome => position.zone == LudoZone.home;
  bool get isInPlay => position.zone == LudoZone.main || position.zone == LudoZone.homeStretch;
  bool get isFinished => position.zone == LudoZone.finish;

  LudoToken moveTo(LudoPosition newPosition) => LudoToken(
    id: id,
    color: color,
    position: newPosition,
  );

  LudoToken sendHome() => LudoToken(
    id: id,
    color: color,
    position: LudoPosition.home(color, int.parse(id.split('_').last)),
  );
}
```

### Ludo State

```dart
// lib/src/ludo_state.dart
import 'package:game_core/game_core.dart';
import 'ludo_token.dart';
import 'ludo_board.dart';

class LudoState extends GameState {
  final Map<String, List<LudoToken>> playerTokens; // playerId -> tokens
  final Map<String, LudoColor> playerColors;
  final int currentPlayerIndex;
  final int? diceRoll;
  final int consecutiveSixes;
  final bool canRollAgain;
  final String? winnerId;
  final List<String> finishedPlayers; // Order of finish

  LudoState({
    required String gameId,
    required List<String> playerIds,
    required this.playerTokens,
    required this.playerColors,
    this.currentPlayerIndex = 0,
    this.diceRoll,
    this.consecutiveSixes = 0,
    this.canRollAgain = false,
    this.winnerId,
    this.finishedPlayers = const [],
    GamePhase phase = GamePhase.playing,
  }) : super(gameId: gameId, playerIds: playerIds, phase: phase);

  factory LudoState.initial({
    required String gameId,
    required List<String> playerIds,
    int tokensPerPlayer = 4,
  }) {
    final colors = [LudoColor.red, LudoColor.blue, LudoColor.green, LudoColor.yellow];
    final playerColors = <String, LudoColor>{};
    final playerTokens = <String, List<LudoToken>>{};

    for (var i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      final color = colors[i];
      playerColors[playerId] = color;

      playerTokens[playerId] = List.generate(
        tokensPerPlayer,
        (j) => LudoToken(
          id: '${playerId}_$j',
          color: color,
          position: LudoPosition.home(color, j),
        ),
      );
    }

    return LudoState(
      gameId: gameId,
      playerIds: playerIds,
      playerTokens: playerTokens,
      playerColors: playerColors,
    );
  }

  String get currentPlayerId => playerIds[currentPlayerIndex];

  @override
  bool get isGameOver => winnerId != null;

  List<LudoToken> getTokensAt(LudoPosition position) {
    return playerTokens.values
      .expand((tokens) => tokens)
      .where((t) => t.position == position)
      .toList();
  }

  bool hasPlayerFinished(String playerId) {
    return playerTokens[playerId]!.every((t) => t.isFinished);
  }

  @override
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'playerIds': playerIds,
    'playerTokens': playerTokens.map((k, v) => MapEntry(k, v.map((t) => {
      'id': t.id,
      'color': t.color.name,
      'position': {
        'zone': t.position.zone.name,
        'index': t.position.index,
        'color': t.position.color.name,
      },
    }).toList())),
    'playerColors': playerColors.map((k, v) => MapEntry(k, v.name)),
    'currentPlayerIndex': currentPlayerIndex,
    'diceRoll': diceRoll,
    'consecutiveSixes': consecutiveSixes,
    'canRollAgain': canRollAgain,
    'winnerId': winnerId,
    'finishedPlayers': finishedPlayers,
    'phase': phase.name,
  };

  LudoState copyWith({
    Map<String, List<LudoToken>>? playerTokens,
    int? currentPlayerIndex,
    int? diceRoll,
    bool clearDice = false,
    int? consecutiveSixes,
    bool? canRollAgain,
    String? winnerId,
    List<String>? finishedPlayers,
    GamePhase? phase,
  }) {
    return LudoState(
      gameId: gameId,
      playerIds: playerIds,
      playerTokens: playerTokens ?? this.playerTokens,
      playerColors: playerColors,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      diceRoll: clearDice ? null : (diceRoll ?? this.diceRoll),
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      canRollAgain: canRollAgain ?? this.canRollAgain,
      winnerId: winnerId ?? this.winnerId,
      finishedPlayers: finishedPlayers ?? this.finishedPlayers,
      phase: phase ?? this.phase,
    );
  }
}
```

### Ludo Move

```dart
// lib/src/ludo_move.dart
import 'package:game_core/game_core.dart';

sealed class LudoMove extends GameMove {
  LudoMove({required super.playerId});
}

class LudoRollDice extends LudoMove {
  LudoRollDice({required super.playerId});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'roll',
    'playerId': playerId,
  };
}

class LudoMoveToken extends LudoMove {
  final String tokenId;
  final int steps;

  LudoMoveToken({
    required super.playerId,
    required this.tokenId,
    required this.steps,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'move',
    'playerId': playerId,
    'tokenId': tokenId,
    'steps': steps,
  };
}

class LudoPass extends LudoMove {
  LudoPass({required super.playerId});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pass',
    'playerId': playerId,
  };
}
```

### Ludo Rules

```dart
// lib/src/ludo_rules.dart
import 'dart:math';
import 'package:game_core/game_core.dart';
import 'ludo_state.dart';
import 'ludo_move.dart';
import 'ludo_board.dart';
import 'ludo_token.dart';
import 'ludo_config.dart';

class LudoRules extends GameRules<LudoState, LudoMove> {
  final LudoConfig config;
  final Random _random;

  LudoRules(this.config, [Random? random]) : _random = random ?? Random();

  @override
  LudoState applyMove(LudoState state, LudoMove move) {
    return switch (move) {
      LudoRollDice() => _applyRoll(state, move),
      LudoMoveToken() => _applyTokenMove(state, move),
      LudoPass() => _applyPass(state, move),
    };
  }

  LudoState _applyRoll(LudoState state, LudoRollDice move) {
    final roll = _random.nextInt(6) + 1;

    // Three sixes in a row = turn ends
    if (roll == 6 && state.consecutiveSixes >= 2) {
      return state.copyWith(
        clearDice: true,
        consecutiveSixes: 0,
        canRollAgain: false,
        currentPlayerIndex: (state.currentPlayerIndex + 1) % state.playerIds.length,
      );
    }

    return state.copyWith(
      diceRoll: roll,
      consecutiveSixes: roll == 6 ? state.consecutiveSixes + 1 : 0,
      canRollAgain: roll == 6 && config.doubleRollBonus,
    );
  }

  LudoState _applyTokenMove(LudoState state, LudoMoveToken move) {
    final token = _findToken(state, move.tokenId);
    if (token == null) return state;

    final newPosition = _calculateNewPosition(token, move.steps, state.playerColors[move.playerId]!);
    if (newPosition == null) return state;

    var newTokens = _deepCopyTokens(state.playerTokens);

    // Check for capture
    if (newPosition.zone == LudoZone.main && !newPosition.isSafe) {
      final tokensAtPosition = state.getTokensAt(newPosition);
      for (final otherToken in tokensAtPosition) {
        if (otherToken.color != token.color) {
          // Send opponent token home
          newTokens = _updateToken(newTokens, otherToken.sendHome());
        }
      }
    }

    // Move token
    newTokens = _updateToken(newTokens, token.moveTo(newPosition));

    // Check if player finished
    final finishedPlayers = List<String>.from(state.finishedPlayers);
    String? winnerId = state.winnerId;
    GamePhase phase = state.phase;

    if (_hasPlayerFinished(newTokens, move.playerId) &&
        !finishedPlayers.contains(move.playerId)) {
      finishedPlayers.add(move.playerId);
      if (finishedPlayers.length == 1) {
        winnerId = move.playerId;
      }
      if (finishedPlayers.length >= state.playerIds.length - 1) {
        phase = GamePhase.finished;
      }
    }

    // Determine next player
    var nextPlayerIndex = state.currentPlayerIndex;
    if (!state.canRollAgain) {
      nextPlayerIndex = (nextPlayerIndex + 1) % state.playerIds.length;
      // Skip finished players
      while (finishedPlayers.contains(state.playerIds[nextPlayerIndex]) &&
             finishedPlayers.length < state.playerIds.length) {
        nextPlayerIndex = (nextPlayerIndex + 1) % state.playerIds.length;
      }
    }

    return state.copyWith(
      playerTokens: newTokens,
      clearDice: true,
      currentPlayerIndex: nextPlayerIndex,
      canRollAgain: state.canRollAgain,
      consecutiveSixes: state.canRollAgain ? state.consecutiveSixes : 0,
      finishedPlayers: finishedPlayers,
      winnerId: winnerId,
      phase: phase,
    );
  }

  LudoState _applyPass(LudoState state, LudoPass move) {
    return state.copyWith(
      clearDice: true,
      consecutiveSixes: 0,
      canRollAgain: false,
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.playerIds.length,
    );
  }

  LudoPosition? _calculateNewPosition(LudoToken token, int steps, LudoColor color) {
    switch (token.position.zone) {
      case LudoZone.home:
        // Need 6 to leave home
        if (steps != 6) return null;
        return LudoPosition.main(LudoPosition.startPosition(color));

      case LudoZone.main:
        var newIndex = (token.position.index + steps) % LudoPosition.mainTrackLength;

        // Check if entering home stretch
        final entry = LudoPosition.homeStretchEntry(color);
        final current = token.position.index;

        // Calculate if we pass the entry point
        final passedEntry = _passesPosition(current, newIndex, entry);
        if (passedEntry) {
          final stepsAfterEntry = (steps - _distanceTo(current, entry, LudoPosition.mainTrackLength));
          if (stepsAfterEntry <= LudoPosition.homeStretchLength) {
            return LudoPosition.homeStretch(color, stepsAfterEntry - 1);
          } else if (stepsAfterEntry == LudoPosition.homeStretchLength + 1) {
            return LudoPosition.finish(color);
          }
          return null; // Overshot
        }

        return LudoPosition.main(newIndex);

      case LudoZone.homeStretch:
        final newIndex = token.position.index + steps;
        if (newIndex < LudoPosition.homeStretchLength) {
          return LudoPosition.homeStretch(color, newIndex);
        } else if (newIndex == LudoPosition.homeStretchLength) {
          return LudoPosition.finish(color);
        }
        return null; // Overshot

      case LudoZone.finish:
        return null; // Already finished
    }
  }

  bool _passesPosition(int from, int to, int target) {
    if (from < to) {
      return target >= from && target < to;
    } else {
      return target >= from || target < to;
    }
  }

  int _distanceTo(int from, int to, int trackLength) {
    if (to >= from) {
      return to - from;
    } else {
      return trackLength - from + to;
    }
  }

  LudoToken? _findToken(LudoState state, String tokenId) {
    for (final tokens in state.playerTokens.values) {
      for (final token in tokens) {
        if (token.id == tokenId) return token;
      }
    }
    return null;
  }

  Map<String, List<LudoToken>> _deepCopyTokens(Map<String, List<LudoToken>> tokens) {
    return tokens.map((k, v) => MapEntry(k, List.from(v)));
  }

  Map<String, List<LudoToken>> _updateToken(
    Map<String, List<LudoToken>> tokens,
    LudoToken newToken,
  ) {
    final result = _deepCopyTokens(tokens);
    for (final playerId in result.keys) {
      result[playerId] = result[playerId]!.map((t) {
        if (t.id == newToken.id) return newToken;
        return t;
      }).toList();
    }
    return result;
  }

  bool _hasPlayerFinished(Map<String, List<LudoToken>> tokens, String playerId) {
    return tokens[playerId]!.every((t) => t.isFinished);
  }

  @override
  List<LudoMove> getValidMoves(LudoState state, String playerId) {
    if (state.isGameOver) return [];
    if (state.currentPlayerId != playerId) return [];

    // Need to roll first
    if (state.diceRoll == null) {
      return [LudoRollDice(playerId: playerId)];
    }

    final moves = <LudoMove>[];
    final tokens = state.playerTokens[playerId]!;
    final color = state.playerColors[playerId]!;

    for (final token in tokens) {
      final newPos = _calculateNewPosition(token, state.diceRoll!, color);
      if (newPos != null) {
        moves.add(LudoMoveToken(
          playerId: playerId,
          tokenId: token.id,
          steps: state.diceRoll!,
        ));
      }
    }

    // If no valid moves, must pass
    if (moves.isEmpty) {
      return [LudoPass(playerId: playerId)];
    }

    return moves;
  }

  @override
  bool isValidMove(LudoState state, LudoMove move) {
    return getValidMoves(state, move.playerId).any((m) {
      if (m is LudoRollDice && move is LudoRollDice) return true;
      if (m is LudoPass && move is LudoPass) return true;
      if (m is LudoMoveToken && move is LudoMoveToken) {
        return m.tokenId == move.tokenId && m.steps == move.steps;
      }
      return false;
    });
  }
}
```

---

## Package: `game_sequence`

### Overview

Sequence is a board-and-card game where players place chips on a board to create sequences of 5.

### Directory Structure

```
packages/game_sequence/
├── lib/
│   ├── game_sequence.dart
│   └── src/
│       ├── sequence_config.dart
│       ├── sequence_state.dart
│       ├── sequence_move.dart
│       ├── sequence_rules.dart
│       └── sequence_board.dart
├── test/
│   └── sequence_rules_test.dart
└── pubspec.yaml
```

### Sequence Configuration

```dart
// lib/src/sequence_config.dart
import 'package:game_core/game_core.dart';

enum SequenceVariant {
  standard,   // First to 2 sequences (2 players) or 1 sequence (3 players)
  quick,      // First to 1 sequence
  extended,   // First to 3 sequences
}

class SequenceConfig extends GameConfig {
  final SequenceVariant variant;
  final int playerCount;  // 2, 3, 4 (teams), 6 (teams)
  final int sequencesToWin;
  final bool allowRemoval;  // One-eyed jacks remove chips

  const SequenceConfig({
    required this.variant,
    required this.playerCount,
    required this.sequencesToWin,
    this.allowRemoval = true,
  });

  @override
  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'playerCount': playerCount,
    'sequencesToWin': sequencesToWin,
    'allowRemoval': allowRemoval,
  };
}
```

### Sequence Board

```dart
// lib/src/sequence_board.dart
import 'package:game_core/game_core.dart';

/// The Sequence board is 10x10 with specific card placements
class SequenceBoard {
  static const int size = 10;

  /// Corner positions are "wild" - any color can use them
  static final Set<(int, int)> corners = {
    (0, 0), (0, 9), (9, 0), (9, 9),
  };

  /// Card layout for the board (matches standard Sequence board)
  static final List<List<PlayingCard?>> cardLayout = _generateLayout();

  static List<List<PlayingCard?>> _generateLayout() {
    // Standard Sequence board layout
    // Two of each card appears on the board (two decks minus 8 Jacks)
    // Jacks are special: Two-eyed wild, One-eyed remove
    // Corners are free spaces

    // This would be the actual board layout
    // For brevity, showing structure only
    return List.generate(10, (row) =>
      List.generate(10, (col) {
        if (corners.contains((row, col))) return null;
        // Return appropriate card for position
        return null; // Placeholder - actual implementation needed
      }),
    );
  }

  final Map<(int, int), ChipColor?> chips;
  final Set<Set<(int, int)>> completedSequences;

  const SequenceBoard._({
    required this.chips,
    required this.completedSequences,
  });

  factory SequenceBoard.empty() => const SequenceBoard._(
    chips: {},
    completedSequences: {},
  );

  ChipColor? chipAt(int row, int col) => chips[(row, col)];

  bool isCorner(int row, int col) => corners.contains((row, col));

  bool isOccupied(int row, int col) =>
    chips.containsKey((row, col)) || isCorner(row, col);

  bool isPartOfSequence(int row, int col) {
    for (final seq in completedSequences) {
      if (seq.contains((row, col))) return true;
    }
    return false;
  }

  SequenceBoard placeChip(int row, int col, ChipColor color) {
    return SequenceBoard._(
      chips: {...chips, (row, col): color},
      completedSequences: completedSequences,
    );
  }

  SequenceBoard removeChip(int row, int col) {
    final newChips = Map<(int, int), ChipColor?>.from(chips);
    newChips.remove((row, col));
    return SequenceBoard._(
      chips: newChips,
      completedSequences: completedSequences,
    );
  }

  SequenceBoard withSequence(Set<(int, int)> sequence) {
    return SequenceBoard._(
      chips: chips,
      completedSequences: {...completedSequences, sequence},
    );
  }

  /// Find all positions matching a card
  List<(int, int)> findCardPositions(PlayingCard card) {
    final positions = <(int, int)>[];
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (cardLayout[row][col] == card) {
          positions.add((row, col));
        }
      }
    }
    return positions;
  }
}

enum ChipColor { red, blue, green }
```

### Sequence State

```dart
// lib/src/sequence_state.dart
import 'package:game_core/game_core.dart';
import 'sequence_board.dart';

class SequenceState extends GameState {
  final SequenceBoard board;
  final Map<String, List<PlayingCard>> playerHands;
  final Map<String, ChipColor> playerColors;
  final Map<ChipColor, int> sequenceCount;
  final Deck drawPile;
  final int currentPlayerIndex;
  final String? winnerId;

  SequenceState({
    required String gameId,
    required List<String> playerIds,
    required this.board,
    required this.playerHands,
    required this.playerColors,
    required this.sequenceCount,
    required this.drawPile,
    this.currentPlayerIndex = 0,
    this.winnerId,
    GamePhase phase = GamePhase.playing,
  }) : super(gameId: gameId, playerIds: playerIds, phase: phase);

  factory SequenceState.initial({
    required String gameId,
    required List<String> playerIds,
    int cardsPerHand = 7,
  }) {
    // Use two decks, remove Jacks (they're special)
    var deck = Deck.standard()..addAll(Deck.standard().cards);
    deck.shuffle();

    final playerHands = <String, List<PlayingCard>>{};
    final colors = [ChipColor.red, ChipColor.blue, ChipColor.green];
    final playerColors = <String, ChipColor>{};

    for (var i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      playerColors[playerId] = colors[i % colors.length];
      playerHands[playerId] = deck.drawMultiple(cardsPerHand);
    }

    return SequenceState(
      gameId: gameId,
      playerIds: playerIds,
      board: SequenceBoard.empty(),
      playerHands: playerHands,
      playerColors: playerColors,
      sequenceCount: {
        ChipColor.red: 0,
        ChipColor.blue: 0,
        ChipColor.green: 0,
      },
      drawPile: deck,
    );
  }

  String get currentPlayerId => playerIds[currentPlayerIndex];

  @override
  bool get isGameOver => winnerId != null;

  @override
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'playerIds': playerIds,
    'board': {
      'chips': board.chips.map((k, v) => MapEntry('${k.$1},${k.$2}', v?.name)),
      'sequences': board.completedSequences.map((s) =>
        s.map((p) => '${p.$1},${p.$2}').toList()
      ).toList(),
    },
    'playerHands': playerHands.map((k, v) =>
      MapEntry(k, v.map((c) => c.toJson()).toList())
    ),
    'playerColors': playerColors.map((k, v) => MapEntry(k, v.name)),
    'sequenceCount': sequenceCount.map((k, v) => MapEntry(k.name, v)),
    'drawPileSize': drawPile.remaining,
    'currentPlayerIndex': currentPlayerIndex,
    'winnerId': winnerId,
    'phase': phase.name,
  };

  SequenceState copyWith({
    SequenceBoard? board,
    Map<String, List<PlayingCard>>? playerHands,
    Map<ChipColor, int>? sequenceCount,
    Deck? drawPile,
    int? currentPlayerIndex,
    String? winnerId,
    GamePhase? phase,
  }) {
    return SequenceState(
      gameId: gameId,
      playerIds: playerIds,
      board: board ?? this.board,
      playerHands: playerHands ?? this.playerHands,
      playerColors: playerColors,
      sequenceCount: sequenceCount ?? this.sequenceCount,
      drawPile: drawPile ?? this.drawPile,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      winnerId: winnerId ?? this.winnerId,
      phase: phase ?? this.phase,
    );
  }
}
```

### Sequence Move

```dart
// lib/src/sequence_move.dart
import 'package:game_core/game_core.dart';

class SequenceMove extends GameMove {
  final PlayingCard card;
  final int row;
  final int col;
  final bool isRemoval; // One-eyed jack

  SequenceMove({
    required super.playerId,
    required this.card,
    required this.row,
    required this.col,
    this.isRemoval = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'card': card.toJson(),
    'row': row,
    'col': col,
    'isRemoval': isRemoval,
  };
}
```

### Sequence Rules

```dart
// lib/src/sequence_rules.dart
import 'package:game_core/game_core.dart';
import 'sequence_state.dart';
import 'sequence_move.dart';
import 'sequence_board.dart';
import 'sequence_config.dart';

class SequenceRules extends GameRules<SequenceState, SequenceMove> {
  final SequenceConfig config;

  SequenceRules(this.config);

  @override
  SequenceState applyMove(SequenceState state, SequenceMove move) {
    final color = state.playerColors[move.playerId]!;
    var newBoard = state.board;
    var newSequenceCount = Map<ChipColor, int>.from(state.sequenceCount);

    if (move.isRemoval) {
      // One-eyed jack removes opponent's chip
      newBoard = newBoard.removeChip(move.row, move.col);
    } else {
      // Place chip
      newBoard = newBoard.placeChip(move.row, move.col, color);

      // Check for new sequences
      final newSequences = _findNewSequences(newBoard, move.row, move.col, color);
      for (final seq in newSequences) {
        newBoard = newBoard.withSequence(seq);
        newSequenceCount[color] = (newSequenceCount[color] ?? 0) + 1;
      }
    }

    // Update hand
    final newHands = Map<String, List<PlayingCard>>.from(state.playerHands);
    newHands[move.playerId] = List.from(newHands[move.playerId]!)
      ..remove(move.card);

    // Draw new card
    final newDeck = state.drawPile;
    if (newDeck.remaining > 0) {
      newHands[move.playerId]!.add(newDeck.draw()!);
    }

    // Check for winner
    String? winnerId;
    GamePhase phase = state.phase;

    if ((newSequenceCount[color] ?? 0) >= config.sequencesToWin) {
      winnerId = move.playerId;
      phase = GamePhase.finished;
    }

    // Next player
    final nextIndex = (state.currentPlayerIndex + 1) % state.playerIds.length;

    return state.copyWith(
      board: newBoard,
      playerHands: newHands,
      sequenceCount: newSequenceCount,
      drawPile: newDeck,
      currentPlayerIndex: nextIndex,
      winnerId: winnerId,
      phase: phase,
    );
  }

  List<Set<(int, int)>> _findNewSequences(
    SequenceBoard board,
    int row,
    int col,
    ChipColor color,
  ) {
    final sequences = <Set<(int, int)>>[];
    final directions = [
      (0, 1),   // Horizontal
      (1, 0),   // Vertical
      (1, 1),   // Diagonal down-right
      (1, -1),  // Diagonal down-left
    ];

    for (final (dr, dc) in directions) {
      final sequence = _checkDirection(board, row, col, dr, dc, color);
      if (sequence != null && !_isAlreadyCompleted(board, sequence)) {
        sequences.add(sequence);
      }
    }

    return sequences;
  }

  Set<(int, int)>? _checkDirection(
    SequenceBoard board,
    int row,
    int col,
    int dr,
    int dc,
    ChipColor color,
  ) {
    final positions = <(int, int)>{};

    // Count in both directions
    for (var d = -4; d <= 4; d++) {
      final r = row + d * dr;
      final c = col + d * dc;

      if (r < 0 || r >= 10 || c < 0 || c >= 10) continue;

      final chip = board.chipAt(r, c);
      final isCorner = board.isCorner(r, c);

      if (chip == color || isCorner) {
        positions.add((r, c));
      } else {
        // Gap found, check if we have 5 in a row
        if (positions.length >= 5) {
          return positions.take(5).toSet();
        }
        positions.clear();
      }
    }

    if (positions.length >= 5) {
      return positions.take(5).toSet();
    }
    return null;
  }

  bool _isAlreadyCompleted(SequenceBoard board, Set<(int, int)> sequence) {
    for (final existing in board.completedSequences) {
      // A sequence can share at most one position with another
      if (existing.intersection(sequence).length > 1) {
        return true;
      }
    }
    return false;
  }

  @override
  List<SequenceMove> getValidMoves(SequenceState state, String playerId) {
    if (state.isGameOver) return [];
    if (state.currentPlayerId != playerId) return [];

    final moves = <SequenceMove>[];
    final hand = state.playerHands[playerId]!;
    final color = state.playerColors[playerId]!;

    for (final card in hand) {
      // Two-eyed jack (wild) - can place anywhere empty
      if (_isTwoEyedJack(card)) {
        for (var r = 0; r < 10; r++) {
          for (var c = 0; c < 10; c++) {
            if (!state.board.isOccupied(r, c)) {
              moves.add(SequenceMove(
                playerId: playerId,
                card: card,
                row: r,
                col: c,
              ));
            }
          }
        }
      }
      // One-eyed jack - remove opponent chip
      else if (_isOneEyedJack(card) && config.allowRemoval) {
        for (var r = 0; r < 10; r++) {
          for (var c = 0; c < 10; c++) {
            final chip = state.board.chipAt(r, c);
            if (chip != null &&
                chip != color &&
                !state.board.isPartOfSequence(r, c)) {
              moves.add(SequenceMove(
                playerId: playerId,
                card: card,
                row: r,
                col: c,
                isRemoval: true,
              ));
            }
          }
        }
      }
      // Regular card - place at matching position
      else {
        for (final (r, c) in state.board.findCardPositions(card)) {
          if (!state.board.isOccupied(r, c)) {
            moves.add(SequenceMove(
              playerId: playerId,
              card: card,
              row: r,
              col: c,
            ));
          }
        }
      }
    }

    return moves;
  }

  bool _isTwoEyedJack(PlayingCard card) {
    return card.rank == Rank.jack &&
           (card.suit == Suit.diamonds || card.suit == Suit.clubs);
  }

  bool _isOneEyedJack(PlayingCard card) {
    return card.rank == Rank.jack &&
           (card.suit == Suit.hearts || card.suit == Suit.spades);
  }

  @override
  bool isValidMove(SequenceState state, SequenceMove move) {
    return getValidMoves(state, move.playerId).any((m) =>
      m.card == move.card && m.row == move.row && m.col == move.col
    );
  }
}
```

---

## Tests

### Chess Rules Tests

```dart
// test/chess_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:game_chess/game_chess.dart';

void main() {
  group('ChessRules', () {
    late ChessRules rules;
    late ChessState state;

    setUp(() {
      rules = ChessRules(ChessConfig.rapid());
      state = ChessState.initial(
        gameId: 'test',
        whitePlayerId: 'white',
        blackPlayerId: 'black',
      );
    });

    test('initial position has 20 legal moves for white', () {
      final moves = rules.getValidMoves(state, 'white');
      expect(moves.length, 20); // 16 pawn moves + 4 knight moves
    });

    test('e4 is a valid opening move', () {
      final move = ChessMove(
        playerId: 'white',
        from: ChessSquare.fromNotation('e2'),
        to: ChessSquare.fromNotation('e4'),
      );
      expect(rules.isValidMove(state, move), isTrue);
    });

    test('castling is available in initial position', () {
      // Play some moves to clear path
      // ... test implementation
    });

    test('checkmate ends the game', () {
      // Set up checkmate position
      // ... test implementation
    });
  });
}
```

### Ludo Rules Tests

```dart
// test/ludo_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:game_ludo/game_ludo.dart';

void main() {
  group('LudoRules', () {
    late LudoRules rules;
    late LudoState state;

    setUp(() {
      rules = LudoRules(LudoConfig(
        variant: LudoVariant.classic,
        playerCount: 4,
      ));
      state = LudoState.initial(
        gameId: 'test',
        playerIds: ['p1', 'p2', 'p3', 'p4'],
      );
    });

    test('first move must be roll dice', () {
      final moves = rules.getValidMoves(state, 'p1');
      expect(moves.length, 1);
      expect(moves.first, isA<LudoRollDice>());
    });

    test('need 6 to leave home', () {
      // Roll something other than 6
      var newState = state.copyWith(diceRoll: 3);
      final moves = rules.getValidMoves(newState, 'p1');
      expect(moves.length, 1);
      expect(moves.first, isA<LudoPass>());
    });

    test('can leave home on 6', () {
      var newState = state.copyWith(diceRoll: 6);
      final moves = rules.getValidMoves(newState, 'p1');
      expect(moves.any((m) => m is LudoMoveToken), isTrue);
    });
  });
}
```

---

## Integration Notes

1. **Shared Assets**: Board games use shared assets from `assets/boards/`
2. **Animations**: Each game has specific animations in `09-animation-system.md`
3. **Bot Support**: See `07-bot-strategies.md` for AI implementations
4. **Multiplayer**: All games use Supabase Realtime for state sync
