/// Ludo board geometry constants.
library;

enum LudoColor { red, blue, green, yellow }

enum LudoZone { home, main, homeStretch, finish }

class LudoPosition {
  final LudoZone zone;
  final int index; // Position within zone
  final LudoColor color; // Meaningful for home / homeStretch / finish zones

  const LudoPosition._({
    required this.zone,
    required this.index,
    required this.color,
  });

  /// Token sitting in its home base before entering the board.
  factory LudoPosition.home(LudoColor color, int slot) =>
      LudoPosition._(zone: LudoZone.home, index: slot, color: color);

  /// Token on the shared main track (0-51).
  factory LudoPosition.main(int index) =>
      LudoPosition._(zone: LudoZone.main, index: index, color: LudoColor.red);

  /// Token in the player-specific home stretch (0-5).
  factory LudoPosition.homeStretch(LudoColor color, int index) =>
      LudoPosition._(
          zone: LudoZone.homeStretch, index: index, color: color);

  /// Token has reached the finish square.
  factory LudoPosition.finish(LudoColor color) =>
      LudoPosition._(zone: LudoZone.finish, index: 0, color: color);

  /// Reconstruct from JSON (for serialisation).
  factory LudoPosition.fromJson(Map<String, dynamic> json) {
    final zone = LudoZone.values.byName(json['zone'] as String);
    final index = json['index'] as int;
    final color = LudoColor.values.byName(json['color'] as String);
    return LudoPosition._(zone: zone, index: index, color: color);
  }

  // ---------------------------------------------------------------------------
  // Board geometry constants
  // ---------------------------------------------------------------------------

  static const int mainTrackLength = 52;
  static const int homeStretchLength = 6;

  /// Starting square on the main track for each colour.
  static int startPosition(LudoColor color) {
    switch (color) {
      case LudoColor.red:
        return 0;
      case LudoColor.blue:
        return 13;
      case LudoColor.green:
        return 26;
      case LudoColor.yellow:
        return 39;
    }
  }

  /// Main-track square from which the token enters the home stretch.
  /// A token AT this square enters the home stretch on its next roll.
  static int homeStretchEntry(LudoColor color) =>
      (startPosition(color) + 50) % mainTrackLength;

  /// Safe squares on the main track (starting squares + star squares).
  static const Set<int> safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  bool get isSafe =>
      zone == LudoZone.main && safeSquares.contains(index);

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LudoPosition) return false;
    if (zone != other.zone) return false;
    if (index != other.index) return false;
    // For the main track, color is irrelevant
    if (zone == LudoZone.main) return true;
    return color == other.color;
  }

  @override
  int get hashCode {
    if (zone == LudoZone.main) return Object.hash(zone, index);
    return Object.hash(zone, index, color);
  }

  @override
  String toString() => '$zone($index, $color)';
}
