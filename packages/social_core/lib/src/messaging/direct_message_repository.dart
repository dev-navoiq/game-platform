import 'direct_message.dart';

/// Persistence for 1:1 direct messages. Implementations point at Supabase
/// in production and at in-memory fakes in tests.
abstract class DirectMessageRepository {
  /// Send a free-form text message to [recipientId].
  Future<void> sendText({
    required String senderId,
    required String recipientId,
    required String content,
  });

  /// Send a typed `game_invite` message carrying a room reference. The
  /// recipient renders this with an Accept button that calls join-room.
  Future<void> sendGameInvite({
    required String senderId,
    required String recipientId,
    required String roomId,
    required String gameType,
    required String roomCode,
    DateTime? expiresAt,
  });

  /// Watch the thread between [userAId] and [userBId] in chronological
  /// order. RLS in production enforces that the caller is one of the two
  /// IDs.
  Stream<List<DirectMessage>> watchThread({
    required String userAId,
    required String userBId,
  });

  /// Watch every DM the current user is a party to, rolled up into one
  /// thread per other-user. Used by the inbox screen.
  Stream<List<DirectMessageThread>> watchInbox({required String currentUserId});

  /// Mark every unread incoming message from [otherUserId] as read. Returns
  /// the number of rows updated. Implementations should do this in one
  /// round-trip (an RPC, not a select-then-update loop).
  Future<int> markThreadRead({required String otherUserId});
}
