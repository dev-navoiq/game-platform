import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_core/social_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../friends/providers/friends_providers.dart';
import '../providers/messaging_providers.dart';

/// Inbox of 1:1 conversations with friends. Each row links into the DM
/// thread. Rows show a green presence dot for friends who are currently
/// in the Realtime presence channel.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(dmInboxProvider);
    final friendActivities = ref.watch(friendActivitiesProvider);
    final onlineIds = ref.watch(onlineUserIdsProvider);
    final selfId = ref.watch(currentUserProvider)?.id;

    // Name lookup from accepted friends (the only people who can DM us).
    final nameById = <String, FriendActivity>{
      for (final f in friendActivities.valueOrNull ?? const <FriendActivity>[])
        f.friendId: f,
    };

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Messages'),
        body: inboxAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Failed to load messages',
              style: TextStyle(color: AppColors.textOnFelt),
            ),
          ),
          data: (threads) {
            // Show all friends as "start a chat" rows when no thread exists,
            // so the screen is useful on a fresh install.
            final friendsWithoutThread = (friendActivities.valueOrNull ??
                    const <FriendActivity>[])
                .where((f) =>
                    !threads.any((t) => t.otherUserId == f.friendId))
                .toList();

            if (threads.isEmpty && friendsWithoutThread.isEmpty) {
              return _EmptyState();
            }

            return ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56 + 12,
                left: 12,
                right: 12,
                bottom: 24,
              ),
              children: [
                if (threads.isNotEmpty) ...[
                  _SectionLabel('Recent'),
                  for (final t in threads)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ThreadTile(
                        thread: t,
                        friend: nameById[t.otherUserId],
                        isOnline: onlineIds.contains(t.otherUserId),
                        isMine: t.lastMessage.senderId == selfId,
                        onTap: () => context.push(
                          AppRoutes.dmThreadPath(t.otherUserId),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (friendsWithoutThread.isNotEmpty) ...[
                  _SectionLabel('Start a chat'),
                  for (final f in friendsWithoutThread)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FriendTile(
                        friend: f,
                        isOnline: onlineIds.contains(f.friendId),
                        onTap: () => context.push(
                          AppRoutes.dmThreadPath(f.friendId),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: AppColors.textFeltMuted),
            const SizedBox(height: 12),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a friend to start chatting and invite them to games.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textFeltMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textFeltMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final DirectMessageThread thread;
  final FriendActivity? friend;
  final bool isOnline;
  final bool isMine;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.thread,
    required this.friend,
    required this.isOnline,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = friend?.displayName ?? 'Friend';
    final lastMsg = thread.lastMessage;
    final preview = switch (lastMsg.type) {
      DirectMessageType.gameInvite =>
        '🎮 ${isMine ? 'You sent' : 'Game invite'}: ${lastMsg.payload?['game_type'] ?? 'a game'}',
      DirectMessageType.system => lastMsg.content,
      DirectMessageType.text =>
        isMine ? 'You: ${lastMsg.content}' : lastMsg.content,
    };

    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _AvatarWithDot(
            name: name,
            avatarUrl: friend?.avatarUrl,
            isOnline: isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(lastMsg.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: thread.unreadCount > 0
                              ? AppColors.textDark
                              : AppColors.textMuted,
                          fontWeight: thread.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (thread.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.accent,
                        ),
                        child: Text(
                          thread.unreadCount > 99
                              ? '99+'
                              : '${thread.unreadCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendActivity friend;
  final bool isOnline;
  final VoidCallback onTap;

  const _FriendTile({
    required this.friend,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _AvatarWithDot(
            name: friend.displayName,
            avatarUrl: friend.avatarUrl,
            isOnline: isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Online — tap to chat' : 'Tap to send a message',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _AvatarWithDot extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isOnline;

  const _AvatarWithDot({
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accent.withOpacity(0.15),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

String _formatTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${t.month}/${t.day}';
}
