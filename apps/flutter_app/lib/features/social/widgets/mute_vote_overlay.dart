import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_core/social_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../providers/social_providers.dart';

/// Glass-styled overlay for democratic mute voting.
///
/// Shows a progress bar indicating votes cast vs votes needed,
/// with "Vote to Mute" and "Keep" buttons.
class MuteVoteOverlay extends ConsumerWidget {
  final String roomId;
  final String targetId;
  final String targetName;
  final int playerCount;
  final VoidCallback onDismiss;

  const MuteVoteOverlay({
    super.key,
    required this.roomId,
    required this.targetId,
    required this.targetName,
    required this.playerCount,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final votesAsync = ref.watch(roomMuteVotesProvider(roomId));
    final votes = votesAsync.valueOrNull ?? [];
    final targetVotes =
        votes.where((v) => v.targetId == targetId).toList();
    final voteCount = targetVotes.length;
    final required = MuteCalculator.votesRequired(playerCount);
    final progress = required > 0 ? (voteCount / required).clamp(0.0, 1.0) : 0.0;
    final remaining = MuteCalculator.votesNeeded(
      currentVotes: voteCount,
      playerCount: playerCount,
    );

    return Center(
      child: GlassContainer(
        width: 280,
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mute $targetName?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '$voteCount / $required votes${remaining > 0 ? ' ($remaining more needed)' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Keep',
                    variant: GlassButtonVariant.outlined,
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Vote to Mute',
                    onPressed: () => _castVote(ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _castVote(WidgetRef ref) {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    ref.read(moderationRepositoryProvider).castMuteVote(
          roomId: roomId,
          voterId: userId,
          targetId: targetId,
        );
    onDismiss();
  }
}
