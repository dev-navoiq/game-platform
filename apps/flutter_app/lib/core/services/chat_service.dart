import '../config/constants.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseService _supabase;

  ChatService({required SupabaseService supabase}) : _supabase = supabase;

  Future<void> sendMessage({
    required String roomId,
    required String message,
    required String senderId,
  }) async {
    final trimmed = message.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    if (trimmed.length > AppConstants.maxChatMessageLength) {
      throw ArgumentError(
        'Message exceeds maximum length of ${AppConstants.maxChatMessageLength} characters',
      );
    }

    await _supabase.insertChatMessage(
      roomId: roomId,
      message: trimmed,
      senderId: senderId,
    );
  }

  void subscribeToMessages({
    required String roomId,
    required Function onMessage,
  }) {
    _supabase.subscribeToRoomMessages(
      roomId: roomId,
      onMessage: onMessage,
    );
  }
}
