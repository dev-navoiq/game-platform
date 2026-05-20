import 'friend_activity.dart';
import 'friendship.dart';

/// Abstract interface for friend-related operations.
///
/// Implementations handle the actual storage backend (e.g. Supabase).
abstract class FriendsRepository {
  /// Send a friend request.
  Future<void> sendFriendRequest({
    required String userId,
    required String friendId,
  });

  /// Accept a pending friend request.
  Future<void> acceptFriendRequest({required String friendshipId});

  /// Decline a pending friend request.
  Future<void> declineFriendRequest({required String friendshipId});

  /// Remove an accepted friend.
  Future<void> removeFriend({required String friendshipId});

  /// Get friendships for a user, optionally filtered by status.
  Future<List<Friendship>> getFriendships({
    required String userId,
    FriendshipStatus? status,
  });

  /// Watch friendships as a real-time stream.
  Stream<List<Friendship>> watchFriendships({required String userId});

  /// Get friend activity list (who's online, in-game, etc.).
  Future<List<FriendActivity>> getFriendActivities({required String userId});

  /// Watch friend activities as a real-time stream.
  Stream<List<FriendActivity>> watchFriendActivities({
    required String userId,
  });

  /// Block a user.
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  });

  /// Unblock a user.
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  });

  /// Get list of blocked user IDs.
  Future<List<String>> getBlockedUserIds({required String userId});
}
