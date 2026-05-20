import 'package:equatable/equatable.dart';

/// Marker interface for piece types; implement in each board-game package.
abstract class PieceType {
  String get name;
  String get symbol;
}

/// A piece on the board, parameterised by its [PieceType].
class BoardPiece<T extends PieceType> extends Equatable {
  final T type;
  final String ownerId;
  final int teamIndex;
  final bool hasMoved;

  const BoardPiece({
    required this.type,
    required this.ownerId,
    required this.teamIndex,
    this.hasMoved = false,
  });

  BoardPiece<T> copyWith({
    T? type,
    String? ownerId,
    int? teamIndex,
    bool? hasMoved,
  }) =>
      BoardPiece(
        type: type ?? this.type,
        ownerId: ownerId ?? this.ownerId,
        teamIndex: teamIndex ?? this.teamIndex,
        hasMoved: hasMoved ?? this.hasMoved,
      );

  @override
  List<Object?> get props => [type, ownerId, teamIndex, hasMoved];
}
