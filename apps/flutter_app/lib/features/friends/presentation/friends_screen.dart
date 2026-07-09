import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/friend_activity_card.dart';
import '../../../shared/widgets/glass_container.dart';
import '../providers/friends_providers.dart';
import '../../social/providers/social_providers.dart';
import 'widgets/friend_request_card.dart';

/// Full friends management screen with three tabs:
/// Friends, Requests, and Blocked.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: const Key('friends-screen'),
        appBar: AppBar(
          title: const Text('Friends & Activity'),
          actions: [
            IconButton(
              key: const Key('add-friends-button'),
              tooltip: 'Add friends',
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => context.push(AppRoutes.addFriends),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('friends-tab'), text: 'Friends'),
              Tab(key: Key('requests-tab'), text: 'Requests'),
              Tab(key: Key('blocked-tab'), text: 'Blocked'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsTab(),
            _RequestsTab(),
            _BlockedTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab showing accepted friends with activity status.
class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(friendActivitiesProvider);

    return activities.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No friends yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.addFriends),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Find friends'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FriendActivityCard(
                displayName: friend.displayName,
                avatarUrl: friend.avatarUrl,
                status: friend.status.toWidgetStatus(),
                gameType: friend.gameType,
                statusDetail: friend.statusDetail,
                roomId: friend.roomId,
                onAction: () => context.push(
                  AppRoutes.dmThreadPath(friend.friendId),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Failed to load friends', style: TextStyle(color: AppColors.danger)),
      ),
    );
  }
}

/// Tab showing pending incoming friend requests.
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestsProvider);

    if (pending.isEmpty) {
      return const Center(
        child: Text(
          'No pending requests',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FriendRequestCard(friendship: pending[index]),
        );
      },
    );
  }
}

/// Tab showing blocked users with unblock option.
class _BlockedTab extends ConsumerWidget {
  const _BlockedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);

    if (blocked.isEmpty) {
      return const Center(
        child: Text(
          'No blocked users',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: blocked.length,
      itemBuilder: (context, index) {
        final user = blocked[index];
        final name = user.friendName ?? user.friendId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.textMuted.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final currentUserId = ref.read(
                      currentUserProvider.select((u) => u?.id),
                    );
                    if (currentUserId == null) return;
                    ref.read(friendsRepositoryProvider).unblockUser(
                          blockerId: currentUserId,
                          blockedId: user.friendId,
                        );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
