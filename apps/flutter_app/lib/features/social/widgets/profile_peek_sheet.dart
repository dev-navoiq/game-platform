import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../friends/data/discovery_repository.dart';
import '../providers/social_providers.dart';
import 'report_user_sheet.dart';

/// The universal social hub: tap any player anywhere → this sheet.
/// Shows identity + context actions (add/accept, message, block, report).
class ProfilePeekSheet extends ConsumerStatefulWidget {
  final DiscoveredPlayer player;

  const ProfilePeekSheet({super.key, required this.player});

  static Future<void> show(BuildContext context, DiscoveredPlayer player) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfilePeekSheet(player: player),
    );
  }

  @override
  ConsumerState<ProfilePeekSheet> createState() => _ProfilePeekSheetState();
}

class _ProfilePeekSheetState extends ConsumerState<ProfilePeekSheet> {
  late bool _requestPending = widget.player.requestPending;
  bool _busy = false;

  Future<void> _sendRequest() async {
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(friendsRepositoryProvider).sendFriendRequest(
            userId: currentUserId,
            friendId: widget.player.id,
          );
      if (mounted) setState(() => _requestPending = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send the request")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block() async {
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${widget.player.name}?'),
        content: const Text(
            "They won't be able to message you or join your rooms."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(friendsRepositoryProvider).blockUser(
          blockerId: currentUserId,
          blockedId: widget.player.id,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.feltDark.withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent.withOpacity(0.2),
              backgroundImage:
                  p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
              child: p.avatarUrl == null
                  ? Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              p.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            Text(
              '@${p.username} · Level ${p.level}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            if (p.gamesTogether > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  p.gamesTogether == 1
                      ? 'Played 1 game together'
                      : 'Played ${p.gamesTogether} games together',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _primaryAction(context)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _block,
                    icon: const Icon(Icons.block,
                        size: 18, color: AppColors.textMuted),
                    label: Text(
                      'Block',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ReportUserSheet.show(
                        context,
                        targetId: p.id,
                        targetName: p.name,
                        reportContext: 'profile',
                      );
                    },
                    icon: const Icon(Icons.flag_outlined,
                        size: 18, color: AppColors.textMuted),
                    label: Text(
                      'Report',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryAction(BuildContext context) {
    final p = widget.player;
    if (p.isFriend) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
        onPressed: () {
          Navigator.pop(context);
          context.push(AppRoutes.dmThreadPath(p.id));
        },
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('Message'),
      );
    }
    if (_requestPending) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textMuted.withOpacity(0.25),
        ),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top, size: 18),
        label: const Text('Request pending'),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
      onPressed: _busy ? null : _sendRequest,
      icon: const Icon(Icons.person_add_alt, size: 18),
      label: const Text('Add friend'),
    );
  }
}
