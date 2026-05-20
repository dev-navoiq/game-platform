import 'chat_message.dart';

/// Abstract interface for chat message persistence.
///
/// Implementations handle the actual storage backend (e.g. Supabase).
abstract class ChatRepository {
  /// Send a chat message to a room.
  Future<void> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    bool isSpectatorChat = false,
  });

  /// Watch messages in a room as a stream.
  ///
  /// If [isSpectatorChat] is provided, filters messages by spectator flag.
  /// If null, returns all messages.
  Stream<List<ChatMessage>> watchMessages({
    required String roomId,
    bool? isSpectatorChat,
  });

  /// Get recent messages from a room.
  Future<List<ChatMessage>> getRecentMessages({
    required String roomId,
    int limit = 50,
  });

  /// Delete a message by ID.
  Future<void> deleteMessage(String messageId);
}
