import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_core/social_core.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/gameplay/turn_indicator_animation.dart';
import '../../../../shared/widgets/floating_chat_bubble.dart';
import '../../../social/providers/social_providers.dart';
import 'bid_pill.dart';

/// Floating player avatar node with name, bid pill, and optional chat bubble.
///
/// Sits directly on the felt — no containing glass box.
/// When [roomId] and [playerId] are provided, watches for incoming
/// chat messages and reactions to display as floating bubbles.
class PlayerNode extends ConsumerWidget {
  final String name;
  final String? avatarUrl;
  final String emoji;
  final int won;
  final int bid;
  final bool isActive;
  final bool hasPlayed;
  final bool isDealer;
  final bool isSmall;
  final bool isSpectator;
  final RoomSocialMode socialMode;
  final String? chatMessage;
  final bool showBidPill;
  final String? roomId;
  final String? playerId;

  const PlayerNode({
    super.key,
    required this.name,
    this.avatarUrl,
    this.emoji = '🐯',
    this.won = 0,
    this.bid = 0,
    this.isActive = false,
    this.hasPlayed = false,
    this.isDealer = false,
    this.isSmall = false,
    this.isSpectator = false,
    this.socialMode = RoomSocialMode.full,
    this.chatMessage,
    this.showBidPill = true,
    this.roomId,
    this.playerId,
  });

  double get _avatarSize => isSmall ? 36.0 : 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine bubble content: prefer provider-driven, fall back to prop
    String? bubbleText = chatMessage;
    bool isEmote = false;

    if (roomId != null &&
        playerId != null &&
        ChatRules.areBubblesAllowed(socialMode)) {
      final latestReactions =
          ref.watch(latestReactionByPlayerProvider(roomId!));
      final latestChats = ref.watch(latestChatByPlayerProvider(roomId!));

      final reaction = latestReactions[playerId];
      final chat = latestChats[playerId];

      if (reaction != null) {
        bubbleText = reaction.reaction;
        isEmote = true;
      } else if (chat != null) {
        bubbleText = chat.content;
      }
    }

    final showBubble =
        bubbleText != null && ChatRules.areBubblesAllowed(socialMode);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chat bubble above
        if (showBubble)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FloatingChatBubble(
              message: bubbleText,
              isEmoteOnly: isEmote,
            ),
          ),

        // Avatar with turn indicator
        TurnIndicatorAnimation(
          isActive: isActive,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(),
              if (isDealer && !hasPlayed) _buildDealerBadge(),
              if (hasPlayed) _buildPlayedBadge(),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Name
        SizedBox(
          width: 54,
          child: Text(
            name.length > 8 ? '${name.substring(0, 7)}…' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmall ? 8.5 : 9.0,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.52),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Bid pill
        if (showBidPill) BidPill(won: won, bid: bid),
      ],
    );
  }

  Widget _buildAvatar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.avatarBg1, AppColors.avatarBg2],
        ),
        border: Border.all(
          color: isActive ? AppColors.accent : Colors.white.withOpacity(0.8),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppColors.accentGlow,
              blurRadius: 12,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: _avatarSize * 0.50)),
      ),
    );
  }

  Widget _buildDealerBadge() {
    return Positioned(
      bottom: -2,
      right: -2,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        ),
        child: Center(
          child: Text(
            'D',
            style: GoogleFonts.poppins(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayedBadge() {
    return Positioned(
      bottom: -2,
      right: -2,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.95),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '✓',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
