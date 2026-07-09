import 'dart:async';

import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [DirectMessageRepository].
///
/// Streams use `.stream(primaryKey:['id'])` and filter client-side because
/// Supabase realtime can't combine OR conditions on two columns at the
/// query layer. The volume is low (DMs per user, not per app) so the
/// over-fetch is fine.
class SupabaseDirectMessageRepository implements DirectMessageRepository {
  final SupabaseClient _client;

  SupabaseDirectMessageRepository(this._client);

  @override
  Future<void> sendText({
    required String senderId,
    required String recipientId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Cannot send an empty message');
    }
    await _client.from('direct_messages').insert({
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': trimmed,
      'message_type': 'text',
    });
  }

  @override
  Future<void> sendGameInvite({
    required String senderId,
    required String recipientId,
    required String roomId,
    required String gameType,
    required String roomCode,
    DateTime? expiresAt,
  }) async {
    await _client.from('direct_messages').insert({
      'sender_id': senderId,
      'recipient_id': recipientId,
      // Plain-text fallback for clients that don't render the typed bubble.
      'content': 'Invited you to play $gameType (room $roomCode)',
      'message_type': 'game_invite',
      'payload': {
        'room_id': roomId,
        'game_type': gameType,
        'room_code': roomCode,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      },
    });
  }

  @override
  Future<void> sendTournamentInvite({
    required String senderId,
    required String recipientId,
    required String tournamentId,
    required String tournamentName,
    required String gameType,
    DateTime? startTime,
  }) async {
    await _client.from('direct_messages').insert({
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': 'Invited you to the tournament "$tournamentName"',
      'message_type': 'tournament_invite',
      'payload': {
        'tournament_id': tournamentId,
        'name': tournamentName,
        'game_type': gameType,
        if (startTime != null) 'start_time': startTime.toIso8601String(),
      },
    });
  }

  @override
  Stream<List<DirectMessage>> watchThread({
    required String userAId,
    required String userBId,
  }) {
    return _client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .map((rows) {
      final filtered = rows.where((r) {
        final s = r['sender_id'] as String?;
        final t = r['recipient_id'] as String?;
        return (s == userAId && t == userBId) ||
            (s == userBId && t == userAId);
      }).toList()
        ..sort((a, b) {
          final ca = DateTime.parse(a['created_at'] as String);
          final cb = DateTime.parse(b['created_at'] as String);
          return ca.compareTo(cb);
        });

      return filtered.map(DirectMessage.fromJson).toList();
    });
  }

  @override
  Stream<List<DirectMessageThread>> watchInbox({
    required String currentUserId,
  }) {
    return _client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .map((rows) => _foldToThreads(rows, currentUserId));
  }

  /// Groups raw DM rows by the "other" user and computes unread counts.
  List<DirectMessageThread> _foldToThreads(
    List<Map<String, dynamic>> rows,
    String currentUserId,
  ) {
    final latestByOther = <String, DirectMessage>{};
    final unreadByOther = <String, int>{};

    for (final row in rows) {
      final senderId = row['sender_id'] as String?;
      final recipientId = row['recipient_id'] as String?;
      if (senderId == null || recipientId == null) continue;

      final otherId =
          senderId == currentUserId ? recipientId : senderId;
      if (otherId == currentUserId) continue; // self-message; can't happen

      final msg = DirectMessage.fromJson(row);

      // Keep the newest message per thread.
      final existing = latestByOther[otherId];
      if (existing == null || msg.createdAt.isAfter(existing.createdAt)) {
        latestByOther[otherId] = msg;
      }

      // Count unread incoming.
      if (msg.recipientId == currentUserId && msg.readAt == null) {
        unreadByOther[otherId] = (unreadByOther[otherId] ?? 0) + 1;
      }
    }

    final threads = latestByOther.entries
        .map((e) => DirectMessageThread(
              otherUserId: e.key,
              lastMessage: e.value,
              unreadCount: unreadByOther[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) =>
          b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));

    return threads;
  }

  @override
  Future<int> markThreadRead({required String otherUserId}) async {
    final response = await _client.rpc(
      'mark_thread_read',
      params: {'p_other_user_id': otherUserId},
    );
    if (response is int) return response;
    if (response is num) return response.toInt();
    return 0;
  }
}
