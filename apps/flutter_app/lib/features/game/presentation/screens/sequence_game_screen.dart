import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_sequence/game_sequence.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_rewards_provider.dart';
import '../../providers/game_session_providers.dart';
import '../widgets/card_hand.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/sequence_board_widget.dart';
import '../widgets/turn_timer.dart';

/// Sequence game screen with 10×10 board, card hand, and chip placement.
class SequenceGameScreen extends ConsumerStatefulWidget {
  final SequenceState state;
  final String roomId;
  final String localPlayerId;

  const SequenceGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  ConsumerState<SequenceGameScreen> createState() =>
      _SequenceGameScreenState();
}

class _SequenceGameScreenState extends ConsumerState<SequenceGameScreen> {
  bool get _isMyTurn =>
      widget.state.currentPlayerId == widget.localPlayerId;

  bool get _isSpectator =>
      !widget.state.playerIds.contains(widget.localPlayerId);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selectedCard = ref.watch(selectedCardProvider);
    final localHand = state.playerHands[widget.localPlayerId] ?? [];
    final localColor = state.playerColors[widget.localPlayerId];

    // Calculate valid placements based on selected card
    final validPlacements = <(int, int)>{};
    final removablePositions = <(int, int)>{};

    if (selectedCard != null && _isMyTurn) {
      final isOneEyedJack = selectedCard.rank == Rank.jack &&
          (selectedCard.suit == Suit.hearts ||
              selectedCard.suit == Suit.spades);
      final isTwoEyedJack = selectedCard.rank == Rank.jack &&
          (selectedCard.suit == Suit.diamonds ||
              selectedCard.suit == Suit.clubs);

      if (isOneEyedJack) {
        // One-eyed jack: remove opponent's chip
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cell = state.board.cellAt(row, col);
            if (cell.chip != null &&
                cell.chip != localColor &&
                !cell.isChipLocked) {
              removablePositions.add((row, col));
            }
          }
        }
      } else if (isTwoEyedJack) {
        // Two-eyed jack: place anywhere unoccupied
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            if (!state.board.isOccupied(row, col)) {
              validPlacements.add((row, col));
            }
          }
        }
      } else {
        // Normal card: place on matching board positions
        final positions = state.board.positionsForCard(selectedCard);
        for (final pos in positions) {
          if (!state.board.isOccupied(pos.$1, pos.$2)) {
            validPlacements.add(pos);
          }
        }
      }
    }

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Sequence',
                  socialMode: state.socialMode,
                  isSpectator: _isSpectator,
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: _isSpectator,
                  ),
                ),
                const SizedBox(height: 4),

                // Sequence count display
                GlassContainer(
                  key: const Key('score-display'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.sequenceCount.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _chipColorToFlutter(e.key),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${e.value}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Board
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: SequenceBoardWidget(
                          board: state.board,
                          validPlacements: validPlacements,
                          removablePositions: removablePositions,
                          onCellTap: _isMyTurn && !_isSpectator
                              ? _onCellTap
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Turn timer
                if (_isMyTurn && !state.isGameOver)
                  const TurnTimer(seconds: 30),

                // Emoji bar
                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: widget.roomId,
                ),
                const SizedBox(height: 4),

                // Player hand
                if (!_isSpectator)
                  Container(
                    key: const Key('player-hand'),
                    child: CardHand(
                      cards: localHand,
                      isPlayable: _isMyTurn,
                      mode: CardHandMode.tapToSelect,
                      onCardTap: (_) {},
                    ),
                  ),

                // Actions
              ],
            ),
          ),
        ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: state.winnerId == widget.localPlayerId,
            winnerName: state.winnerId,
            coinsEarned: ref
                    .watch(gameRewardReceiptProvider(widget.roomId))
                    .valueOrNull
                    ?.coins ??
                0,
            xpEarned: ref
                    .watch(gameRewardReceiptProvider(widget.roomId))
                    .valueOrNull
                    ?.xp ??
                0,
            gemsEarned: ref
                    .watch(gameRewardReceiptProvider(widget.roomId))
                    .valueOrNull
                    ?.gems ??
                0,
            rewardNote: rewardNoteFor(ref
                .watch(gameRewardReceiptProvider(widget.roomId))
                .valueOrNull),
            onDoubleCoins: () {
              RewardedAdModal.show(context: context);
            },
            onPlayAgain: () {},
            onLeave: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  void _onCellTap((int, int) position) {
    final selectedCard = ref.read(selectedCardProvider);
    if (selectedCard == null) return;

    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'place',
        'player_id': widget.localPlayerId,
        'card': selectedCard.toJson(),
        'row': position.$1,
        'col': position.$2,
      },
    );
    ref.read(selectedCardProvider.notifier).state = null;
  }

  Color _chipColorToFlutter(ChipColor color) {
    switch (color) {
      case ChipColor.red:
        return AppColors.player1;
      case ChipColor.blue:
        return AppColors.player2;
      case ChipColor.green:
        return AppColors.player3;
    }
  }
}
