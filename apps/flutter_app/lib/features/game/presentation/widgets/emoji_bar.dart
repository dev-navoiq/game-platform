import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:social_core/social_core.dart';

import '../../../../core/di/providers.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../social/providers/social_providers.dart';

/// Quick emoji reaction bar above the player's hand.
///
/// Visibility respects the room's social mode:
/// - Full / Chat Only: all emojis shown
/// - Focus: limited set (thumbs up, clap only)
/// - Silent: hidden entirely
class EmojiBar extends ConsumerWidget {
  final void Function(String emoji) onEmojiTap;
  final RoomSocialMode socialMode;
  final String? roomId;

  const EmojiBar({
    super.key,
    required this.onEmojiTap,
    required this.socialMode,
    this.roomId,
  });

  static const _fullEmojis = ['👍', '👏', '😂', '😢', '😡', '❤️'];
  static const _focusEmojis = ['👍', '👏'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ChatRules.areReactionsAllowed(socialMode)) {
      return const SizedBox.shrink();
    }

    final emojis =
        socialMode == RoomSocialMode.focus ? _focusEmojis : _fullEmojis;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              onEmojiTap(emoji);
              _sendReaction(ref, emoji);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 29,
                height: 29,
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _sendReaction(WidgetRef ref, String emoji) {
    if (roomId == null) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    ref.read(reactionRepositoryProvider).sendReaction(
          roomId: roomId!,
          userId: userId,
          reaction: emoji,
        );
  }
}
