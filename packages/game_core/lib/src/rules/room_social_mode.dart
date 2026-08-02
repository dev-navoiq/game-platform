/// Social-feature mode for a game room.
/// Controls which communication channels are active during play.
enum RoomSocialMode {
  /// Text chat + voice chat + emotes + floating bubbles.
  full,

  /// Text chat + emotes + floating bubbles; no voice.
  chatOnly,

  /// Emotes and emote bubbles only; no text or voice.
  silent,

  /// No social features — zero distractions (tournament / ranked finals).
  focus,
}

/// Wire-format parsing for [RoomSocialMode].
///
/// The database stores snake_case ('chat_only') while the Dart enum uses
/// camelCase ('chatOnly'). `values.byName` on the raw DB string THREW for
/// chat_only — killing deserialization of every chat-only game state and
/// making the whole mode unplayable (#218). Accept both conventions and
/// fall back to full rather than throwing.
extension RoomSocialModeWire on RoomSocialMode {
  static RoomSocialMode parse(String? raw) {
    switch (raw) {
      case 'full':
        return RoomSocialMode.full;
      case 'chat_only':
      case 'chatOnly':
        return RoomSocialMode.chatOnly;
      case 'silent':
        return RoomSocialMode.silent;
      case 'focus':
        return RoomSocialMode.focus;
      default:
        return RoomSocialMode.full;
    }
  }
}
