import 'package:equatable/equatable.dart';

enum ChessPieceType { king, queen, rook, bishop, knight, pawn }

enum ChessColor { white, black }

extension ChessColorExtension on ChessColor {
  ChessColor get opposite =>
      this == ChessColor.white ? ChessColor.black : ChessColor.white;
}

class ChessPiece extends Equatable {
  final ChessPieceType type;
  final ChessColor color;
  final bool hasMoved;

  const ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  ChessPiece withMoved() =>
      ChessPiece(type: type, color: color, hasMoved: true);

  int get materialValue {
    switch (type) {
      case ChessPieceType.pawn:
        return 1;
      case ChessPieceType.knight:
        return 3;
      case ChessPieceType.bishop:
        return 3;
      case ChessPieceType.rook:
        return 5;
      case ChessPieceType.queen:
        return 9;
      case ChessPieceType.king:
        return 0;
    }
  }

  String get symbol {
    const whitePieces = {
      ChessPieceType.king: '♔',
      ChessPieceType.queen: '♕',
      ChessPieceType.rook: '♖',
      ChessPieceType.bishop: '♗',
      ChessPieceType.knight: '♘',
      ChessPieceType.pawn: '♙',
    };
    const blackPieces = {
      ChessPieceType.king: '♚',
      ChessPieceType.queen: '♛',
      ChessPieceType.rook: '♜',
      ChessPieceType.bishop: '♝',
      ChessPieceType.knight: '♞',
      ChessPieceType.pawn: '♟',
    };
    return color == ChessColor.white
        ? whitePieces[type]!
        : blackPieces[type]!;
  }

  /// Piece letter for algebraic notation (empty string for pawns).
  String get notation {
    switch (type) {
      case ChessPieceType.king:
        return 'K';
      case ChessPieceType.queen:
        return 'Q';
      case ChessPieceType.rook:
        return 'R';
      case ChessPieceType.bishop:
        return 'B';
      case ChessPieceType.knight:
        return 'N';
      case ChessPieceType.pawn:
        return '';
    }
  }

  @override
  List<Object?> get props => [type, color, hasMoved];
}
