import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/utils/player_avatar.dart';
import '../../providers/bot_move_controller.dart';
import '../../providers/game_provider.dart';
import '../widgets/bridge_auction_strip.dart';
import '../widgets/bridge_bidding_box.dart';
import '../widgets/bridge_contract_banner.dart';
import '../widgets/bridge_dummy_hand.dart';
import '../widgets/bridge_round_end_overlay.dart';
import '../widgets/bridge_vulnerability_indicator.dart';
import '../widgets/card_hand.dart';
import '../widgets/card_sort.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_table.dart';
import '../widgets/player_node.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/turn_timer.dart';

/// Stable global key pointing at the trick zone — used by CardHand to
/// animate a played card flying from the hand toward where the trick
/// will land. Only one Bridge screen mounts at a time, so a top-level
/// static key is safe.
final GlobalKey _bridgeTrickZoneKey = GlobalKey();

/// Contract Bridge screen — bidding box + auction strip + dummy hand +
/// trick zone + round-end overlay. Stack layout mirrors oh_hell_game_screen.
class BridgeGameScreen extends ConsumerWidget {
  final BridgeState state;
  final String roomId;
  final String localPlayerId;

  const BridgeGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  // The local player acts when it's their seat OR when it's dummy's turn
  // and they are declarer (declarer plays dummy's cards).
  bool get _localCanAct {
    if (state.currentPlayerId == localPlayerId) return true;
    if (state.phase == GamePhase.playing &&
        state.currentPlayerId == state.dummyId &&
        state.contract?.declarerId == localPlayerId) {
      return true;
    }
    return false;
  }

