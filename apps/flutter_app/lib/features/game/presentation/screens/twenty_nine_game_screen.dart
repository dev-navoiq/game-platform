import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

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
import '../widgets/round_end_overlay.dart';
import '../widgets/trump_indicator.dart';
import '../widgets/trump_reveal_overlay.dart';
import '../widgets/turn_timer.dart';

/// Twenty-Nine game screen with team-based scoring.
///
/// Bidding range 15–28 with pass support. The bid winner secretly
/// selects the trump suit. Must render `Key('bid-16')` for tests.
class TwentyNineGameScreen extends ConsumerStatefulWidget {
  final TwentyNineState state;
  final String roomId;
  final String localPlayerId;

  const TwentyNineGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  ConsumerState<TwentyNineGameScreen> createState() =>
      _TwentyNineGameScreenState();
}

class _TwentyNineGameScreenState extends ConsumerState<TwentyNineGameScreen> {
  bool _showTrumpReveal = false;

  @override
  void didUpdateWidget(covariant TwentyNineGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Show trump reveal when trump just got revealed
    if (widget.state.trumpRevealed &&
        !oldWidget.state.trumpRevealed &&
        widget.state.trumpSuit != null) {
      setState(() => _showTrumpReveal = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isMyTurn = state.currentPlayerId == widget.localPlayerId;
    final isSpectator = !state.playerOrder.contains(widget.localPlayerId);
    print('[29Screen] phase=${state.phase} isMyTurn=$isMyTurn bid=${state.currentBid} minBid=${state.minimumBid}');
    final localIndex =
        state.playerOrder.indexOf(widget.localPlayerId).clamp(0, state.playerOrder.length - 1);
    final localTeam = state.teamForPlayer(widget.localPlayerId);
    final seats = SeatLayout.calculate(
      playerCount: state.playerOrder.length,
      localPlayerIndex: localIndex,
    );

    final localHand = state.hands[widget.localPlayerId];
    final cards = localHand?.cards ?? [];
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Positioned.fill(child: GameTable(child: const SizedBox.shrink())),

        // Game layout
        Positioned.fill(
          child: SafeArea(
            child: Column(
              children: [
                // HUD — trump is shown on its own pill below, not here.
                GameHud(
                  gameName: 'Twenty-Nine',
                  roundNumber: state.roundNumber,
                  socialMode: state.socialMode,
                  isSpectator: isSpectator,
                ),
                const SizedBox(height: 4),

                // Bid + trump + score summary bar
                if (state.currentBid > 0 || state.phase == GamePhase.playing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.currentBid > 0) ...[
                                const Text('Bid ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                Text(
                                  '${state.currentBid}${state.doublingMultiplier > 1 ? (state.doublingMultiplier == 4 ? ' XX' : ' X') : ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 10),
                              ],
                              // Card points (what matters for bid)
                              const Text('Pts ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                '${state.teamPoints[localTeam] ?? 0}',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const Text('-', style: TextStyle(color: Colors.white38, fontSize: 13)),
                              Text(
                                '${state.teamPoints[localTeam == 0 ? 1 : 0] ?? 0}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 10),
                              // Tricks won
                              const Text('Tricks ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                '${state.tricksWon[localTeam] ?? 0}-${state.tricksWon[localTeam == 0 ? 1 : 0] ?? 0}',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TrumpIndicator(
                          trumpSuit: state.trumpSuit,
                          trumpRevealed: state.trumpRevealed,
                          doublingMultiplier: state.doublingMultiplier,
                          canReveal: _canRevealTrump(state, isMyTurn),
                          onReveal: () => _revealTrump(),
                        ),
                      ],
                    ),
                  ),

                // Team score display
                TeamScoreDisplay(
                  team0Score: state.sessionScores[0] ?? 0,
                  team1Score: state.sessionScores[1] ?? 0,
                  localTeam: localTeam,
                ),
                const SizedBox(height: 4),

                // Main game area — takes all remaining vertical space
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
                        final isDealer =
                            seat.seatIndex == state.dealerIndex;

                        final displayName = PlayerAvatar.nameFor(
                          playerId: playerId,
                          localPlayerId: widget.localPlayerId,
                          seatIndex: seat.seatIndex,
                        );
                        return Align(
                          alignment: seat.alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: PlayerNode(
                              name: displayName,
                              emoji: playerEmojis[playerId] ?? '🎮',
                              won: 0,
                              bid: 0,
                              isActive: isPlayerActive,
                              hasPlayed: hasPlayed,
                              isDealer: isDealer,
                              isSmall: seat.isSmall,
                              socialMode: state.socialMode,
                              showBidPill: false,
                              roomId: widget.roomId,
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
                          trumpSuit: state.trumpRevealed ? state.trumpSuit : null,
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
                  roomId: widget.roomId,
                ),
                const SizedBox(height: 4),

                // Player hand
                if (!isSpectator)
                  SizedBox(
                    height: 130,
                    child: CardHand(
                      cards: cards,
                      isPlayable: isMyTurn && state.phase == GamePhase.playing,
                      onCardTap: (card) => _playCard(card),
                    ),
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

        // Bidding modal
        if (state.phase == GamePhase.bidding && isMyTurn && !isSpectator)
          Builder(builder: (_) {
            final canDouble = state.bidderId != null &&
                state.doublingMultiplier == 1 &&
                state.teamForPlayer(widget.localPlayerId) !=
                    state.teamForPlayer(state.bidderId!);
            final canRedouble = state.bidderId != null &&
                state.doublingMultiplier == 2 &&
                state.redoubledBy == null &&
                state.teamForPlayer(widget.localPlayerId) ==
                    state.teamForPlayer(state.bidderId!);
            return BiddingModal(
              minBid: state.minimumBid,
              maxBid: 28,
              showPassButton: state.currentBid > 0,
              showDoubleButton: canDouble,
              showRedoubleButton: canRedouble,
              bidGridEnabled: state.doublingMultiplier == 1,
              onBidSelected: (bid) => _placeBid(bid),
              onPass: () => _pass(),
              onDouble: () => _double(),
              onRedouble: () => _redouble(),
            );
          }),

        // Trump selection modal
        if (state.phase == GamePhase.trumpSelection && isMyTurn && !isSpectator)
          _buildTrumpSelectionModal(state),

        // Trump reveal overlay
        if (_showTrumpReveal && state.trumpSuit != null)
          TrumpRevealOverlay(
            trumpSuit: state.trumpSuit!,
            onComplete: () => setState(() => _showTrumpReveal = false),
          ),

        // Round end overlay
        if (state.phase == GamePhase.roundEnd)
          RoundEndOverlay(
            winningTeam: _roundWinningTeam(state),
            localTeam: localTeam,
            bid: state.currentBid,
            biddingTeam: state.bidWinnerTeam ?? 0,
            teamPoints: state.teamPoints,
            bidMet: (state.teamPoints[state.bidWinnerTeam ?? 0] ?? 0) >=
                (state.currentBid == 29 ? 28 : state.currentBid),
            sessionScores: state.sessionScores,
            roundNumber: state.roundNumber - 1, // roundNumber already incremented
            onContinue: () => _startNextRound(),
          ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: _isLocalWinner(),
            finalScores: {
              'Team 1': state.sessionScores[0] ?? 0,
              'Team 2': state.sessionScores[1] ?? 0,
            },
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

  Widget _buildTrumpSelectionModal(TwentyNineState state) {
    final hand = state.hands[widget.localPlayerId];
    final availableSuits = <Suit>{};
    if (hand != null) {
      for (final card in hand.cards) {
        availableSuits.add(card.suit);
      }
    }

    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Trump Suit',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a suit you hold cards in',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: Suit.values.map((suit) {
                final isAvailable = availableSuits.contains(suit);
                final symbol = _suitSymbol(suit);
                final color = (suit == Suit.hearts || suit == Suit.diamonds)
                    ? Colors.red
                    : Colors.black87;
                return GestureDetector(
                  key: Key('trump-${suit.name}'),
                  onTap: isAvailable ? () => _declareTrump(suit) : null,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.white
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAvailable
                            ? color.withOpacity(0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        symbol,
                        style: TextStyle(
                          fontSize: 28,
                          color: isAvailable ? color : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _declareTrump(Suit suit) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'declareTrump',
        'player_id': widget.localPlayerId,
        'suit': suit.name,
      },
    );
  }

  void _playCard(PlayingCard card) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'playCard',
        'player_id': widget.localPlayerId,
        'card': card.toJson(),
      },
    );
  }

  void _placeBid(int bid) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: BidMoveDto(
        playerId: widget.localPlayerId,
        bidValue: bid,
      ).toJson(),
    );
  }

  void _pass() {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'pass',
        'player_id': widget.localPlayerId,
      },
    );
  }

  void _double() {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'double',
        'player_id': widget.localPlayerId,
      },
    );
  }

  void _redouble() {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'redouble',
        'player_id': widget.localPlayerId,
      },
    );
  }

  void _revealTrump() {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'revealTrump',
        'player_id': widget.localPlayerId,
      },
    );
  }

