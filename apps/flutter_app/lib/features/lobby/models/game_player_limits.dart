/// Client-side mirror of `GAME_PLAYER_LIMITS` in
/// `supabase/functions/_shared/types.ts` — the server rejects create-room
/// requests outside these ranges, so the two must stay in sync.
class GamePlayerLimits {
  GamePlayerLimits._();

  static const Map<String, (int min, int max)> _limits = {
    'twenty_nine': (4, 4),
    'oh_hell': (4, 6),
    'hearts': (4, 4),
    'spades': (4, 4),
    'bridge': (4, 4),
    'rummy': (2, 6),
    'chess': (2, 2),
    'ludo': (2, 4),
    'sequence': (2, 3),
  };

  static int minFor(String gameType) => _limits[gameType]?.$1 ?? 2;

  static int maxFor(String gameType) => _limits[gameType]?.$2 ?? 4;

  /// True when the host has a real choice to make (min != max) and the
  /// create flow should show the player-count sheet.
  static bool isVariable(String gameType) =>
      minFor(gameType) != maxFor(gameType);
}
