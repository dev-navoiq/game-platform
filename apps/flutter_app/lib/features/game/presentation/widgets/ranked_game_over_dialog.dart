import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/game_end_ad_controller.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/animations/celebrations/confetti_animation.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';

/// One row of the final standings fed into [RankedGameOverDialog].
class RankedPlayerResult {
  final String playerId;
  final String name;
  final String emoji;
  final int score;
  final bool isLocal;

  const RankedPlayerResult({
    required this.playerId,
    required this.name,
    required this.emoji,
    required this.score,
    required this.isLocal,
  });
}

/// End-game modal for ranked (everyone-for-themselves) games like Oh Hell,
/// Hearts, and Rummy — a podium replaces [GameOverDialog]'s binary
/// win/lose treatment: crown on the topper, silver/bronze for 2nd and 3rd,
/// and sulking rows for everyone below the podium.
///
/// Like [GameOverDialog], this is the game-end interstitial hook: it
/// notifies [GameEndAdController] on first frame, which applies the tier +
/// cadence gating. The game is already over here, so it can never fire
/// mid-game.
class RankedGameOverDialog extends ConsumerStatefulWidget {
  /// Standings in any order; the dialog sorts by score descending and
  /// assigns tied players the same rank (competition ranking).
  final List<RankedPlayerResult> results;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeave;

  /// Label for the primary action. Tournament matches override this to
  /// "View Bracket" — replaying a bracket match is not a thing (#176).
  final String playAgainLabel;

  // Reward display
  final int coinsEarned;
  final int xpEarned;

  /// Gems are never granted at regular game end — this only renders for
  /// flows that do pay gems (e.g. tournament payouts routed through the
  /// dialog). Hidden when 0 (#55).
  final int gemsEarned;
  final VoidCallback? onDoubleCoins;

  /// Optional one-liner under the reward chips (e.g. "Includes first win of
  /// the day 🌟" or "Daily earn limit reached"). Hidden when null.
  final String? rewardNote;

  const RankedGameOverDialog({
    super.key,
    required this.results,
    this.onPlayAgain,
    this.onLeave,
    this.playAgainLabel = 'Play Again',
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.gemsEarned = 0,
    this.onDoubleCoins,
    this.rewardNote,
  });

  @override
  ConsumerState<RankedGameOverDialog> createState() =>
      _RankedGameOverDialogState();
}

