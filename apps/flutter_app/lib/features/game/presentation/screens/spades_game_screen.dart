import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_spades/game_spades.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_rewards_provider.dart';
import '../widgets/bidding_modal.dart';
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

/// Spades game screen with nil bids, bags tracking, and team scoring.
class SpadesGameScreen extends ConsumerWidget {
  final SpadesState state;
  final String roomId;
  final String localPlayerId;

  const SpadesGameScreen({
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
    final localTeam = state.teamForPlayer(localPlayerId);
    final seats = SeatLayout.calculate(
      playerCount: state.playerOrder.length,
      localPlayerIndex: localIndex,
    );

    final localHand = state.hands[localPlayerId];
    final cards = localHand?.cards ?? [];
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Spades',
                  roundNumber: state.roundNumber,
                  trumpInfo: '♠',
                  socialMode: state.socialMode,
                  isSpectator: isSpectator,
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: isSpectator,
                  ),
                ),
                const SizedBox(height: 4),

                // Team score + bags
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TeamScoreDisplay(
                      team0Score: state.teamScores[0] ?? 0,
                      team1Score: state.teamScores[1] ?? 0,
                      localTeam: localTeam,
                    ),
                    const SizedBox(width: 8),
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Bags: ${state.teamBags[localTeam] ?? 0}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Spades broken indicator
                if (state.spadesBroken)
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('♠', style: TextStyle(fontSize: 12, color: AppColors.textDark)),
                        const SizedBox(width: 4),
                        Text(
                          'Spades Broken',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main game area
                Expanded(
                  child: Stack(
                    children: [
                      // Player nodes with bid pills
                      ...seats.where((s) => !s.isBottom).map((seat) {
                        final playerId = state.playerOrder[seat.seatIndex];
                        final isPlayerActive =
                            state.currentPlayerId == playerId;
                        final hasPlayed = state.currentTrick
                            .any((tc) => tc.playerId == playerId);
                        final bid = state.bids[playerId] ?? 0;
                        final won = state.playerTricksWon[playerId] ?? 0;
                        final isDealer =
                            seat.seatIndex == state.dealerIndex;
                        final isNil = state.isNilBid[playerId] ?? false;
                        final displayName = PlayerAvatar.nameFor(
                          playerId: playerId,
                          localPlayerId: localPlayerId,
                          seatIndex: seat.seatIndex,
                        );

                        return Align(
                          alignment: seat.alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerNode(
                                  name: displayName,
                                  emoji: playerEmojis[playerId] ?? '🎮',
                                  won: won,
                                  bid: bid,
                                  isActive: isPlayerActive,
                                  hasPlayed: hasPlayed,
                                  isDealer: isDealer,
                                  isSmall: seat.isSmall,
                                  socialMode: state.socialMode,
                                  showBidPill: state.bids.containsKey(playerId),
                                  roomId: roomId,
                                  playerId: playerId,
                                ),
                                if (isNil)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'NIL',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
                          trumpSuit: Suit.spades,
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
              ],
            ),
          ),
        ),

        // Bidding modal
        if (state.phase == GamePhase.bidding && isMyTurn && !isSpectator)
          BiddingModal(
            minBid: 0,
            maxBid: 13,
            onBidSelected: (bid) => _placeBid(ref, bid),
          ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: _isLocalWinner(),
            finalScores: {
              'Team 1': state.teamScores[0] ?? 0,
              'Team 2': state.teamScores[1] ?? 0,
            },
            coinsEarned: ref
                    .watch(gameRewardReceiptProvider(roomId))
                    .valueOrNull
                    ?.coins ??
                0,
            xpEarned: ref
                    .watch(gameRewardReceiptProvider(roomId))
                    .valueOrNull
                    ?.xp ??
                0,
            rewardNote: rewardNoteFor(ref
                .watch(gameRewardReceiptProvider(roomId))
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

  void _placeBid(WidgetRef ref, int bid) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: BidMoveDto(
        playerId: localPlayerId,
        bidValue: bid,
      ).toJson(),
    );
  }

  bool _isLocalWinner() {
    final localTeam = state.teamForPlayer(localPlayerId);
    final team0 = state.teamScores[0] ?? 0;
    final team1 = state.teamScores[1] ?? 0;
    return localTeam == 0 ? team0 >= 500 : team1 >= 500;
  }
}
