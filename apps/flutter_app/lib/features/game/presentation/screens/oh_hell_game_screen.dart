import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

import '../../../../core/utils/player_avatar.dart';
import '../../providers/game_provider.dart';
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

/// Oh Hell game screen — reference implementation for card game screens.
///
/// Stack layout: GameTable → PlayerNodes → TrickZone → CardHand → overlays.
class OhHellGameScreen extends ConsumerWidget {
  final OhHellState state;
  final String roomId;
  final String localPlayerId;

  const OhHellGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMyTurn = state.currentPlayerId == localPlayerId;
    final isSpectator = !state.playerOrder.contains(localPlayerId);
    final localIndex = state.playerOrder.indexOf(localPlayerId).clamp(0, state.playerOrder.length - 1);
    final seats = SeatLayout.calculate(
      playerCount: state.playerOrder.length,
      localPlayerIndex: localIndex,
    );

    final localHand = state.hands[localPlayerId];
    final cards = localHand?.cards ?? [];
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);

    return Stack(
      children: [
        // Game table background
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Oh Hell',
                  roundNumber: state.roundNumber,
                  totalRounds: state.totalRounds,
                  trumpInfo: '♥',
                  cardsDealt: state.cardsThisRound,
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

                // Main game area with players and trick
                Expanded(
                  child: Stack(
                    children: [
                      // Player nodes
                      ...seats.where((s) => !s.isBottom).map((seat) {
                        final playerId = state.playerOrder[seat.seatIndex];
                        final bid = state.bids[playerId] ?? 0;
                        final won = state.tricksWon[playerId] ?? 0;
                        final isDealer =
                            seat.seatIndex == state.dealerIndex;
                        final isPlayerActive =
                            state.currentPlayerId == playerId;
                        final hasPlayed = state.currentTrick
                            .any((tc) => tc.playerId == playerId);

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
                          ),
                        );
                      }),

                      // Trick zone (center)
                      Center(
                        child: TrickZone(
                          currentTrick: state.currentTrick,
                          playerOrder: state.playerOrder,
                          playerEmojis: playerEmojis,
                          trumpSuit: Suit.hearts,
                        ),
                      ),

                      // Turn timer
                      if (isMyTurn && state.phase == GamePhase.playing)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: TurnTimer(seconds: 30),
                        ),

                      // Bidding panel (inside game area so cards remain visible below)
                      if (state.phase == GamePhase.bidding && isMyTurn && !isSpectator)
                        BiddingModal(
                          minBid: 0,
                          maxBid: state.cardsThisRound,
                          forbiddenBid: state.isDealerBidding
                              ? state.forbiddenBidForDealer
                              : null,
                          onBidSelected: (bid) => _placeBid(ref, bid),
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

        // Game over dialog
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

  void _placeBid(WidgetRef ref, int bid) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: {
        'type': 'bid',
        'player_id': localPlayerId,
        'bid_value': bid,
      },
    );
  }

  bool _isLocalWinner() {
    if (state.scores.isEmpty) return false;
    final maxScore = state.scores.values.reduce((a, b) => a > b ? a : b);
    return state.scores[localPlayerId] == maxScore;
  }

  String? _winnerName() {
    if (state.scores.isEmpty) return null;
    final maxScore = state.scores.values.reduce((a, b) => a > b ? a : b);
    return state.scores.entries
        .firstWhere((e) => e.value == maxScore)
        .key;
  }
}
