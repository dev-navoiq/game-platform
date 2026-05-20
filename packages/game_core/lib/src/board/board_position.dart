import 'package:equatable/equatable.dart';

/// A position on a 2-D game board identified by (row, col).
class BoardPosition extends Equatable {
  final int row;
  final int col;

  const BoardPosition({required this.row, required this.col});

  /// True when this position falls within a board of [rows] × [cols].
  bool isValid({required int rows, required int cols}) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  /// Returns the position shifted by ([dRow], [dCol]).
  BoardPosition offset({required int dRow, required int dCol}) =>
      BoardPosition(row: row + dRow, col: col + dCol);

  /// All valid orthogonal (N/S/E/W) neighbours on a [rows] × [cols] board.
  List<BoardPosition> orthogonalNeighbours({
    required int rows,
    required int cols,
  }) {
    return [
      offset(dRow: -1, dCol: 0),
      offset(dRow: 1, dCol: 0),
      offset(dRow: 0, dCol: -1),
      offset(dRow: 0, dCol: 1),
    ].where((p) => p.isValid(rows: rows, cols: cols)).toList();
  }

  /// All valid diagonal neighbours on a [rows] × [cols] board.
  List<BoardPosition> diagonalNeighbours({
    required int rows,
    required int cols,
  }) {
    return [
      offset(dRow: -1, dCol: -1),
      offset(dRow: -1, dCol: 1),
      offset(dRow: 1, dCol: -1),
      offset(dRow: 1, dCol: 1),
    ].where((p) => p.isValid(rows: rows, cols: cols)).toList();
  }

  /// Manhattan distance to [other].
  int distanceTo(BoardPosition other) =>
      (row - other.row).abs() + (col - other.col).abs();

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => '($row, $col)';

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory BoardPosition.fromJson(Map<String, dynamic> json) =>
      BoardPosition(row: json['row'] as int, col: json['col'] as int);
}
