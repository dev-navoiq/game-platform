import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/animations/gameplay/ohell_bust_animation.dart';
import '../../providers/game_provider.dart';
import '../widgets/bid_pill.dart';
import '../widgets/bidding_modal.dart';
import '../widgets/card_hand.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/oh_hell_round_end_overlay.dart';
import '../widgets/game_table.dart';
import '../widgets/player_node.dart';
import '../widgets/score_display.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/turn_timer.dart';

/// Oh Hell game screen — reference implementation for card game screens.
///
/// Stack layout: GameTable → PlayerNodes → TrickZone → CardHand → overlays.
class OhHellGameScreen extends ConsumerStatefulWidget {
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
  ConsumerState<OhHellGameScreen> createState() => _OhHellGameScreenState();
}

class _OhHellGameScreenState extends ConsumerState<OhHellGameScreen> {
  /// Players who have already had their bust animation played this round.
  /// Reset whenever a new round begins (detected by roundNumber change).
  final Set<String> _bustedAnimated = {};
  int? _lastRoundNumber;

  /// Currently active bust: playerId of the seat the flames spew from.
  /// Cleared when the animation completes.
  String? _activeBustPlayerId;
  Alignment? _activeBustAlignment;

  /// Round number for which the deal animation has finished. The bidding
  /// modal stays hidden until this catches up to the current round so the
  /// cards have time to fan in first.
  int? _dealAnimatedRound;
  Timer? _dealTimer;

  /// Approximate time the [CardFanAnimation] needs to stagger N cards into
  /// view: 60ms per card + 300ms tail for the last card to settle.
  Duration _dealAnimationDuration(int cardCount) =>
      Duration(milliseconds: 60 * cardCount + 350);

  void _scheduleDealReveal(int round, int cardCount) {
    if (_dealAnimatedRound == round) return;
    _dealTimer?.cancel();
    _dealTimer = Timer(_dealAnimationDuration(cardCount), () {
      if (!mounted) return;
      setState(() => _dealAnimatedRound = round);
    });
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    super.dispose();
  }

  void _checkForBust(OhHellState state) {
    // Reset per-round memory on new round.
    if (_lastRoundNumber != state.roundNumber) {
      _lastRoundNumber = state.roundNumber;
      _bustedAnimated.clear();
    }

    if (state.phase != GamePhase.playing) return;
    if (_activeBustPlayerId != null) return;

    for (final pid in state.playerOrder) {
      if (_bustedAnimated.contains(pid)) continue;
      final bid = state.bids[pid];
      final won = state.tricksWon[pid] ?? 0;
      if (bid == null) continue;
      if (won > bid) {
        // Compute seat alignment for this player relative to local seat.
        final localIndex = state.playerOrder
            .indexOf(widget.localPlayerId)
            .clamp(0, state.playerOrder.length - 1);
        final seats = SeatLayout.calculate(
          playerCount: state.playerOrder.length,
          localPlayerIndex: localIndex,
        );
        final seat = seats.firstWhere(
          (s) => state.playerOrder[s.seatIndex] == pid,
          orElse: () => seats.first,
        );
        _bustedAnimated.add(pid);
        // Schedule for after the current build to avoid setState-in-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _activeBustPlayerId = pid;
            _activeBustAlignment = seat.alignment;
          });
        });
        break;
      }
    }
  }

  Offset _alignmentToOffset(Alignment alignment, Size size) {
    return Offset(
      size.width / 2 + alignment.x * size.width / 2,
      size.height / 2 + alignment.y * size.height / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final roomId = widget.roomId;
    final localPlayerId = widget.localPlayerId;

    _checkForBust(state);
    _scheduleDealReveal(state.roundNumber, state.cardsThisRound);
    final bidModalReady = _dealAnimatedRound == state.roundNumber;

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
                  child: LayoutBuilder(builder: (context, constraints) {
                    final stackSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
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
                              showBidPill: true,
                              hasBid: state.bids.containsKey(playerId),
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

                      // Bidding panel — anchored to the top of the game
                      // area so the trick zone and the player's hand below
                      // remain fully visible while choosing a bid. Held back
                      // until the deal animation finishes so the player can
                      // see all their cards before having to choose.
                      if (state.phase == GamePhase.bidding && isMyTurn && !isSpectator && bidModalReady)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: BiddingModal(
                              minBid: 0,
                              maxBid: state.cardsThisRound,
                              forbiddenBid: state.isDealerBidding
                                  ? state.forbiddenBidForDealer
                                  : null,
                              onBidSelected: (bid) => _placeBid(ref, bid),
                            ),
                          ),
                        ),

                      // OHELL bust animation overlay — full-bleed; emits
                      // flames from the busted player's seat.
                      if (_activeBustPlayerId != null && _activeBustAlignment != null)
                        Positioned.fill(
                          child: OhellBustAnimation(
                            isPlaying: true,
                            emissionCenter: _alignmentToOffset(
                              _activeBustAlignment!,
                              stackSize,
                            ),
                            onComplete: () {
                              if (!mounted) return;
                              setState(() {
                                _activeBustPlayerId = null;
                                _activeBustAlignment = null;
                              });
                            },
                          ),
                        ),
                    ],
                  );
                  }),
                ),

                // Emoji bar
                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: roomId,
                ),
                const SizedBox(height: 4),

                // Local player bid pill — same widget as the seat pills so
                // the player always knows what they bid and how they're
                // tracking against it.
                if (!isSpectator)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: BidPill(
                      won: state.tricksWon[localPlayerId] ?? 0,
                      bid: state.bids[localPlayerId] ?? 0,
                      hasBid: state.bids.containsKey(localPlayerId),
                    ),
                  ),

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

        // Round-end / game-end scoreboard. Single overlay for both states
        // — the difference is only the button label and whether we cycle
        // through the next round or restart the session.
        if (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd)
          OhHellRoundEndOverlay(
            roundNumber: state.roundNumber - 1,
            cardsThisRound: state.roundHistory.isNotEmpty
                ? state.cardsThisRound
                : state.cardsThisRound,
            playerOrder: state.playerOrder,
            localPlayerId: localPlayerId,
            bids: state.bids,
            tricksWon: state.tricksWon,
            roundPoints: state.roundHistory.isNotEmpty
                ? state.roundHistory.last
                : const {},
            scores: state.scores,
            roundHistory: state.roundHistory,
            isGameOver: state.phase == GamePhase.gameEnd,
            onContinue: () => _startNextRound(ref),
          ),
      ],
    );
  }

  void _startNextRound(WidgetRef ref) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'newRound',
        'player_id': widget.localPlayerId,
      },
    );
  }

  void _playCard(WidgetRef ref, PlayingCard card) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'playCard',
        'player_id': widget.localPlayerId,
        'card': card.toJson(),
      },
    );
  }

  void _placeBid(WidgetRef ref, int bid) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'bid',
        'player_id': widget.localPlayerId,
        'bid_value': bid,
      },
    );
  }

}
