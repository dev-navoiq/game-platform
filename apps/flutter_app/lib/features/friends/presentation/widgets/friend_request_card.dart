import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_core/social_core.dart' as social_core;

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../social/providers/social_providers.dart';

/// Card for an incoming friend request with Accept/Decline buttons.
class FriendRequestCard extends ConsumerStatefulWidget {
  final social_core.Friendship friendship;

  const FriendRequestCard({
    super.key,
    required this.friendship,
  });

  @override
  ConsumerState<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<FriendRequestCard> {
  bool _busy = false;

  Future<void> _respond({required bool accept}) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(friendsRepositoryProvider);
      if (accept) {
        await repo.acceptFriendRequest(friendshipId: widget.friendship.id);
      } else {
        await repo.declineFriendRequest(friendshipId: widget.friendship.id);
      }
      // The friendships stream refreshes the list; nothing else to do.
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update the request")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendship = widget.friendship;
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

          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            // Accept
            FilledButton(
              key: Key('accept-request-${friendship.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _respond(accept: true),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 6),

            // Decline
            OutlinedButton(
              key: Key('decline-request-${friendship.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withOpacity(0.6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _respond(accept: false),
              child: const Text('Decline'),
            ),
          ],
        ],
      ),
    );
  }
}
