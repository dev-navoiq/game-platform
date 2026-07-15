/// Contract for a fully on-device game session ("Practice vs Bots").
///
/// When attached to `GameNotifier` (see game_provider.dart), wire-format
/// moves from the game screens are routed here instead of the
/// `validate-move` edge function, and no realtime subscription is opened —
/// the session publishes engine states straight into the provider. No
/// network is touched for the lifetime of the session.
///
/// Kept in its own file (no Riverpod / Supabase imports) so both the
/// provider layer and the coordinator can depend on it without cycles.
abstract class LocalGameSession {
  /// Room ids for local sessions start with this prefix. Server rooms use
  /// UUIDs, so no real room id can ever collide with it.
  static const String roomIdPrefix = 'local-';

  /// Whether [roomId] identifies an on-device practice session (as opposed
  /// to a Supabase room).
  static bool isLocalRoomId(String roomId) => roomId.startsWith(roomIdPrefix);

  /// The synthetic room id this session was started with.
  String get roomId;

  /// Handle a move in the same snake_case wire format the game screens
  /// already send to the validate-move edge function
  /// (e.g. `{'type': 'roll', 'player_id': ...}`).
  Future<void> handleWireMove(Map<String, dynamic> move);

  /// Stop bot timers and drop the session. Safe to call more than once.
  void dispose();
}