  bool get _isLocalDummyTurn =>
      state.phase == GamePhase.playing &&
      state.currentPlayerId == state.dummyId &&
      state.contract?.declarerId == localPlayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpectator = !state.playerOrder.contains(localPlayerId);
    final localIndex = isSpectator
        ? 0
        : state.playerOrder
            .indexOf(localPlayerId)
            .clamp(0, state.playerOrder.length - 1);
    final seats = SeatLayout.calculate(
      playerCount: state.playerOrder.length,
      localPlayerIndex: localIndex,
    );

    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);
    final localHand = state.hands[localPlayerId];
    final localCards = localHand?.cards ?? const <PlayingCard>[];

    final trumpSuit = state.contract?.denomination.suit;
    final declarerTricks =
        state.contract == null ? 0 : state.tricksWon[state.contract!.declarerTeam] ?? 0;

    final showBiddingBox =
        state.phase == GamePhase.bidding && !isSpectator && _localCanAct;
    final showRoundEnd = state.phase == GamePhase.roundEnd ||
        state.phase == GamePhase.gameEnd;
    final lastDeal =
        state.dealHistory.isNotEmpty ? state.dealHistory.last : null;

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                GameHud(
                  gameName: 'Bridge',
                  roundNumber: state.dealNumber,
                  totalRounds: state.totalDeals,
                  trumpInfo: state.contract == null
                      ? null
                      : _denomGlyph(state.contract!.denomination),
                  socialMode: state.socialMode,
                  isSpectator: isSpectator,
                ),
                _DebugStrip(state: state, localPlayerId: localPlayerId),
                const SizedBox(height: 4),

                if (state.contract != null &&
                    state.phase == GamePhase.playing)
                  BridgeContractBanner(
                    contract: state.contract!,
                    vulnerability: state.vulnerability,
                    declarerTricks: declarerTricks,
                  ),
                const SizedBox(height: 4),

                Expanded(
                  child: Stack(
                    children: [
                      // Player nodes (everyone except local at bottom)
                      ...seats.where((s) => !s.isBottom).map((seat) {
                        final playerId = state.playerOrder[seat.seatIndex];
                        final isDealer = seat.seatIndex == state.dealerIndex;
                        final isActive = state.currentPlayerId == playerId;
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
                              won: 0,
                              bid: 0,
                              isActive: isActive,
                              hasPlayed: hasPlayed,
                              isDealer: isDealer,
                              isSmall: seat.isSmall,
                              socialMode: state.socialMode,
                              showBidPill: false,
                              roomId: roomId,
                              playerId: playerId,
                            ),
                          ),
                        );
                      }),

                      // Vulnerability indicator (subtle border glow)
                      BridgeVulnerabilityIndicator(
                        vulnerability: state.vulnerability,
                      ),

                      // Trick zone (center). Keyed so CardHand can fly
                      // played cards toward it.
                      Center(
                        child: KeyedSubtree(
                          key: _bridgeTrickZoneKey,
                          child: TrickZone(
                            currentTrick: state.currentTrick,
                            playerOrder: state.playerOrder,
                            playerEmojis: playerEmojis,
                            trumpSuit: trumpSuit,
                          ),
                        ),
                      ),

                      // Auction strip (top-left during bidding only)
                      if (state.phase == GamePhase.bidding)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: BridgeAuctionStrip(
                            auctionHistory: state.auctionHistory,
                            dealerIndex: state.dealerIndex,
                          ),
                        ),

                      // Dummy hand (above trick zone, once revealed)
                      if (state.phase == GamePhase.playing &&
                          state.dummyRevealed &&
                          state.dummyId != null &&
                          state.hands[state.dummyId] != null)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: BridgeDummyHand(
                            hand: state.hands[state.dummyId!]!,
                            tappable: _isLocalDummyTurn,
                            validCards: _isLocalDummyTurn
                                ? _legalCardsFor(state.dummyId!)
                                : null,
                            onCardTap: _isLocalDummyTurn
                                ? (card) => _playCard(ref, card)
                                : null,
                          ),
                        ),

                      // Turn timer
                      if (_localCanAct &&
                          state.phase == GamePhase.playing)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: TurnTimer(seconds: 30),
                        ),

                      // Bidding box overlay — anchored to bottom so the
                      // player's hand at the screen bottom stays visible
                      // while they pick a bid.
                      if (showBiddingBox)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: BridgeBiddingBox(
                            seatIndex:
                                state.playerOrder.indexOf(localPlayerId),
                            auctionHistory: state.auctionHistory,
                            onBid: (level, denom) =>
                                _sendBid(ref, level, denom),
                            onPass: () => _sendCall(ref, 'pass'),
                            onDouble: () => _sendCall(ref, 'double'),
                            onRedouble: () => _sendCall(ref, 'redouble'),
                          ),
                        ),
                    ],
                  ),
                ),

                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: roomId,
                ),
                const SizedBox(height: 4),

                if (!isSpectator)
                  TurnIndicator(
                    isYourTurn: _localCanAct &&
                        state.phase == GamePhase.playing,
                    child: CardHand(
                      cards: localCards,
                      isPlayable: _localCanAct &&
                          state.phase == GamePhase.playing,
                      // Only enforce must-follow-suit when it's actually
                      // our turn; before that we let the user queue any
                      // card and re-validate on auto-dispatch.
                      validCards: _localCanAct &&
                              state.phase == GamePhase.playing
                          ? _legalCardsFor(
                              _isLocalDummyTurn
                                  ? state.dummyId!
                                  : localPlayerId)
                          : null,
                      sorter: bridgeCardSort,
                      flightTargetKey: _bridgeTrickZoneKey,
                      onCardTap: (card) => _playCard(ref, card),
                      onIllegalTap: (_) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text("You must follow suit if you can."),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      },
                    ),
                  ),

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

        // Round-end / game-end overlay
        if (showRoundEnd && lastDeal != null)
          BridgeRoundEndOverlay(
            result: lastDeal,
            cumulativeScores: state.scores,
            isGameEnd: state.phase == GamePhase.gameEnd,
            onNext: () => _sendCall(ref, 'newDeal'),
          ),
      ],
    );
  }

  // ── Move dispatch ─────────────────────────────────────────────────────────

  void _sendBid(WidgetRef ref, int level, BridgeDenomination denom) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: {
        'type': 'bid',
        'player_id': localPlayerId,
        'data': {
          'level': level,
          'denomination': denom.name,
        },
      },
    );
  }

  void _sendCall(WidgetRef ref, String type) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: {
        'type': type,
        'player_id': localPlayerId,
      },
    );
  }

  void _playCard(WidgetRef ref, PlayingCard card) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: {
        'type': 'playCard',
        'player_id': localPlayerId,
        'data': {
          'card': card.toJson(),
        },
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Legal cards for [playerId] this trick — applies must-follow-suit.
  Set<PlayingCard> _legalCardsFor(String playerId) {
    final hand = state.hands[playerId];
    if (hand == null) return const {};
    if (state.currentTrick.isEmpty) return hand.cards.toSet();
    final leadSuit = state.currentTrick.first.suit;
    if (hand.hasSuit(leadSuit)) {
      return hand.cards.where((c) => c.suit == leadSuit).toSet();
    }
    return hand.cards.toSet();
  }

  String _denomGlyph(BridgeDenomination d) {
    switch (d) {
      case BridgeDenomination.clubs:
        return '♣';
      case BridgeDenomination.diamonds:
        return '♦';
      case BridgeDenomination.hearts:
        return '♥';
      case BridgeDenomination.spades:
        return '♠';
      case BridgeDenomination.noTrump:
        return 'NT';
    }
  }
}

/// Temporary on-screen diagnostic strip — shows whether the bot controller
/// knows about the bots and whose turn it is. Remove once bot dispatch is
/// confirmed working.
class _DebugStrip extends ConsumerWidget {
  final BridgeState state;
  final String localPlayerId;
  const _DebugStrip({required this.state, required this.localPlayerId});

  String _short(String id) => id.length >= 8 ? id.substring(0, 8) : id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bots = ref.watch(roomBotsProvider);
    final current = state.currentPlayerId ?? '-';
    final isCurrentBot = bots.any((b) => b.id == current);
    final isCurrentMe = current == localPlayerId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: Colors.black.withOpacity(0.55),
      child: Text(
        'bots=${bots.length} '
        'me=${_short(localPlayerId)} '
        'cur=${_short(current)} '
        '${isCurrentMe ? 'MY-TURN' : isCurrentBot ? 'BOT-TURN' : 'OTHER'} '
        'phase=${state.phase.name} '
        'auct=${state.auctionHistory.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
