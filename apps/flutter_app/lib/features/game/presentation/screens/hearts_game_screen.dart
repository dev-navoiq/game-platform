import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_hearts/game_hearts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../widgets/card_hand.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/player_node.dart';
import '../widgets/score_display.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/turn_timer.dart';

/// Hearts game screen with card passing phase and hearts broken indicator.
class HeartsGameScreen extends ConsumerWidget {
  final HeartsState state;
  final String roomId;
  final String localPlayerId;

  const HeartsGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMyTurn = state.currentPlayerId == localPlayerId;
    final isSpectator = !state.playerOrder.contains(localPlayerId);
    final localIndex =
        state.playerOrder.indexOf(localPlayerId).clamp(0, state.playerOrder.length - 1);
    final seats = SeatLayout.calculate(
      playerCount: state.playerOrder.length,
      localPlayerIndex: localIndex,
    );

    final localHand = state.hands[localPlayerId];
    final cards = localHand?.cards ?? [];
    final isPassing = state.phase == GamePhase.bidding; // Passing phase uses bidding phase
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Hearts',
                  roundNumber: state.roundNumber,
                  socialMode: state.socialMode,
                  isSpectator: isSpectator,
                ),
                const SizedBox(height: 4),

                // Score display
                ScoreDisplay(
                  scores: state.scores,
                  localPlayerId: localPlayerId,
                ),
                const SizedBox(height: 4),

                // Hearts broken indicator
                if (state.heartsBroken)
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('♥', style: TextStyle(fontSize: 12, color: AppColors.cardRed)),
                        const SizedBox(width: 4),
                        Text(
                          'Hearts Broken',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cardRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main game area
                Expanded(
                  child: Stack(
                    children: [
                      // Player nodes
                      ...seats.where((s) => !s.isBottom).map((seat) {
                        final playerId = state.playerOrder[seat.seatIndex];
                        final isPlayerActive =
                            state.currentPlayerId == playerId;
                        final hasPlayed = state.currentTrick
                            .any((tc) => tc.playerId == playerId);
                        final handPoints = state.handPoints[playerId] ?? 0;

                        final displayName = PlayerAvatar.nameFor(
                          playerId: playerId,
                          localPlayerId: localPlayerId,
                          seatIndex: seat.seatIndex,
                        );
                        return Align(
                          alignment: seat.alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: PlayerNode(
                              name: displayName,
                              emoji: playerEmojis[playerId] ?? '🎮',
                              won: handPoints,
                              bid: 0,
                              isActive: isPlayerActive,
                              hasPlayed: hasPlayed,
                              isSmall: seat.isSmall,
                              socialMode: state.socialMode,
                              showBidPill: false,
                              roomId: roomId,
                              playerId: playerId,
                            ),
                          ),
                        );
                      }),

                      // Trick zone
                      Center(
                        child: TrickZone(
                          currentTrick: state.currentTrick,
                          playerOrder: state.playerOrder,
                          playerEmojis: playerEmojis,
                        ),
                      ),

                      // Passing phase indicator
                      if (isPassing)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: Text(
                                'Pass 3 cards ${_passDirectionLabel(state.passDirection)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Turn timer
                      if (isMyTurn && state.phase == GamePhase.playing)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: TurnTimer(seconds: 30),
                        ),
                    ],
                  ),
                ),

                // Emoji bar
                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: roomId,
                ),
                const SizedBox(height: 4),

                // Player hand
                if (!isSpectator)
                  CardHand(
                    cards: cards,
                    isPlayable: isMyTurn && state.phase == GamePhase.playing,
                    onCardTap: (card) => _playCard(ref, card),
                  ),

                // Actions
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GameActions(
                    isSpectator: isSpectator,
                    onLeave: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: _isLocalWinner(),
            winnerName: _winnerName(),
            finalScores: state.scores,
            coinsEarned: _isLocalWinner() ? 50 : 10,
            xpEarned: _isLocalWinner() ? 30 : 10,
            onDoubleCoins: () {
              RewardedAdModal.show(context: context);
            },
            onPlayAgain: () {},
            onLeave: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  void _playCard(WidgetRef ref, PlayingCard card) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: {
        'type': 'playCard',
        'player_id': localPlayerId,
        'card': card.toJson(),
      },
    );
  }

  bool _isLocalWinner() {
    if (state.scores.isEmpty) return false;
    // In Hearts, lowest score wins
    final minScore = state.scores.values.reduce((a, b) => a < b ? a : b);
    return state.scores[localPlayerId] == minScore;
  }

  String? _winnerName() {
    if (state.scores.isEmpty) return null;
    final minScore = state.scores.values.reduce((a, b) => a < b ? a : b);
    return state.scores.entries
        .firstWhere((e) => e.value == minScore)
        .key;
  }

  String _passDirectionLabel(PassDirection dir) {
    switch (dir) {
      case PassDirection.left:
        return '← Left';
      case PassDirection.right:
        return 'Right →';
      case PassDirection.across:
        return '↕ Across';
      case PassDirection.keep:
        return '(No Pass)';
    }
  }
}
