import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_core/social_core.dart' as social_core;

import '../../../core/di/providers.dart';
import '../../../shared/widgets/friend_activity_card.dart';
import '../../social/providers/social_providers.dart';

// ── Stream providers ──

final friendshipsProvider =
    StreamProvider<List<social_core.Friendship>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value([]);
  return ref
      .watch(friendsRepositoryProvider)
      .watchFriendships(userId: userId);
});

final friendActivitiesProvider =
    StreamProvider<List<social_core.FriendActivity>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value([]);
  return ref
      .watch(friendsRepositoryProvider)
      .watchFriendActivities(userId: userId);
});

// ── Derived providers ──

final pendingRequestsProvider =
    Provider<List<social_core.Friendship>>((ref) {
  final friendships = ref.watch(friendshipsProvider).valueOrNull ?? [];
  final userId = ref.watch(currentUserProvider)?.id;
  return friendships
      .where(
        (f) =>
            f.status == social_core.FriendshipStatus.pending &&
            f.friendId == userId,
      )
      .toList();
});

final acceptedFriendsProvider =
    Provider<List<social_core.Friendship>>((ref) {
  final friendships = ref.watch(friendshipsProvider).valueOrNull ?? [];
  return friendships
      .where((f) => f.status == social_core.FriendshipStatus.accepted)
      .toList();
});

final blockedUsersProvider =
    Provider<List<social_core.Friendship>>((ref) {
  final friendships = ref.watch(friendshipsProvider).valueOrNull ?? [];
  return friendships
      .where((f) => f.status == social_core.FriendshipStatus.blocked)
      .toList();
});

// ── Status mapper ──

/// Maps social_core [FriendActivityType] to the widget's [FriendActivityStatus].
extension FriendActivityTypeMapper on social_core.FriendActivityType {
  FriendActivityStatus toWidgetStatus() {
    switch (this) {
      case social_core.FriendActivityType.inGame:
        return FriendActivityStatus.inGame;
      case social_core.FriendActivityType.inLobby:
        return FriendActivityStatus.inLobby;
      case social_core.FriendActivityType.online:
        return FriendActivityStatus.online;
      case social_core.FriendActivityType.offline:
        return FriendActivityStatus.offline;
    }
  }
}
