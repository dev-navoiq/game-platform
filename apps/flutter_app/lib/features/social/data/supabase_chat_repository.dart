import 'dart:async';

import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [ChatRepository].
class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _client;

  SupabaseChatRepository(this._client);

  @override
  Future<void> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    bool isSpectatorChat = false,
  }) async {
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'content': content.trim(),
      'is_spectator_chat': isSpectatorChat,
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String roomId,
    bool? isSpectatorChat,
  }) {
    final query = _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId);

    return query.map((rows) {
      var filtered = rows;
      if (isSpectatorChat != null) {
        filtered = rows
            .where((r) => r['is_spectator_chat'] == isSpectatorChat)
            .toList();
      }

      // Sort by created_at ascending
      filtered.sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));

      return filtered.map((row) {
        return ChatMessage(
          id: row['id'] as String,
          roomId: row['room_id'] as String,
          userId: row['user_id'] as String,
          senderName: row['user_id'] as String, // Will be resolved by UI layer
          content: row['content'] as String,
          isSpectatorChat: row['is_spectator_chat'] as bool? ?? false,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    });
  }

  @override
  Future<List<ChatMessage>> getRecentMessages({
    required String roomId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    return response.reversed.map((row) {
      return ChatMessage(
        id: row['id'] as String,
        roomId: row['room_id'] as String,
        userId: row['user_id'] as String,
        senderName: row['user_id'] as String,
        content: row['content'] as String,
        isSpectatorChat: row['is_spectator_chat'] as bool? ?? false,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _client.from('chat_messages').delete().eq('id', messageId);
  }
}