class _RankedGameOverDialogState extends ConsumerState<RankedGameOverDialog> {
  @override
  void initState() {
    super.initState();
    // Game-end interstitial (free tier, cadence-gated). Post-frame so the
    // results are on screen before any full-screen ad appears on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gameEndAdControllerProvider).onGameFinished(context);
    });
  }

  /// Sorted standings with competition ranking: ties share a rank and the
  /// next rank skips (two players on 40 pts are both #1; the next is #3).
  List<(int rank, RankedPlayerResult result)> _ranked() {
    final sorted = [...widget.results]
      ..sort((a, b) => b.score.compareTo(a.score));
    final out = <(int, RankedPlayerResult)>[];
    for (var i = 0; i < sorted.length; i++) {
      final rank = (i > 0 && sorted[i].score == sorted[i - 1].score)
          ? out[i - 1].$1
          : i + 1;
      out.add((rank, sorted[i]));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked();
    final localRank = ranked
        .where((e) => e.$2.isLocal)
        .map((e) => e.$1)
        .fold<int?>(null, (a, b) => a ?? b);
    final localWon = localRank == 1;
    final podium = ranked.where((e) => e.$1 <= 3).toList();
    final rest = ranked.where((e) => e.$1 > 3).toList();

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),

        // Dialog
        Center(
          child: ModalEntryTransition(
            child: GlassContainer(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 310,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localWon
                          ? 'Victory!'
                          : (localRank != null && localRank <= 3
                              ? 'So Close!'
                              : 'Game Over'),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color:
                            localWon ? AppColors.success : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _PodiumRow(podium: podium),
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            for (final (rank, r) in rest)
                              _SulkingRow(rank: rank, result: r),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Reward chips
                    if (widget.coinsEarned > 0 ||
                        widget.xpEarned > 0 ||
                        widget.gemsEarned > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (widget.coinsEarned > 0)
                              _RewardChip(
                                icon: Icons.circle,
                                iconColor: GlassTokens.warning,
                                label: '+${widget.coinsEarned}',
                              ),
                            if (widget.gemsEarned > 0)
                              _RewardChip(
                                icon: Icons.diamond,
                                iconColor: const Color(0xFF9C27B0),
                                label: '+${widget.gemsEarned}',
                              ),
                            if (widget.xpEarned > 0)
                              _RewardChip(
                                icon: Icons.bolt,
                                iconColor: AppColors.success,
                                label: '+${widget.xpEarned} XP',
                              ),
                          ],
                        ),
                      ),

                    if (widget.rewardNote != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.rewardNote!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),

                    // Double coins prompt
                    if (widget.onDoubleCoins != null &&
                        widget.coinsEarned > 0) ...[
                      GestureDetector(
                        onTap: widget.onDoubleCoins,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: GlassTokens.warning.withOpacity(0.15),
                            border: Border.all(
                              color: GlassTokens.warning.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill,
                                  size: 18, color: GlassTokens.warning),
                              const SizedBox(width: 8),
                              Text(
                                'Double your coins!',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: GlassTokens.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.onLeave != null)
                          GlassButton(
                            label: 'Home',
                            onPressed: widget.onLeave,
                            variant: GlassButtonVariant.ghost,
                            color: AppColors.textMuted,
                          ),
                        if (widget.onPlayAgain != null)
                          GlassButton(
                            label: widget.playAgainLabel,
                            onPressed: widget.onPlayAgain,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Confetti only when the local player topped the table.
        if (localWon)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiAnimation(isPlaying: localWon),
            ),
          ),
      ],
    );
  }
}

/// Top-3 podium: 1st centred and elevated with the crown, 2nd left, 3rd
/// right. Ties can put more than three players on the podium — extras of
/// the same rank simply stand side by side.
class _PodiumRow extends StatelessWidget {
  final List<(int rank, RankedPlayerResult result)> podium;

  const _PodiumRow({required this.podium});

  static const _medals = {2: '🥈', 3: '🥉'};
  static const _lifts = {1: 22.0, 2: 10.0, 3: 0.0};

  @override
  Widget build(BuildContext context) {
    final firsts = podium.where((e) => e.$1 == 1).toList();
    final seconds = podium.where((e) => e.$1 == 2).toList();
    final thirds = podium.where((e) => e.$1 == 3).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (rank, r) in [...seconds.take(1), ...firsts, ...seconds.skip(1), ...thirds])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.translate(
                offset: Offset(0, -_lifts[rank]!),
                child: _PodiumPlayer(
                  result: r,
                  badge: rank == 1 ? '👑' : _medals[rank]!,
                  isChampion: rank == 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumPlayer extends StatelessWidget {
  final RankedPlayerResult result;
  final String badge;
  final bool isChampion;

  const _PodiumPlayer({
    required this.result,
    required this.badge,
    required this.isChampion,
  });

  @override
  Widget build(BuildContext context) {
    final size = isChampion ? 56.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(badge, style: TextStyle(fontSize: isChampion ? 26 : 18)),
        const SizedBox(height: 2),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.35),
            border: Border.all(
              color: isChampion
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.5),
              width: isChampion ? 2.5 : 1.5,
            ),
            boxShadow: isChampion
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            result.emoji,
            style: TextStyle(fontSize: isChampion ? 28 : 22),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            result.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isChampion ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
        Text(
          '${result.score}',
          style: GoogleFonts.poppins(
            fontSize: isChampion ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: isChampion ? AppColors.accent : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

/// Below-podium row: desaturated, small, with a sulking face where the
/// medal would be.
class _SulkingRow extends StatelessWidget {
  final int rank;
  final RankedPlayerResult result;

  const _SulkingRow({required this.rank, required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Text('😞', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              result.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            '${result.score}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _RewardChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: iconColor.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
