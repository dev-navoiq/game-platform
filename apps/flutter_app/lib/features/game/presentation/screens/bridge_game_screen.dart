import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/animations/celebrations/loser_sad_animation.dart';
import '../../../../shared/animations/celebrations/winner_jump_animation.dart';
import '../../../../shared/animations/gameplay/bidding_pulse.dart';
import '../../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../lobby/models/room_member.dart';
import '../../providers/bot_move_controller.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_session_providers.dart';
import '../../services/ready_broadcast_controller.dart';
import '../../services/round_advance_guard.dart';
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
import '../widgets/round_end_celebration_layer.dart';
import '../widgets/between_rounds_ready_icon.dart';
import '../widgets/round_end_ribbon.dart';
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
class BridgeGameScreen extends ConsumerStatefulWidget {
  final BridgeState state;
  final String roomId;
  final String localPlayerId;

  const BridgeGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  ConsumerState<BridgeGameScreen> createState() => _BridgeGameScreenState();
}

class _BridgeGameScreenState extends ConsumerState<BridgeGameScreen> {
  final Map<String, GlobalKey> _seatKeys = {};
  Map<String, int> _prevTricksWon = const {};
  List<TrickCard> _prevTrick = const [];
  Map<String, List<PlayingCard>> _prevHandsCards = const {};
  String? _lastTrickWinnerId;
  List<TrickCard>? _heldTrickForCollect;
  Timer? _winnerClearTimer;
  // Trick-winner celebration is delayed until AFTER the cards finish
  // collecting — same shape as the 29 screen.
  String? _celebrationWinnerId;
  Timer? _celebrationStartTimer;
  Timer? _celebrationClearTimer;

  bool _wasRoundEnd = false;
  Timer? _readyTicker;
  int _secondsElapsed = 0;
  static const int _countdownLimit = 30;

  BridgeState get state => widget.state;
  String get roomId => widget.roomId;
  String get localPlayerId => widget.localPlayerId;

  @override
  void dispose() {
    _winnerClearTimer?.cancel();
    _celebrationStartTimer?.cancel();
    _celebrationClearTimer?.cancel();
    _readyTicker?.cancel();
    super.dispose();
  }

  /// Build the `({String id, bool isBot})` records the guard expects.
  /// `isBot` is sourced from [roomMembersProvider] — the engine state only
  /// knows IDs.
  List<({String id, bool isBot})> _playerRecords(Map<String, RoomMember> members) {
    return [
      for (final id in state.playerOrder)
        (id: id, isBot: members[id]?.isBot ?? false),
    ];
  }

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

