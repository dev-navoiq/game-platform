/// Pure-function helpers that the game screens consult before firing the
/// `newRound` / `newDeal` move at round-end.
///
/// Two responsibilities:
///
///   1. **Bot-only pause guard** ([hasAnyHumans]) — when a room has no human
///      players (e.g. the only human left mid-game), the screens should
///      *not* auto-advance. Instead they show a "Waiting for a player..."
///      message and hold the round-end ribbon indefinitely.
///   2. **Ready coordination** ([shouldAdvance]) — when humans are present,
///      auto-advance fires either when *all* humans have tapped READY or
///      the 30-second countdown expires, whichever comes first.
///
/// The record type `({String id, bool isBot})` is the lowest-common-
/// denominator each game screen can adapt to without depending on a
/// game-specific PlayerInfo class — the games only expose `playerOrder`
/// (List<String>) on their state, and `isBot` lives in [RoomMember]
/// (looked up via `roomMembersProvider`).
class RoundAdvanceGuard {
  RoundAdvanceGuard._();

  /// True if at least one HUMAN player is in the room. When false, the
  /// room is bot-only and the ribbon should pause rather than auto-advance.
  /// (Future: extend to count only CONNECTED humans once Item 5b's presence
  /// service lands.)
  static bool hasAnyHumans(Iterable<({String id, bool isBot})> players) {
    return players.any((p) => !p.isBot);
  }

  /// Should the screen fire newRound right now?
  ///
  /// Returns false when bot-only (the user-facing guardrail). Otherwise
  /// true iff all humans have readied OR the countdown elapsed.
  static bool shouldAdvance({
    required Iterable<({String id, bool isBot})> players,
    required Set<String> readyPlayerIds,
    required int secondsElapsed,
    int countdownLimit = 30,
  }) {
    if (!hasAnyHumans(players)) return false;
    final humans = players.where((p) => !p.isBot).map((p) => p.id).toSet();
    if (humans.isEmpty) return false;
    final allHumansReady = humans.every(readyPlayerIds.contains);
    return allHumansReady || secondsElapsed >= countdownLimit;
  }
}
