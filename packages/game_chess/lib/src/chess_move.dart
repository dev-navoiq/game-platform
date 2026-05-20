import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

import 'chess_board.dart';
import 'chess_piece.dart';

sealed class ChessMove extends GameMove with EquatableMixin {
  @override
  final String playerId;
  @override
  final DateTime? timestamp;

  const ChessMove({required this.playerId, this.timestamp});
}

/// A piece movement: normal move, capture, en passant, castling, or promotion.
class ChessMoveAction extends ChessMove {
  final ChessSquare from;
  final ChessSquare to;
  final bool isCastling;
  final bool isEnPassant;
  final ChessPieceType? promotion;

  const ChessMoveAction({
    required super.playerId,
    required this.from,
    required this.to,
    this.isCastling = false,
    this.isEnPassant = false,
    this.promotion,
    super.timestamp,
  });

  @override
  MoveType get type => isCastling
      ? MoveType.castle
      : promotion != null
          ? MoveType.promote
          : MoveType.movePiece;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'playerId': playerId,
        'from': from.notation,
        'to': to.notation,
        'isCastling': isCastling,
        'isEnPassant': isEnPassant,
        if (promotion != null) 'promotion': promotion!.name,
      };

  @override
  List<Object?> get props =>
      [playerId, from, to, isCastling, isEnPassant, promotion];
}

/// Player resigns — their opponent wins.
class ChessResign extends ChessMove {
  const ChessResign({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.resign;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'resign',
        'playerId': playerId,
      };

  @override
  List<Object?> get props => [playerId];
}

ChessMove parseChessMove(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final playerId = json['playerId'] as String;
  switch (type) {
    case 'movePiece':
    case 'castle':
    case 'promote':
      return ChessMoveAction(
        playerId: playerId,
        from: ChessSquare.fromNotation(json['from'] as String),
        to: ChessSquare.fromNotation(json['to'] as String),
        isCastling: json['isCastling'] ?? false,
        isEnPassant: json['isEnPassant'] ?? false,
        promotion: json['promotion'] != null
            ? ChessPieceType.values.byName(json['promotion'] as String)
            : null,
      );
    case 'resign':
      return ChessResign(playerId: playerId);
    default:
      throw ArgumentError('Unknown chess move type: $type');
  }
}