  void _detectTrickWinner(BridgeState s) {
    final prevTrick = _prevTrick;
    final prevTricks = _prevTricksWon;
    final prevHands = _prevHandsCards;
    _prevTrick = s.currentTrick;
    _prevTricksWon = s.tricksWon;
    _prevHandsCards = {
      for (final entry in s.hands.entries)
        entry.key: List<PlayingCard>.from(entry.value.cards),
    };

    final isCleared = s.currentTrick.isEmpty;
    final playerCount = s.playerOrder.length;
    final wasFull = prevTrick.length == playerCount;
    final wasNearlyFull = prevTrick.length == playerCount - 1;
    if (!isCleared) return;
    if (!wasFull && !wasNearlyFull) return;

    // Reconstruct the 4-card trick when the engine collapses play-4th +
    // clear into one update (see twenty_nine_game_screen._detectTrickWinner
    // for the longer rationale — same shape).
    List<TrickCard> fullTrick;
    if (wasFull) {
      fullTrick = prevTrick;
    } else {
      String? playerWhoPlayed;
      PlayingCard? fourthCard;
      for (final pid in s.playerOrder) {
        final prevCards = prevHands[pid] ?? const <PlayingCard>[];
        final currCards = s.hands[pid]?.cards ?? const <PlayingCard>[];
        if (prevCards.length - currCards.length != 1) continue;
        final currSet = currCards.toSet();
        final missing =
            prevCards.where((c) => !currSet.contains(c)).toList();
        if (missing.length == 1) {
          playerWhoPlayed = pid;
          fourthCard = missing.first;
          break;
        }
      }
      if (playerWhoPlayed == null || fourthCard == null) return;
      final seatIndex = s.playerOrder.indexOf(playerWhoPlayed);
      fullTrick = [
        ...prevTrick,
        TrickCard(
          playerId: playerWhoPlayed,
          card: fourthCard,
          seatIndex: seatIndex,
        ),
      ];
    }

    // currentPlayerId after a completed trick becomes the winner.
    final winnerId = s.currentPlayerId;
    if (winnerId == null) return;
    if (!fullTrick.any((t) => t.playerId == winnerId)) return;
    // Sanity: a team's tricksWon should have ticked up.
    final anyTicked = s.tricksWon.entries.any((e) =>
        (e.value) > (prevTricks[e.key] ?? 0));
    if (!anyTicked) return;

    // Update synchronously — same rationale as 29 screen. The old
    // postFrame-+-setState path left an empty frame between "engine
    // cleared the trick" and "screen showed the reconstructed held
    // trick", which the user perceived as cards flashing.
    _lastTrickWinnerId = winnerId;
    _heldTrickForCollect = fullTrick;
    _celebrationStartTimer?.cancel();
    _celebrationClearTimer?.cancel();
    if (_celebrationWinnerId != null) _celebrationWinnerId = null;
    _winnerClearTimer?.cancel();
    _winnerClearTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() {
        _lastTrickWinnerId = null;
        _heldTrickForCollect = null;
      });
    });
    // Bridge holds 2800ms + collect ~950ms = ~3750ms before celebrating.
    _celebrationStartTimer = Timer(
      const Duration(milliseconds: 3750),
      () {
        if (!mounted) return;
        setState(() => _celebrationWinnerId = winnerId);
        _celebrationClearTimer =
            Timer(const Duration(milliseconds: 1300), () {
          if (!mounted) return;
          setState(() => _celebrationWinnerId = null);
        });
      },
    );
  }

  void _syncAutoAdvance(bool isRoundEnd, Map<String, RoomMember> members) {
    if (isRoundEnd && !_wasRoundEnd) {
      _wasRoundEnd = true;
      _secondsElapsed = 0;

      final botIds = _playerRecords(members)
          .where((p) => p.isBot)
          .map((p) => p.id)
          .toList();

      ref.read(readyBroadcastControllerProvider.notifier).subscribe(
            roomId: roomId,
            roundNumber: state.dealNumber,
            botPlayerIds: botIds,
          );

      _readyTicker?.cancel();
      _readyTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _secondsElapsed += 1);
        _maybeFireNextRound();
      });
    } else if (!isRoundEnd && _wasRoundEnd) {
      _wasRoundEnd = false;
      _readyTicker?.cancel();
      _readyTicker = null;
      _secondsElapsed = 0;
      ref.read(readyBroadcastControllerProvider.notifier).reset();
    }
  }

  void _maybeFireNextRound() {
    // Once the ticker is cancelled we've already fired (or the round
    // ended) — never fire a second time for the same round.
    if (_readyTicker == null) return;
    final readySet = ref.read(readyBroadcastControllerProvider);
    final members = ref.read(roomMembersProvider);
    final records = _playerRecords(members);

    if (RoundAdvanceGuard.shouldAdvance(
      players: records,
      readyPlayerIds: readySet,
      secondsElapsed: _secondsElapsed,
      countdownLimit: _countdownLimit,
    )) {
      _readyTicker?.cancel();
      _readyTicker = null;
      _sendCall(ref, 'newDeal');
    }
  }

  Set<String> _winnersFor(BridgeDealResult deal) {
    if (deal.nsPoints == deal.ewPoints) return const {};
    final winningTeam = deal.nsPoints > deal.ewPoints ? 'NS' : 'EW';
    final winnerSeats = winningTeam == 'NS' ? const [0, 2] : const [1, 3];
    final ids = <String>{};
    for (final seat in winnerSeats) {
      if (seat < state.playerOrder.length) {
        ids.add(state.playerOrder[seat]);
      }
    }
    return ids;
  }

  String _ribbonMessage(BridgeDealResult deal) {
    final contract = deal.contract;
    if (contract == null) return 'Deal ${deal.dealNumber} passed out';
    final glyph = _denomGlyph(contract.denomination);
    final team = contract.declarerTeam;
    final pts = team == 'NS' ? deal.nsPoints : deal.ewPoints;
    if (deal.made) {
      final overs = deal.overtricks == 0 ? '' : '+${deal.overtricks}';
      return '$team made ${contract.level}$glyph$overs — +$pts to $team';
    }
    final defenders = team == 'NS' ? 'EW' : 'NS';
    final defPts = defenders == 'NS' ? deal.nsPoints : deal.ewPoints;
    return '$team down ${deal.undertricks} on ${contract.level}$glyph — +$defPts to $defenders';
  }

  void _openScoreboard(BuildContext context, BridgeDealResult deal) {
    GlassBottomSheet.show<void>(
      context: context,
      title: state.phase == GamePhase.gameEnd ? 'Game Over' : 'Deal ${deal.dealNumber}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BridgeScoreTable(
              result: deal,
              cumulativeScores: state.scores,
              isGameEnd: state.phase == GamePhase.gameEnd,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                key: const Key('bridge-next-deal'),
                onTap: () {
                  _readyTicker?.cancel();
                  _readyTicker = null;
                  Navigator.of(context).pop();
                  _sendCall(ref, 'newDeal');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC47B2B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Next Round',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final members = ref.watch(roomMembersProvider);
    _detectTrickWinner(state);
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
    final isRoundEnd = state.phase == GamePhase.roundEnd ||
        state.phase == GamePhase.gameEnd;
    final lastDeal =
        state.dealHistory.isNotEmpty ? state.dealHistory.last : null;
    final winnerPlayerIds = isRoundEnd && lastDeal != null
        ? _winnersFor(lastDeal)
        : const <String>{};

    final showPulse = state.phase == GamePhase.bidding &&
        state.currentPlayerId == localPlayerId;

    _syncAutoAdvance(isRoundEnd, members);

    final playerRecords = _playerRecords(members);
    final isPaused = isRoundEnd && !RoundAdvanceGuard.hasAnyHumans(playerRecords);
    final readySet = ref.watch(readyBroadcastControllerProvider);
    final remainingSeconds = (_countdownLimit - _secondsElapsed).clamp(0, _countdownLimit);
    final isLocalReady = readySet.contains(localPlayerId);
    // chipsRow removed — per-player ready chips now live inside each PlayerNode.

    return Stack(
      children: [
        RoundEndCelebrationLayer(
          winnerPlayerIds: winnerPlayerIds,
          seatKeys: _seatKeys,
          child: GameTable(
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
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: isSpectator,
                  ),
                  onScoreboardTap: lastDeal == null
                      ? null
                      : () => _openScoreboard(context, lastDeal),
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

                        final seatKey = _seatKeys.putIfAbsent(
                            playerId, () => GlobalKey());
                        final node = PlayerNode(
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
                          nodeKey: seatKey,
                          isTrickWinnerPulsing:
                              _celebrationWinnerId == playerId,
                          isReady: isRoundEnd
                              ? readySet.contains(playerId)
                              : null,
                        );
                        final wrapped = isRoundEnd
                            ? (winnerPlayerIds.contains(playerId)
                                ? WinnerJumpAnimation(
                                    key: ValueKey('winner-$playerId-${state.dealNumber}'),
                                    child: node,
                                  )
                                : LoserSadAnimation(
                                    key: ValueKey('loser-$playerId-${state.dealNumber}'),
                                    child: node,
                                  ))
                            : node;
                        return Align(
                          alignment: seat.alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: wrapped,
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
                            currentTrick: _heldTrickForCollect != null &&
                                    _lastTrickWinnerId != null
                                ? _heldTrickForCollect!
                                : state.currentTrick,
                            playerOrder: state.playerOrder,
                            playerEmojis: playerEmojis,
                            winningPlayerId: _lastTrickWinnerId,
                            trumpSuit: trumpSuit,
                            seatKeys: _seatKeys,
                            localPlayerId: localPlayerId,
                            lastTrickWinnerId: _lastTrickWinnerId,
                            trickHold: const Duration(milliseconds: 2500),
                            fullTrickSize: state.playerOrder.length,
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
                    child: BiddingPulse(
                      isActive: showPulse,
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
                        localEmoji: playerEmojis[localPlayerId],
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
                  ),

              ],
            ),
          ),
        ),
        ),

        // RoundEndRibbon removed entirely.

        // Compact ready icon above the hand.
        if (isRoundEnd && !isPaused && !isSpectator)
          Positioned(
            right: 16,
            bottom: 168,
            child: BetweenRoundsReadyIcon(
              secondsLeft: remainingSeconds,
              isReady: isLocalReady,
              onTap: () {
                ref
                    .read(readyBroadcastControllerProvider.notifier)
                    .markReady(localPlayerId);
                _maybeFireNextRound();
              },
            ),
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
