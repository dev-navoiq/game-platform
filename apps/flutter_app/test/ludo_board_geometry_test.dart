import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:flutter_app/features/game/presentation/ludo/ludo_board_geometry.dart';

void main() {
  const geo = LudoBoardGeometry();

  LudoToken tokenAt(LudoColor color, LudoPosition pos) =>
      LudoToken(id: '${color.name}_0', color: color, position: pos);

  group('main path', () {
    test('has 52 unique cells', () {
      final cells = geo.mainPath.toSet();
      expect(geo.mainPath.length, 52);
      expect(cells.length, 52, reason: 'all main cells must be distinct');
    });

    test('is a closed loop with only the 4 corner turns stepping diagonally', () {
      var diagonals = 0;
      for (var i = 0; i < 52; i++) {
        final a = geo.mainPath[i];
        final b = geo.mainPath[(i + 1) % 52];
        final d = (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();
        // 1 = straight step; 2 = a diagonal corner turn (visually fine).
        expect(d, inInclusiveRange(1, 2),
            reason: 'cells $i→${(i + 1) % 52} must be contiguous');
        if (d == 2) diagonals++;
      }
      expect(diagonals, 4, reason: 'exactly the 4 arm corners turn diagonally');
    });

    test('start indices sit on the engine-defined start cells', () {
      expect(geo.mainPath[LudoPosition.startPosition(LudoColor.red)], (6, 13));
      expect(geo.mainPath[LudoPosition.startPosition(LudoColor.blue)], (1, 6));
      expect(geo.mainPath[LudoPosition.startPosition(LudoColor.green)], (8, 1));
      expect(geo.mainPath[LudoPosition.startPosition(LudoColor.yellow)], (13, 8));
    });

    test('all 8 safe squares land on real path cells', () {
      for (final idx in LudoPosition.safeSquares) {
        expect(idx, inInclusiveRange(0, 51));
        // Resolving the cell must not throw and must be on the grid.
        final c = geo.mainPath[idx];
        expect(c.$1, inInclusiveRange(0, 14));
        expect(c.$2, inInclusiveRange(0, 14));
      }
    });
  });

  group('home stretches', () {
    test('each color has 6 cells leading toward the centre', () {
      for (final color in LudoColor.values) {
        expect(geo.homeStretchCells(color).length, 6);
        // last home cell is orthogonally adjacent to the centre (7,7)
        final last = geo.homeStretchCells(color).last;
        final d = (last.$1 - 7).abs() + (last.$2 - 7).abs();
        expect(d, 1, reason: '$color home column should end next to centre');
      }
    });

    test('home-entry track cell is adjacent to the first home cell', () {
      for (final color in LudoColor.values) {
        final entryIdx = LudoPosition.homeStretchEntry(color);
        final entryCell = geo.mainPath[entryIdx];
        final firstHome = geo.homeStretchCells(color).first;
        final d = (entryCell.$1 - firstHome.$1).abs() +
            (entryCell.$2 - firstHome.$2).abs();
        expect(d, 1,
            reason: '$color home entry $entryCell must touch $firstHome');
      }
    });
  });

  group('route', () {
    test('a 3-step main move yields 3 cells ending at the destination', () {
      final token = tokenAt(LudoColor.red, LudoPosition.main(0));
      final cells = geo.route(token, LudoPosition.main(3));
      expect(cells.length, 3);
      expect(cells.last, const Offset(6, 10)); // mainPath[3]
    });

    test('entering the board from the garage is a single hop onto start', () {
      final token = tokenAt(LudoColor.green, LudoPosition.home(LudoColor.green, 0));
      final cells = geo.route(
          token, LudoPosition.main(LudoPosition.startPosition(LudoColor.green)));
      expect(cells.length, 1);
      expect(cells.single, const Offset(8, 1));
    });

    test('a move into the home stretch turns off the main track', () {
      // red enters home stretch after passing index 50 (its entry cell).
      final token = tokenAt(LudoColor.red, LudoPosition.main(50));
      final cells = geo.route(token, LudoPosition.homeStretch(LudoColor.red, 0));
      expect(cells.last, const Offset(7, 13)); // red home[0]
    });
  });
}
