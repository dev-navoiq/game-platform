import 'package:flutter/material.dart';
import 'package:game_ludo/game_ludo.dart';

import '../../../../core/theme/colors.dart';

/// Ludo board widget with cross layout, home areas, and token circles.
///
/// The board is a 15×15 grid with four colored home bases in the corners
/// and a cross-shaped track in the center.
class LudoBoardWidget extends StatelessWidget {
  final LudoState state;
  final String? selectedTokenId;
  final Set<String> movableTokenIds;
  final ValueChanged<String>? onTokenTap;

  const LudoBoardWidget({
    super.key,
    required this.state,
    this.selectedTokenId,
    this.movableTokenIds = const {},
    this.onTokenTap,
  });

  static const _colors = {
    LudoColor.red: Color(0xFFEF4444),
    LudoColor.blue: Color(0xFF3B82F6),
    LudoColor.green: Color(0xFF22C55E),
    LudoColor.yellow: Color(0xFFF59E0B),
  };

  static const _lightColors = {
    LudoColor.red: Color(0xFFFECACA),
    LudoColor.blue: Color(0xFFBFDBFE),
    LudoColor.green: Color(0xFFBBF7D0),
    LudoColor.yellow: Color(0xFFFEF3C7),
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.textDark.withOpacity(0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth / 15;
              return Stack(
                children: [
                  // Background grid
                  _buildGrid(cellSize),

                  // Home bases
                  _buildHomeBase(cellSize, LudoColor.red, 0, 0),
                  _buildHomeBase(cellSize, LudoColor.green, 9, 0),
                  _buildHomeBase(cellSize, LudoColor.yellow, 0, 9),
                  _buildHomeBase(cellSize, LudoColor.blue, 9, 9),

                  // Center triangle area
                  _buildCenter(cellSize),

                  // Home stretch paths
                  _buildHomeStretch(cellSize, LudoColor.red, isVertical: false, startX: 1, startY: 7),
                  _buildHomeStretch(cellSize, LudoColor.green, isVertical: true, startX: 7, startY: 1),
                  _buildHomeStretch(cellSize, LudoColor.blue, isVertical: false, startX: 8, startY: 7),
                  _buildHomeStretch(cellSize, LudoColor.yellow, isVertical: true, startX: 7, startY: 8),

                  // Safe squares (stars)
                  ..._buildSafeSquares(cellSize),

                  // Tokens on board
                  ..._buildTokens(cellSize),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(double cellSize) {
    return CustomPaint(
      size: Size(cellSize * 15, cellSize * 15),
      painter: _LudoGridPainter(cellSize),
    );
  }

  Widget _buildHomeBase(double cellSize, LudoColor color, int gridX, int gridY) {
    final baseColor = _colors[color]!;
    final lightColor = _lightColors[color]!;
    final homeTokens = state.tokens
        .where((t) => t.color == color && t.isAtHome)
        .toList();

    return Positioned(
      left: gridX * cellSize,
      top: gridY * cellSize,
      width: cellSize * 6,
      height: cellSize * 6,
      child: Container(
        decoration: BoxDecoration(
          color: lightColor,
          border: Border.all(color: baseColor, width: 2),
        ),
        child: Center(
          child: Container(
            width: cellSize * 3.5,
            height: cellSize * 3.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: baseColor, width: 1.5),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: List.generate(4, (i) {
                final token = i < homeTokens.length ? homeTokens[i] : null;
                return _TokenCircle(
                  size: cellSize * 1.2,
                  color: baseColor,
                  hasToken: token != null,
                  isMovable: token != null && movableTokenIds.contains(token.id),
                  isSelected: token != null && selectedTokenId == token.id,
                  onTap: token != null && onTokenTap != null
                      ? () => onTokenTap!(token.id)
                      : null,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenter(double cellSize) {
    return Positioned(
      left: 6 * cellSize,
      top: 6 * cellSize,
      width: 3 * cellSize,
      height: 3 * cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: CustomPaint(
          painter: _CenterTrianglePainter(),
        ),
      ),
    );
  }

  Widget _buildHomeStretch(
    double cellSize,
    LudoColor color, {
    required bool isVertical,
    required int startX,
    required int startY,
  }) {
    final baseColor = _colors[color]!;
    return Stack(
      children: List.generate(5, (i) {
        final x = isVertical ? startX : startX + i;
        final y = isVertical ? startY + i : startY;
        return Positioned(
          left: x * cellSize,
          top: y * cellSize,
          width: cellSize,
          height: cellSize,
          child: Container(
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.3),
              border: Border.all(color: baseColor.withOpacity(0.5), width: 0.5),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildSafeSquares(double cellSize) {
    // Map safe square indices to grid positions
    final safePositions = <int, Offset>{
      0: Offset(6, 13),  // Red start
      8: Offset(2, 6),
      13: Offset(1, 6),  // Blue start
      21: Offset(6, 2),
      26: Offset(8, 1),  // Green start
      34: Offset(12, 6),
      39: Offset(13, 8),  // Yellow start
      47: Offset(8, 12),
    };

    return safePositions.entries.map((e) {
      return Positioned(
        left: e.value.dx * cellSize,
        top: e.value.dy * cellSize,
        width: cellSize,
        height: cellSize,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Center(
            child: Icon(
              Icons.star,
              size: cellSize * 0.4,
              color: AppColors.accent.withOpacity(0.4),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTokens(double cellSize) {
    final widgets = <Widget>[];

    for (final token in state.tokens) {
      if (token.isAtHome || token.isFinished) continue;

      final pos = _tokenGridPosition(token, cellSize);
      if (pos == null) continue;

      final baseColor = _colors[token.color]!;
      widgets.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: _TokenCircle(
            size: cellSize * 0.8,
            color: baseColor,
            hasToken: true,
            isMovable: movableTokenIds.contains(token.id),
            isSelected: selectedTokenId == token.id,
            onTap: onTokenTap != null ? () => onTokenTap!(token.id) : null,
          ),
        ),
      );
    }

    return widgets;
  }

  Offset? _tokenGridPosition(LudoToken token, double cellSize) {
    // Simplified grid mapping — real implementation would map all 52 main
    // track positions + 6 home stretch positions to pixel coordinates.
    // For now, use a basic circular mapping.
    if (token.position.zone == LudoZone.main) {
      final angle = (token.position.index / 52) * 2 * 3.14159;
      final radius = cellSize * 5.5;
      final cx = cellSize * 7.5;
      final cy = cellSize * 7.5;
      return Offset(
        cx + radius * _sin(angle) - cellSize * 0.4,
        cy - radius * _cos(angle) - cellSize * 0.4,
      );
    } else if (token.position.zone == LudoZone.homeStretch) {
      // Home stretch positions point towards center
      final color = token.color;
      final i = token.position.index;
      double x, y;
      switch (color) {
        case LudoColor.red:
          x = (1 + i) * cellSize;
          y = 7 * cellSize;
        case LudoColor.green:
          x = 7 * cellSize;
          y = (1 + i) * cellSize;
        case LudoColor.blue:
          x = (13 - i) * cellSize;
          y = 7 * cellSize;
        case LudoColor.yellow:
          x = 7 * cellSize;
          y = (13 - i) * cellSize;
      }
      return Offset(x + cellSize * 0.1, y + cellSize * 0.1);
    }
    return null;
  }

  double _sin(double angle) {
    // Simple sine approximation for position calculation
    return _sinTable(angle);
  }

  double _cos(double angle) {
    return _sinTable(angle + 1.5708);
  }

  double _sinTable(double x) {
    // Normalize to 0..2π
    while (x < 0) x += 6.28318;
    while (x > 6.28318) x -= 6.28318;
    // Taylor series approximation
    final x2 = x > 3.14159 ? x - 6.28318 : x;
    final x3 = x2 * x2 * x2;
    final x5 = x3 * x2 * x2;
    return x2 - x3 / 6 + x5 / 120;
  }
}

class _TokenCircle extends StatelessWidget {
  final double size;
  final Color color;
  final bool hasToken;
  final bool isMovable;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TokenCircle({
    required this.size,
    required this.color,
    required this.hasToken,
    this.isMovable = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isMovable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasToken ? color : Colors.transparent,
          border: Border.all(
            color: hasToken ? color : color.withOpacity(0.3),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : isMovable
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
        ),
        child: hasToken
            ? Center(
                child: Container(
                  width: size * 0.4,
                  height: size * 0.4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _LudoGridPainter extends CustomPainter {
  final double cellSize;

  _LudoGridPainter(this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw the cross-shaped track area (rows 6-8, cols 0-14 and rows 0-14, cols 6-8)
    // Horizontal path
    for (var y = 6; y <= 8; y++) {
      for (var x = 0; x < 15; x++) {
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) continue; // Center
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }

    // Vertical path
    for (var x = 6; x <= 8; x++) {
      for (var y = 0; y < 15; y++) {
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) continue; // Center
        if (y >= 6 && y <= 8) continue; // Already drawn
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      LudoBoardWidget._colors[LudoColor.red]!,
      LudoBoardWidget._colors[LudoColor.green]!,
      LudoBoardWidget._colors[LudoColor.blue]!,
      LudoBoardWidget._colors[LudoColor.yellow]!,
    ];

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Four triangles pointing inward
    final paths = [
      // Top (green)
      _trianglePath(Offset(0, 0), Offset(size.width, 0), Offset(cx, cy)),
      // Right (blue)
      _trianglePath(
          Offset(size.width, 0), Offset(size.width, size.height), Offset(cx, cy)),
      // Bottom (yellow)
      _trianglePath(
          Offset(size.width, size.height), Offset(0, size.height), Offset(cx, cy)),
      // Left (red)
      _trianglePath(Offset(0, size.height), Offset(0, 0), Offset(cx, cy)),
    ];

    for (var i = 0; i < 4; i++) {
      canvas.drawPath(
        paths[i],
        Paint()
          ..color = colors[i].withOpacity(0.6)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        paths[i],
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  Path _trianglePath(Offset a, Offset b, Offset c) {
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
