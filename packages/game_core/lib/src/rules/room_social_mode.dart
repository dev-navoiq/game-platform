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
