import 'package:flutter/material.dart';

/// Describes a player's seat position on the game table.
class SeatPosition {
  final Alignment alignment;
  final bool isBottom;
  final bool isSmall;
  final int seatIndex;

  const SeatPosition({
    required this.alignment,
    required this.seatIndex,
    this.isBottom = false,
    this.isSmall = false,
  });
}

/// Calculates player seat positions around the game table perimeter.
///
/// The local player is always placed at the bottom. Opponents are
/// distributed around the perimeter based on player count.
class SeatLayout {
  SeatLayout._();

  static List<SeatPosition> calculate({
    required int playerCount,
    required int localPlayerIndex,
  }) {
    final rawSeats = _seatsForCount(playerCount);
    // Rotate so localPlayerIndex maps to index 0 (bottom)
    final rotated = <SeatPosition>[];
    for (var i = 0; i < rawSeats.length; i++) {
      final sourceIndex = (localPlayerIndex + i) % playerCount;
      rotated.add(SeatPosition(
        alignment: rawSeats[i].alignment,
        seatIndex: sourceIndex,
        isBottom: i == 0,
        isSmall: rawSeats[i].isSmall,
      ));
    }
    return rotated;
  }

  static List<SeatPosition> _seatsForCount(int count) {
    switch (count) {
      case 2:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment.topCenter, seatIndex: 1),
        ];
      case 3:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-0.7, -0.7), seatIndex: 1),
          SeatPosition(alignment: Alignment(0.7, -0.7), seatIndex: 2),
        ];
      case 4:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-1, 0), seatIndex: 1, isSmall: true),
          SeatPosition(alignment: Alignment.topCenter, seatIndex: 2),
          SeatPosition(alignment: Alignment(1, 0), seatIndex: 3, isSmall: true),
        ];
      case 5:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-1, 0.3), seatIndex: 1, isSmall: true),
          SeatPosition(alignment: Alignment(-0.6, -0.7), seatIndex: 2),
          SeatPosition(alignment: Alignment.topCenter, seatIndex: 3),
          SeatPosition(alignment: Alignment(0.6, -0.7), seatIndex: 4),
        ];
      case 6:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-1, 0), seatIndex: 1, isSmall: true),
          SeatPosition(alignment: Alignment(-0.7, -0.7), seatIndex: 2),
          SeatPosition(alignment: Alignment.topCenter, seatIndex: 3),
          SeatPosition(alignment: Alignment(0.7, -0.7), seatIndex: 4),
          SeatPosition(alignment: Alignment(1, 0), seatIndex: 5, isSmall: true),
        ];
      case 7:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-1, 0.3), seatIndex: 1, isSmall: true),
          SeatPosition(alignment: Alignment(-1, -0.4), seatIndex: 2, isSmall: true),
          SeatPosition(alignment: Alignment(-0.5, -0.8), seatIndex: 3),
          SeatPosition(alignment: Alignment(0.5, -0.8), seatIndex: 4),
          SeatPosition(alignment: Alignment(1, -0.4), seatIndex: 5, isSmall: true),
          SeatPosition(alignment: Alignment(1, 0.3), seatIndex: 6, isSmall: true),
        ];
      case 8:
        return const [
          SeatPosition(alignment: Alignment.bottomCenter, seatIndex: 0, isBottom: true),
          SeatPosition(alignment: Alignment(-1, 0.3), seatIndex: 1, isSmall: true),
          SeatPosition(alignment: Alignment(-1, -0.4), seatIndex: 2, isSmall: true),
          SeatPosition(alignment: Alignment(-0.5, -0.8), seatIndex: 3),
          SeatPosition(alignment: Alignment.topCenter, seatIndex: 4),
          SeatPosition(alignment: Alignment(0.5, -0.8), seatIndex: 5),
          SeatPosition(alignment: Alignment(1, -0.4), seatIndex: 6, isSmall: true),
          SeatPosition(alignment: Alignment(1, 0.3), seatIndex: 7, isSmall: true),
        ];
      default:
        // Fallback: distribute evenly (2 minimum)
        return _seatsForCount(count.clamp(2, 8));
    }
  }
}
