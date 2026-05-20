/// Deterministic display identity (emoji + short name) for a player ID.
///
/// Keeps bots visually distinguishable at the table without requiring a
/// backend field. The emoji is derived from a stable hash of the player ID,
/// so the same bot keeps the same avatar across re-renders.
class PlayerAvatar {
  PlayerAvatar._();

  static const List<String> _emojiPool = [
    '🦁', '🐯', '🐼', '🦊', '🐨', '🐸', '🦉', '🐵',
    '🐰', '🐻', '🦄', '🐲', '🦅', '🐺', '🐱', '🐶',
  ];

  /// Pick a deterministic emoji for [playerId].
  static String emojiFor(String playerId) {
    if (playerId.isEmpty) return _emojiPool[0];
    final hash = _stableHash(playerId);
    return _emojiPool[hash % _emojiPool.length];
  }

  /// Short display name. Local player shows "You"; other players get a
  /// seat-based label like "Bot 1", "Bot 2", etc. If a backend-supplied
  /// [displayName] is provided and non-empty, prefer it.
  static String nameFor({
    required String playerId,
    required String? localPlayerId,
    required int seatIndex,
    String? displayName,
  }) {
    if (playerId == localPlayerId) return 'You';
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return 'Bot ${seatIndex + 1}';
  }

  /// Build a map of `playerId → emoji` for a seating order.
  static Map<String, String> emojiMap(List<String> playerOrder) {
    return {for (final pid in playerOrder) pid: emojiFor(pid)};
  }

  static int _stableHash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}
