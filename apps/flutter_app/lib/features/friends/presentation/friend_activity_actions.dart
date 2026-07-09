import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_core/social_core.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';

/// Context action for a friend-activity card: join their lobby when
/// joinable, spectate their game when watchable, otherwise open the DM
/// thread. (Was a TODO since the M1+M3 beta shortcuts.)
Future<void> handleFriendActivityAction(
  BuildContext context,
  WidgetRef ref,
  FriendActivity friend,
) async {
  final roomId = friend.roomId;

  if (friend.isJoinable && roomId != null) {
    try {
      await ref.read(supabaseServiceProvider).joinRoom(roomId: roomId);
      if (context.mounted) context.push(AppRoutes.roomPath(roomId));
    } catch (e) {
      if (context.mounted) {
        final message = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.contains('room_full')
                ? 'Their room is already full'
                : "Couldn't join their room"),
          ),
        );
      }
    }
    return;
  }

  if (friend.isWatchable && roomId != null) {
    try {
      await ref
          .read(supabaseServiceProvider)
          .joinRoom(roomId: roomId, asSpectator: true);
      if (context.mounted) context.push(AppRoutes.gamePath(roomId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't spectate this game")),
        );
      }
    }
    return;
  }

  if (context.mounted) {
    context.push(AppRoutes.dmThreadPath(friend.friendId));
  }
}