  /// The local player is allowed to reveal the hidden trump when it is their
  /// turn to play, they have no card of the lead suit in hand, and trump is
  /// still closed.
  bool _canRevealTrump(TwentyNineState state, bool isMyTurn) {
    if (state.phase != GamePhase.playing) return false;
    if (state.trumpSuit == null || state.trumpRevealed) return false;
    if (!isMyTurn) return false;
    if (state.currentTrick.isEmpty) return false;
    final hand = state.hands[widget.localPlayerId];
    if (hand == null) return false;
    final leadSuit = state.currentTrick.first.suit;
    return !hand.hasSuit(leadSuit);
  }

  bool _isLocalWinner() {
    final localTeam = widget.state.teamForPlayer(widget.localPlayerId);
    final team0 = widget.state.sessionScores[0] ?? 0;
    final team1 = widget.state.sessionScores[1] ?? 0;
    return localTeam == 0 ? team0 > team1 : team1 > team0;
  }

  /// Determine which team won the current round based on bid result.
  int _roundWinningTeam(TwentyNineState state) {
    final biddingTeam = state.bidWinnerTeam ?? 0;
    final bidTeamPts = state.teamPoints[biddingTeam] ?? 0;
    final threshold = state.currentBid == 29 ? 28 : state.currentBid;
    final bidMet = bidTeamPts >= threshold;
    return bidMet ? biddingTeam : (biddingTeam == 0 ? 1 : 0);
  }

  void _startNextRound() {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'newRound',
        'player_id': widget.localPlayerId,
      },
    );
  }

  String _suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }
}
