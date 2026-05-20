import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  group('BoardPosition', () {
    test('two positions with same row and col are equal', () {
      final a = BoardPosition(row: 3, col: 5);
      final b = BoardPosition(row: 3, col: 5);
      expect(a, equals(b));
    });

    test('positions with different row are not equal', () {
      final a = BoardPosition(row: 1, col: 5);
      final b = BoardPosition(row: 2, col: 5);
      expect(a, isNot(equals(b)));
    });

    test('positions with different col are not equal', () {
      final a = BoardPosition(row: 3, col: 1);
      final b = BoardPosition(row: 3, col: 2);
      expect(a, isNot(equals(b)));
    });

    test('isValid returns true for in-bounds position (8×8 board)', () {
      final pos = BoardPosition(row: 0, col: 0);
      expect(pos.isValid(rows: 8, cols: 8), isTrue);

      final pos2 = BoardPosition(row: 7, col: 7);
      expect(pos2.isValid(rows: 8, cols: 8), isTrue);
    });

    test('isValid returns false for out-of-bounds row', () {
      final pos = BoardPosition(row: 8, col: 0);
      expect(pos.isValid(rows: 8, cols: 8), isFalse);
    });

    test('isValid returns false for negative col', () {
      final pos = BoardPosition(row: 0, col: -1);
      expect(pos.isValid(rows: 8, cols: 8), isFalse);
    });

    test('offset returns correct adjacent position', () {
      final pos = BoardPosition(row: 3, col: 3);
      final right = pos.offset(dRow: 0, dCol: 1);
      expect(right, equals(BoardPosition(row: 3, col: 4)));

      final below = pos.offset(dRow: 1, dCol: 0);
      expect(below, equals(BoardPosition(row: 4, col: 3)));
    });

    test('orthogonalNeighbours returns 4 positions for centre cell', () {
      final pos = BoardPosition(row: 3, col: 3);
      final neighbours = pos.orthogonalNeighbours(rows: 8, cols: 8);
      expect(neighbours.length, 4);
    });

    test('orthogonalNeighbours returns fewer for corner cell', () {
      final pos = BoardPosition(row: 0, col: 0);
      final neighbours = pos.orthogonalNeighbours(rows: 8, cols: 8);
      expect(neighbours.length, 2);
    });
  });
}
