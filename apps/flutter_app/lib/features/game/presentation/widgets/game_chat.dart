import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_core/social_core.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../social/providers/social_providers.dart';

/// In-game chat panel that respects social mode.
///
/// Hidden in Silent and Focus modes.
/// Supports spectator chat separation via [isSpectator].
class GameChat extends ConsumerStatefulWidget {
  final RoomSocialMode socialMode;
  final String roomId;
  final bool isSpectator;

  const GameChat({
    super.key,
    required this.socialMode,
    required this.roomId,
    this.isSpectator = false,
  });

  @override
  ConsumerState<GameChat> createState() => _GameChatState();
}

class _GameChatState extends ConsumerState<GameChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ChatRules.isChatAllowed(widget.socialMode)) {
      return const SizedBox.shrink();
    }

    // Watch the appropriate message stream based on spectator status
    final messagesAsync = widget.isSpectator
        ? ref.watch(roomSpectatorChatMessagesProvider(widget.roomId))
        : ref.watch(roomPlayerChatMessagesProvider(widget.roomId));

    final messages = messagesAsync.valueOrNull ?? [];

    return GlassContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: AppColors.textDark, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.isSpectator ? 'Spectator Chat' : 'Chat',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(messages[index]);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.senderName,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Text(
            msg.content,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textDark.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (ChatRules.validateMessage(text) != null) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    ref.read(chatRepositoryProvider).sendMessage(
          roomId: widget.roomId,
          userId: userId,
          content: text,
          isSpectatorChat: widget.isSpectator,
        );
    _controller.clear();
  }
}
