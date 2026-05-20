import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import 'chess_piece.dart';

/// A square on the chess board.
/// [file] 0-7 maps to a-h; [rank] 0-7 maps to 1-8.
class ChessSquare extends Equatable {
  final int file;
  final int rank;

  const ChessSquare(this.file, this.rank);

  factory ChessSquare.fromNotation(String notation) {
    assert(notation.length == 2, 'Invalid square notation: $notation');
    final file = notation.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(notation[1]) - 1;
    return ChessSquare(file, rank);
  }

  String get notation =>
      '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';

  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  ChessSquare offset(int df, int dr) => ChessSquare(file + df, rank + dr);

  @override
  List<Object?> get props => [file, rank];

  @override
  String toString() => notation;
}

/// Immutable chess board — a snapshot of where all pieces are.
class ChessBoard extends Equatable {
  final Map<ChessSquare, ChessPiece> _pieces;

  const ChessBoard._(this._pieces);

  factory ChessBoard.initial() {
    final pieces = <ChessSquare, ChessPiece>{};

    // Pawns
    for (var file = 0; file < 8; file++) {
      pieces[ChessSquare(file, 1)] =
          const ChessPiece(type: ChessPieceType.pawn, color: ChessColor.white);
      pieces[ChessSquare(file, 6)] =
          const ChessPiece(type: ChessPieceType.pawn, color: ChessColor.black);
    }

    const backRank = [
      ChessPieceType.rook,
      ChessPieceType.knight,
      ChessPieceType.bishop,
      ChessPieceType.queen,
      ChessPieceType.king,
      ChessPieceType.bishop,
      ChessPieceType.knight,
      ChessPieceType.rook,
    ];

    for (var file = 0; file < 8; file++) {
      pieces[ChessSquare(file, 0)] =
          ChessPiece(type: backRank[file], color: ChessColor.white);
      pieces[ChessSquare(file, 7)] =
          ChessPiece(type: backRank[file], color: ChessColor.black);
    }

    return ChessBoard._(pieces);
  }

  /// Construct from a FEN position string (piece placement section only).
  factory ChessBoard.fromFEN(String fen) {
    final pieces = <ChessSquare, ChessPiece>{};
    final ranks = fen.split('/');

    for (var rank = 7; rank >= 0; rank--) {
      var file = 0;
      for (final char in ranks[7 - rank].split('')) {
        final digit = int.tryParse(char);
        if (digit != null) {
          file += digit;
        } else {
          final color =
              char == char.toUpperCase() ? ChessColor.white : ChessColor.black;
          final type = _pieceTypeFromChar(char.toLowerCase());
          pieces[ChessSquare(file, rank)] =
              ChessPiece(type: type, color: color);
          file++;
        }
      }
    }

    return ChessBoard._(pieces);
  }

  static ChessPieceType _pieceTypeFromChar(String char) {
    switch (char) {
      case 'k':
        return ChessPieceType.king;
      case 'q':
        return ChessPieceType.queen;
      case 'r':
        return ChessPieceType.rook;
      case 'b':
        return ChessPieceType.bishop;
      case 'n':
        return ChessPieceType.knight;
      case 'p':
        return ChessPieceType.pawn;
      default:
        throw ArgumentError('Unknown piece character: $char');
    }
  }

  static String _charFromPieceType(ChessPieceType type) {
    switch (type) {
      case ChessPieceType.king:
        return 'k';
      case ChessPieceType.queen:
        return 'q';
      case ChessPieceType.rook:
        return 'r';
      case ChessPieceType.bishop:
        return 'b';
      case ChessPieceType.knight:
        return 'n';
      case ChessPieceType.pawn:
        return 'p';
    }
  }

  ChessPiece? pieceAt(ChessSquare square) => _pieces[square];

  bool isEmpty(ChessSquare square) => !_pieces.containsKey(square);

  ChessBoard withMove(ChessSquare from, ChessSquare to) {
    final newPieces = Map<ChessSquare, ChessPiece>.from(_pieces);
    final piece = newPieces.remove(from);
    if (piece != null) newPieces[to] = piece.withMoved();
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

  ChessSquare? findKing(ChessColor color) {
    for (final entry in _pieces.entries) {
      if (entry.value.type == ChessPieceType.king &&
          entry.value.color == color) {
        return entry.key;
      }
    }
    return null;
  }

  Iterable<MapEntry<ChessSquare, ChessPiece>> get pieces => _pieces.entries;

  /// FEN position string (piece placement section).
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
          if (piece.color == ChessColor.white) char = char.toUpperCase();
          buffer.write(char);
        }
      }
      if (emptyCount > 0) buffer.write(emptyCount);
      if (rank > 0) buffer.write('/');
    }
    return buffer.toString();
  }

  @override
  // Use MapEquality from collection for deep comparison
  List<Object?> get props => [const MapEquality<ChessSquare, ChessPiece>().hash(_pieces)];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChessBoard) return false;
    return const MapEquality<ChessSquare, ChessPiece>()
        .equals(_pieces, other._pieces);
  }

  @override
  int get hashCode =>
      const MapEquality<ChessSquare, ChessPiece>().hash(_pieces);
}
