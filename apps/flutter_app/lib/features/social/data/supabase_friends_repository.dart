import 'dart:async';

import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [FriendsRepository].
class SupabaseFriendsRepository implements FriendsRepository {
  final SupabaseClient _client;

  SupabaseFriendsRepository(this._client);

  @override
  Future<void> sendFriendRequest({
    required String userId,
    required String friendId,
  }) async {
    await _client.from('friendships').insert({
      'user_id': userId,
      'friend_id': friendId,
      'status': 'pending',
    });
  }

  @override
  Future<void> acceptFriendRequest({required String friendshipId}) async {
    await _client.from('friendships').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', friendshipId);
  }

  @override
  Future<void> declineFriendRequest({required String friendshipId}) async {
    await _client.from('friendships').update({
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', friendshipId);
  }

  @override
  Future<void> removeFriend({required String friendshipId}) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  @override
  Future<List<Friendship>> getFriendships({
    required String userId,
    FriendshipStatus? status,
  }) async {
    var query = _client
        .from('friendships')
        .select()
        .or('user_id.eq.$userId,friend_id.eq.$userId');

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query;
    return response.map((row) => Friendship.fromJson(row)).toList();
  }

  @override
  Stream<List<Friendship>> watchFriendships({required String userId}) {
    return _client
        .from('friendships')
        .stream(primaryKey: ['id'])
        .map((rows) {
      return rows
          .where(
              (r) => r['user_id'] == userId || r['friend_id'] == userId)
          .map((row) => Friendship.fromJson(row))
          .toList();
    });
  }

  @override
  Future<List<FriendActivity>> getFriendActivities({
    required String userId,
  }) async {
    // Get accepted friend IDs
    final friendships = await getFriendships(
      userId: userId,
      status: FriendshipStatus.accepted,
    );

    final friendIds = friendships.map((f) {
      return f.userId == userId ? f.friendId : f.userId;
    }).toList();

    if (friendIds.isEmpty) return [];

    // Get profiles with activity
    final profiles = await _client
        .from('profiles')
        .select('id, display_name, username, avatar_url, current_activity')
        .inFilter('id', friendIds);

    return profiles
        .map((p) => FriendActivity.fromProfileJson(p))
        .toList();
  }

  @override
  Stream<List<FriendActivity>> watchFriendActivities({
    required String userId,
  }) {
    // Use a periodic refresh approach since current_activity is JSONB
    // and Supabase stream doesn't support complex cross-table joins.
    // In production, use Supabase Realtime presence instead.
    return Stream.periodic(const Duration(seconds: 10))
        .asyncMap((_) => getFriendActivities(userId: userId));
  }

  @override
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _client.from('user_blocks').insert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  @override
  Future<List<String>> getBlockedUserIds({required String userId}) async {
    final response = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);

    return response.map((r) => r['blocked_id'] as String).toList();
  }
}
