import 'package:flutter/painting.dart';
import 'package:game_ludo/game_ludo.dart';

/// Pure board geometry for Ludo: maps every logical [LudoPosition] to a cell on
/// the 15×15 grid, and computes the ordered route a token travels for a move so
/// the presentation layer can animate it smoothly.
///
/// This is the single source of truth for "where is position P on screen",
/// shared by the static board chrome and the animated rider layer. It replaces
/// the old faked circular mapping.
///
/// Coordinates are `(col, row)` in grid units (0–14). Multiply by the cell size
/// to get pixels. The main path is verified (see ludo_board_geometry_test.dart)
/// to place the engine's start indices (0/13/26/39) and the 8 safe squares
/// {0,8,13,21,26,34,39,47} on the correct cells.
class LudoBoardGeometry {
  const LudoBoardGeometry();

  static const int gridSize = 15;
  static const int mainLength = LudoPosition.mainTrackLength; // 52
  static const int homeStretchLength = LudoPosition.homeStretchLength; // 6

  /// The 52 main-track cells, clockwise, index 0 = red's start cell (6,13).
  static const List<(int, int)> _mainPath = [
    // up the left lane of the bottom (red) arm
    (6, 13), (6, 12), (6, 11), (6, 10), (6, 9),
    // across the bottom lane of the left (blue) arm
    (5, 8), (4, 8), (3, 8), (2, 8), (1, 8), (0, 8),
    (0, 7), // blue's home-entry track cell
    // up the top lane of the left arm
    (0, 6), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6),
    // up the left lane of the top (green) arm
    (6, 5), (6, 4), (6, 3), (6, 2), (6, 1), (6, 0),
    (7, 0), // green's home-entry track cell
    // down the right lane of the top arm
    (8, 0), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5),
    // across the top lane of the right (yellow) arm
    (9, 6), (10, 6), (11, 6), (12, 6), (13, 6), (14, 6),
    (14, 7), // yellow's home-entry track cell
    // back across the bottom lane of the right arm
    (14, 8), (13, 8), (12, 8), (11, 8), (10, 8), (9, 8),
    // down the right lane of the bottom arm
    (8, 9), (8, 10), (8, 11), (8, 12), (8, 13), (8, 14),
    (7, 14), // red's home-entry track cell
    (6, 14),
  ];

  /// Home-column cells per color, from the first cell inside the column
  /// (index 0) to the cell adjacent to the centre (index 5).
  static const Map<LudoColor, List<(int, int)>> _homeStretch = {
    // red enters from the bottom, climbs col 7
    LudoColor.red: [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
    // blue enters from the left, runs along row 7
    LudoColor.blue: [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7)],
    // green enters from the top, descends col 7
    LudoColor.green: [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
    // yellow enters from the right, runs along row 7
    LudoColor.yellow: [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7), (8, 7)],
  };

  /// Top-left grid corner (col,row) of each color's 6×6 home base.
  static const Map<LudoColor, (int, int)> baseCorner = {
    LudoColor.red: (0, 9), // bottom-left
    LudoColor.blue: (0, 0), // top-left
    LudoColor.green: (9, 0), // top-right
    LudoColor.yellow: (9, 9), // bottom-right
  };

  /// Centre finish cell (all colors converge here visually).
  static const Offset _finish = Offset(7, 7);

  List<(int, int)> get mainPath => _mainPath;

  List<(int, int)> homeStretchCells(LudoColor color) => _homeStretch[color]!;

  /// The four garage slot centres (in fractional grid units) inside a color's
  /// home base, where unentered tokens park.
  List<Offset> garageSlots(LudoColor color) {
    final (cx, cy) = baseCorner[color]!;
    // A 2×2 cluster centred in the 6×6 base.
    return [
      Offset(cx + 1.7, cy + 1.7),
      Offset(cx + 3.8, cy + 1.7),
      Offset(cx + 1.7, cy + 3.8),
      Offset(cx + 3.8, cy + 3.8),
    ];
  }

  /// Fractional grid cell (col,row) centre-anchor for any token position.
  Offset cellForPosition(LudoToken token) {
    final p = token.position;
    switch (p.zone) {
      case LudoZone.home:
        final slot = _slotIndex(token.id);
        return garageSlots(token.color)[slot];
      case LudoZone.main:
        final (c, r) = _mainPath[p.index % mainLength];
        return Offset(c.toDouble(), r.toDouble());
      case LudoZone.homeStretch:
        final (c, r) = _homeStretch[p.color]![p.index];
        return Offset(c.toDouble(), r.toDouble());
      case LudoZone.finish:
        return _finish;
    }
  }

  /// Pixel centre of a fractional grid cell.
  Offset pixelCenter(Offset gridCell, double cellSize) =>
      Offset((gridCell.dx + 0.5) * cellSize, (gridCell.dy + 0.5) * cellSize);

  /// Ordered grid cells a token crosses moving from [from] to [to] (one cell per
  /// logical step), so the animation can hop cell-by-cell. Excludes the start
  /// cell, includes the destination. Entering the board from the garage is a
  /// single hop onto the start cell.
  List<Offset> route(LudoToken token, LudoPosition to) {
    final color = token.color;
    final from = token.position;
    if (from.zone == LudoZone.home) {
      // Pop straight onto the destination (the start cell).
      return [_offsetOf(to, color)];
    }
    final cells = <Offset>[];
    var cur = from;
    var guard = 0;
    while (!_samePosition(cur, to) && guard < mainLength + homeStretchLength + 2) {
      cur = _advanceOne(cur, color);
      cells.add(_offsetOf(cur, color));
      guard++;
    }
    if (cells.isEmpty) cells.add(_offsetOf(to, color));
    return cells;
  }

  // ── internals ──────────────────────────────────────────────────────────────

  Offset _offsetOf(LudoPosition p, LudoColor color) {
    switch (p.zone) {
      case LudoZone.home:
        return garageSlots(color).first;
      case LudoZone.main:
        final (c, r) = _mainPath[p.index % mainLength];
        return Offset(c.toDouble(), r.toDouble());
      case LudoZone.homeStretch:
        final (c, r) = _homeStretch[color]![p.index];
        return Offset(c.toDouble(), r.toDouble());
      case LudoZone.finish:
        return _finish;
    }
  }

  /// Advance a position by exactly one cell along its color's route.
  LudoPosition _advanceOne(LudoPosition p, LudoColor color) {
    switch (p.zone) {
      case LudoZone.home:
        return LudoPosition.main(LudoPosition.startPosition(color));
      case LudoZone.main:
        if (p.index == LudoPosition.homeStretchEntry(color)) {
          return LudoPosition.homeStretch(color, 0);
        }
        return LudoPosition.main((p.index + 1) % mainLength);
      case LudoZone.homeStretch:
        if (p.index + 1 < homeStretchLength) {
          return LudoPosition.homeStretch(color, p.index + 1);
        }
        return LudoPosition.finish(color);
      case LudoZone.finish:
        return LudoPosition.finish(color);
    }
  }

  bool _samePosition(LudoPosition a, LudoPosition b) =>
      a.zone == b.zone &&
      a.index == b.index &&
      (a.zone == LudoZone.main || a.color == b.color);

  int _slotIndex(String tokenId) =>
      int.tryParse(tokenId.split('_').last) ?? 0;
}
