import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_core/social_core.dart' as social_core;

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../social/providers/social_providers.dart';

/// Card for an incoming friend request with Accept/Decline buttons.
class FriendRequestCard extends ConsumerWidget {
  final social_core.Friendship friendship;

  const FriendRequestCard({
    super.key,
    required this.friendship,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderName = friendship.friendName ?? friendship.userId;

    return GlassCard(
      key: Key('friend-request-${friendship.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentSoft.withOpacity(0.3),
            child: Text(
              senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              senderName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Accept
          _ActionButton(
            label: 'Accept',
            color: AppColors.success,
            onTap: () {
              ref
                  .read(friendsRepositoryProvider)
                  .acceptFriendRequest(friendshipId: friendship.id);
            },
          ),
          const SizedBox(width: 6),

          // Decline
          _ActionButton(
            label: 'Decline',
            color: AppColors.danger,
            onTap: () {
              ref
                  .read(friendsRepositoryProvider)
                  .declineFriendRequest(friendshipId: friendship.id);
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
