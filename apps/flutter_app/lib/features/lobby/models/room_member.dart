/// One occupant of a room — either a human player (row in `room_players`)
/// or a bot (entry in `game_rooms.config.bots`).
///
/// Bots and humans are sourced from different places by design (see migration
/// `add_bot_to_room_rpc.sql`: bots can't go in `room_players` because that
/// table FKs through `profiles → auth.users`). This class is the unified view
/// the UI consumes.
class RoomMember {
  final String id;
  final String displayName;
  final int seatIndex;
  final bool isHost;
  final bool isBot;
  final bool isReady;
  final bool isCurrentUser;
  final bool isSpectator;
  final String? botDifficulty;

  const RoomMember({
    required this.id,
    required this.displayName,
    required this.seatIndex,
    required this.isHost,
    required this.isBot,
    required this.isReady,
    required this.isCurrentUser,
    this.isSpectator = false,
    this.botDifficulty,
  });
}

/// Everything the Room screen needs to create a room *itself* after the user
/// taps "Create Room" on the lobby. Passed as GoRouter `extra` so the screen
/// can render an optimistic "creating…" state immediately (host seat + correct
/// seat count are all known client-side) while the create-room edge function
/// runs in the background — instead of freezing the lobby button for 2–5s.
class RoomCreateRequest {
  final String gameType;
  final String socialMode;
  final int maxPlayers;

  /// Room-config JSON forwarded verbatim to the create-room edge function:
  /// Oh Hell length options under `oh_hell`, `auto_start_when_full`, etc.
  final Map<String, dynamic>? config;

  const RoomCreateRequest({
    required this.gameType,
    required this.socialMode,
    required this.maxPlayers,
    this.config,
  });
}

/// What the lobby/room screen needs every time it reconciles with the server.
/// One query at the room level + one at the participant level both feed into
/// a single snapshot the UI swaps in atomically.
class RoomSnapshot {
  final String roomCode;
  final String socialMode;
  final String status;
  final String gameType;
  final int maxPlayers;
  final List<RoomMember> members;

  const RoomSnapshot({
    required this.roomCode,
    required this.socialMode,
    required this.status,
    required this.gameType,
    required this.maxPlayers,
    required this.members,
  });
}
