import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_core/social_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../providers/messaging_providers.dart';

/// 1:1 chat with one friend. Text input + a "Invite to play" button that
/// opens a quick game picker, creates a room via the create-room edge
/// function, and posts a `game_invite` DM with the room reference.
class DmThreadScreen extends ConsumerStatefulWidget {
  final String otherUserId;

  const DmThreadScreen({super.key, required this.otherUserId});

  @override
  ConsumerState<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends ConsumerState<DmThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    // Best-effort read receipt on entry. Fire-and-forget — RLS guards
    // against doing this for someone else's thread.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(directMessageRepositoryProvider)
          .markThreadRead(otherUserId: widget.otherUserId)
          .catchError((_) => 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final selfId = ref.read(currentUserProvider)?.id;
    if (selfId == null) return;

    setState(() => _isSending = true);
    _controller.clear();
    try {
      await ref.read(directMessageRepositoryProvider).sendText(
            senderId: selfId,
            recipientId: widget.otherUserId,
            content: text,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t send: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openInvitePicker() async {
    if (_isInviting) return;
    final gameType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GamePickerSheet(),
    );
    if (gameType == null || !mounted) return;
    await _sendGameInvite(gameType);
  }

  Future<void> _sendGameInvite(String gameType) async {
    final selfId = ref.read(currentUserProvider)?.id;
    if (selfId == null) return;

    setState(() => _isInviting = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);

      // Create a private friends-only room. social_mode=full matches the
      // existing manual-create flow defaults.
      final room = await supabase.createRoom(
        gameType: gameType,
        socialMode: 'full',
        maxPlayers: 4,
        isPrivate: true,
      );

      final roomId = room['id'] as String? ?? room['room_id'] as String?;
      final roomCode = room['code'] as String? ?? room['room_code'] as String?;

      if (roomId == null || roomCode == null) {
        throw StateError('create-room returned no room id/code');
      }

      await ref.read(directMessageRepositoryProvider).sendGameInvite(
            senderId: selfId,
            recipientId: widget.otherUserId,
            roomId: roomId,
            gameType: gameType,
            roomCode: roomCode,
            expiresAt: DateTime.now().add(const Duration(minutes: 30)),
          );

      if (!mounted) return;
      // Take the sender straight to the room so they can wait for the
      // friend to accept — matches how the manual create-room flow works.
      context.push(AppRoutes.roomPath(roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t send invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfId = ref.watch(currentUserProvider)?.id;
    final threadAsync = ref.watch(dmThreadProvider(widget.otherUserId));
    final peerProfile =
        ref.watch(dmPeerProfileProvider(widget.otherUserId)).valueOrNull;
    final isOnline = ref
        .watch(onlineUserIdsProvider)
        .contains(widget.otherUserId);

    final peerName = peerProfile?['display_name'] as String? ??
        peerProfile?['username'] as String? ??
        'Friend';
    final peerAvatar = peerProfile?['avatar_url'] as String?;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.2),
          elevation: 0,
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    backgroundImage:
                        peerAvatar != null ? NetworkImage(peerAvatar) : null,
                    child: peerAvatar == null
                        ? Text(
                            peerName.isNotEmpty
                                ? peerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
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
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.feltDark, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnFelt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? AppColors.success
                            : AppColors.textFeltMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Invite to play',
              icon: _isInviting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : const Icon(Icons.sports_esports,
                      color: AppColors.accent),
              onPressed: _isInviting ? null : _openInvitePicker,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: threadAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Couldn\'t load messages',
                      style: TextStyle(color: AppColors.textOnFelt),
                    ),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No messages yet — say hi or send a game invite.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textFeltMuted,
                            ),
                          ),
                        ),
                      );
                    }
                    // newest at the bottom; reverse: true keeps the latest
                    // visible without manual scroll-to-end.
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg.senderId == selfId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: msg.isGameInvite
                              ? _GameInviteBubble(
                                  message: msg,
                                  isMe: isMe,
                                )
                              : _TextBubble(message: msg, isMe: isMe),
                        );
                      },
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _controller,
                isSending: _isSending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bubbles
// ─────────────────────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final DirectMessage message;
  final bool isMe;
  const _TextBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accent.withOpacity(0.28)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textOnFelt,
          ),
        ),
      ),
    );
  }
}

class _GameInviteBubble extends ConsumerStatefulWidget {
  final DirectMessage message;
  final bool isMe;
  const _GameInviteBubble({required this.message, required this.isMe});

  @override
  ConsumerState<_GameInviteBubble> createState() =>
      _GameInviteBubbleState();
}

class _GameInviteBubbleState extends ConsumerState<_GameInviteBubble> {
  bool _isJoining = false;

  Future<void> _accept() async {
    if (_isJoining) return;
    final payload = widget.message.payload;
    final roomId = payload?['room_id'] as String?;
    if (roomId == null) return;

    setState(() => _isJoining = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .joinRoom(roomId: roomId);
      if (!mounted) return;
      context.push(AppRoutes.roomPath(roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t join: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.message.payload ?? const {};
    final gameType = payload['game_type'] as String? ?? 'a game';
    final roomCode = payload['room_code'] as String? ?? '';
    final expiresAtStr = payload['expires_at'] as String?;
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
    final isExpired =
        expiresAt != null && DateTime.now().isAfter(expiresAt);

    return Align(
      alignment:
          widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  widget.isMe ? 'You invited to play' : 'Game invite',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _friendlyGameType(gameType),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            if (roomCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Room $roomCode',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textFeltMuted,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (widget.isMe)
              Text(
                isExpired ? 'Invite expired' : 'Waiting for response…',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textFeltMuted,
                ),
              )
            else if (isExpired)
              Text(
                'This invite has expired',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textFeltMuted,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isJoining ? null : _accept,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Accept & join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 4,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      color: Colors.black.withOpacity(0.25),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  color: AppColors.textOnFelt, fontSize: 14),
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: AppColors.textFeltMuted),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.10),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.send, color: AppColors.accent),
            onPressed: isSending ? null : onSend,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game picker sheet for "Invite to play"
// ─────────────────────────────────────────────────────────────────────────────

class _GamePickerSheet extends StatelessWidget {
  const _GamePickerSheet();

  static const _options = <(String, String, IconData)>[
    ('twenty_nine', 'Twenty-Nine', Icons.style),
    ('oh_hell', 'Oh Hell', Icons.whatshot),
    ('hearts', 'Hearts', Icons.favorite),
    ('spades', 'Spades', Icons.eco),
    ('bridge', 'Bridge', Icons.dashboard),
    ('ludo', 'Ludo', Icons.grid_view),
    ('sequence', 'Sequence', Icons.apps),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Invite to play',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnFelt,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creates a private room and sends an invite to your friend.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textFeltMuted,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final opt in _options)
                _GameChoice(
                  gameType: opt.$1,
                  label: opt.$2,
                  icon: opt.$3,
                  onTap: () => Navigator.of(context).pop(opt.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameChoice extends StatelessWidget {
  final String gameType;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GameChoice({
    required this.gameType,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyGameType(String raw) => switch (raw) {
      'twenty_nine' => 'Twenty-Nine',
      'oh_hell' => 'Oh Hell',
      'hearts' => 'Hearts',
      'spades' => 'Spades',
      'bridge' => 'Bridge',
      'chess' => 'Chess',
      'ludo' => 'Ludo',
      'sequence' => 'Sequence',
      _ => raw,
    };
