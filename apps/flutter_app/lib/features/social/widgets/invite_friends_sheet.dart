import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';
import '../../friends/providers/friends_providers.dart';
import '../providers/messaging_providers.dart';

/// Friends picker used by both room and tournament invites. The caller
/// supplies [onInvite] (typically a typed DM send, which also fires a push
/// via M0); this sheet owns the list, presence dots and sent/busy states.
class InviteFriendsSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String friendId) onInvite;

  const InviteFriendsSheet({super.key, required this.onInvite});

  /// Invite to a waiting game room (game_invite DM, 30-min expiry).
  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String roomCode,
    required String gameType,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (_, ref, __) => InviteFriendsSheet(
          onInvite: (friendId) async {
            final selfId = ref.read(currentUserProvider)?.id;
            if (selfId == null) return;
            await ref.read(directMessageRepositoryProvider).sendGameInvite(
                  senderId: selfId,
                  recipientId: friendId,
                  roomId: roomId,
                  gameType: gameType,
                  roomCode: roomCode,
                  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
                );
          },
        ),
      ),
    );
  }

  /// Invite to a tournament (tournament_invite DM).
  static Future<void> showForTournament(
    BuildContext context, {
    required String tournamentId,
    required String tournamentName,
    required String gameType,
    DateTime? startTime,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (_, ref, __) => InviteFriendsSheet(
          onInvite: (friendId) async {
            final selfId = ref.read(currentUserProvider)?.id;
            if (selfId == null) return;
            await ref
                .read(directMessageRepositoryProvider)
                .sendTournamentInvite(
                  senderId: selfId,
                  recipientId: friendId,
                  tournamentId: tournamentId,
                  tournamentName: tournamentName,
                  gameType: gameType,
                  startTime: startTime,
                );
          },
        ),
      ),
    );
  }

  @override
  ConsumerState<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<InviteFriendsSheet> {
  final _invited = <String>{};
  final _sending = <String>{};

  Future<void> _invite(String friendId) async {
    setState(() => _sending.add(friendId));
    try {
      await widget.onInvite(friendId);
      if (mounted) setState(() => _invited.add(friendId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send the invite")),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(friendId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(acceptedFriendsProvider);
    final selfId = ref.watch(currentUserProvider)?.id;
    final onlineIds = ref.watch(onlineUserIdsProvider);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppColors.feltDark.withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite friends',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 12),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No friends yet — share the room link instead!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textFeltMuted,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in friends)
                      _friendRow(
                        // Friendship rows are directional; the "other" user
                        // is whichever side isn't us.
                        friendId:
                            f.userId == selfId ? f.friendId : f.userId,
                        name: f.friendName ?? 'Friend',
                        online: onlineIds.contains(
                            f.userId == selfId ? f.friendId : f.userId),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _friendRow({
    required String friendId,
    required String name,
    required bool online,
  }) {
    final invited = _invited.contains(friendId);
    final sending = _sending.contains(friendId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accent.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.accent),
                ),
              ),
              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.feltDark, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textOnFelt,
              ),
            ),
          ),
          if (invited)
            const Icon(Icons.check_circle, size: 20, color: AppColors.success)
          else
            SizedBox(
              height: 32,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: sending ? null : () => _invite(friendId),
                child: Text(sending ? '…' : 'Invite'),
              ),
            ),
        ],
      ),
    );
  }
}
