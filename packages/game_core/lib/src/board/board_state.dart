import 'package:equatable/equatable.dart';

/// Abstract snapshot of a board-game's board.
/// Concrete board-game packages extend this with their piece map and logic.
abstract class BoardState extends Equatable {
  const BoardState();

  /// Number of rows on this board.
  int get boardRows;

  /// Number of columns on this board.
  int get boardCols;

  @override
  List<Object?> get props => [boardRows, boardCols];
}
