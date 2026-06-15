import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_core/social_core.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/gameplay/turn_indicator_animation.dart';
import '../../../../shared/widgets/floating_chat_bubble.dart';
import '../../../../shared/animations/celebrations/loser_sad_animation.dart';
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
  final bool isBot;
  final bool isSmall;
  final bool isSpectator;
  final RoomSocialMode socialMode;
  final String? chatMessage;
  final bool showBidPill;
  final bool hasBid;
  final String? roomId;
  final String? playerId;
  final GlobalKey? nodeKey;
  final bool isTrickWinnerPulsing;

  /// Oh Hell only: the player won this trick BUT had already met or
  /// exceeded their bid, so the extra trick is bad news. When true,
  /// PlayerNode shows a brief sad shake instead of a celebratory jump,
  /// and skips the gold pulse ring.
  final bool isTrickWinnerBusted;

  /// Brief shout-style speech bubble that appears above the avatar. Used
  /// at game end to render "yay!" for winners and "oh hell" for losers.
  /// `null` = no bubble.
  final String? reactionEmote;

  /// Between-rounds ready state. `null` = hidden (round in progress).
  /// `true` = ready, `false` = waiting. Bots auto-ready so callers pass
  /// `true` for them.
  final bool? isReady;

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
    this.isBot = false,
    this.isSmall = false,
    this.isSpectator = false,
    this.socialMode = RoomSocialMode.full,
    this.chatMessage,
    this.showBidPill = true,
    this.hasBid = true,
    this.roomId,
    this.playerId,
    this.nodeKey,
    this.isTrickWinnerPulsing = false,
    this.isTrickWinnerBusted = false,
    this.reactionEmote,
    this.isReady,
  });

  double get _avatarSize => isSmall ? 42.0 : 48.0;

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

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game-end reaction bubble: rendered as a small accent pill above
        // everything else so winners shouting "yay!" and losers wailing
        // "oh hell" are unmistakable. Takes precedence over chat bubble.
        if (reactionEmote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _ReactionBubble(text: reactionEmote!),
          ),

        // Chat bubble above (hidden when reactionEmote is shown).
        if (showBubble && reactionEmote == null)
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
              if (isTrickWinnerPulsing) _buildWinnerPulse(),
              if (isDealer && !hasPlayed) _buildDealerBadge(),
              if (hasPlayed) _buildPlayedBadge(),
              // Top-left corner: tiny "BOT" tag so humans aren't confused
              // for bots at a glance. Humans get no badge — the absence is
              // the signal.
              if (isBot) _buildBotBadge(),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Name — tinted slightly accent for humans so they read as players
        // rather than generic seats. Bots keep the muted treatment.
        SizedBox(
          width: 60,
          child: Text(
            name.length > 9 ? '${name.substring(0, 8)}…' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmall ? 8.5 : 9.0,
              fontWeight: FontWeight.w700,
              color: isBot
                  ? Colors.white.withOpacity(0.52)
                  : Colors.white.withOpacity(0.92),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Bid pill (suppressed between rounds — the ready chip takes its slot).
        if (isReady == null && showBidPill)
          BidPill(won: won, bid: bid, hasBid: hasBid),

        // Ready chip — shown only between rounds. Replaces the bid pill
        // visually so the player area stays vertically compact.
        if (isReady != null) _buildReadyChip(),
      ],
    );

    // Trick-end reaction: celebrate (jump) when the player won and is
    // still on-track, or regret (sad shake + droop) when they won the
    // trick but had already met/exceeded their bid (Oh Hell). The pulse
    // ring is skipped in the busted case — gold + glow read as celebration.
    final Widget celebrated;
    if (isTrickWinnerBusted) {
      celebrated = LoserSadAnimation(
        key: ValueKey('trick-busted-${playerId ?? name}'),
        child: content,
      );
    } else if (isTrickWinnerPulsing) {
      celebrated = _TrickWinnerJump(child: content);
    } else {
      celebrated = content;
    }

    if (nodeKey != null) {
      return KeyedSubtree(key: nodeKey!, child: celebrated);
    }
    return celebrated;
  }

  Widget _buildReadyChip() {
    final ready = isReady ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ready
            ? AppColors.success.withOpacity(0.18)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ready
              ? AppColors.success.withOpacity(0.55)
              : Colors.white.withOpacity(0.25),
          width: 1.0,
        ),
      ),
      child: Text(
        ready ? 'READY ✓' : 'WAITING',
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: ready
              ? AppColors.success
              : Colors.white.withOpacity(0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildWinnerPulse() {
    return Positioned.fill(
      child: IgnorePointer(
        child: _WinnerPulseRing(size: _avatarSize),
      ),
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

  Widget _buildBotBadge() {
    return Positioned(
      top: -2,
      left: -2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 0.75,
          ),
        ),
        child: Text(
          'BOT',
          style: GoogleFonts.poppins(
            fontSize: 7,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.85),
            letterSpacing: 0.3,
          ),
        ),
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

class _WinnerPulseRing extends StatefulWidget {
  final double size;

  const _WinnerPulseRing({required this.size});

  @override
  State<_WinnerPulseRing> createState() => _WinnerPulseRingState();
}

class _WinnerPulseRingState extends State<_WinnerPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Longer + bigger ring so the winner's seat reads as a celebratory
      // beat (was 600ms → 40px; now 1300ms → 64px). Still one-shot so
      // pumpAndSettle in tests doesn't hang.
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final radius = 64.0 * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        // The pulse expands well past the avatar's bounds. The parent
        // Stack uses clipBehavior: Clip.none, but Positioned.fill still
        // hands down tight constraints that match the avatar size. Without
        // OverflowBox here, a Container wider than the avatar throws a
        // "RenderFlex overflowed" warning (the yellow-stripe bars).
        return Center(
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Container(
              width: widget.size + radius * 2,
              height: widget.size + radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(opacity),
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(opacity * 0.7),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One-shot jump for the trick winner — translateY bounces up and back
/// down once over ~600ms. Used INSTEAD of a winner-message banner; the
/// movement is the celebratory signal.
class _TrickWinnerJump extends StatefulWidget {
  final Widget child;

  const _TrickWinnerJump({required this.child});

  @override
  State<_TrickWinnerJump> createState() => _TrickWinnerJumpState();
}

class _TrickWinnerJumpState extends State<_TrickWinnerJump>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _translateY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -20.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -20.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 1.4,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translateY,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Glass-pill shout used at game end (`yay!`, `oh hell`). Visible-on-felt
/// styling — accent gold body, dark text, soft glow.
class _ReactionBubble extends StatelessWidget {
  final String text;

  const _ReactionBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.45),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
