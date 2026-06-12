import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../../../../core/utils/player_avatar.dart';
import '../../../lobby/models/room_member.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_session_providers.dart';
import '../../services/ready_broadcast_controller.dart';
import '../../services/round_advance_guard.dart';
import '../widgets/bidding_modal.dart';
import '../widgets/card_hand.dart';
import '../widgets/card_sort.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/player_node.dart';
import '../widgets/round_end_celebration_layer.dart';
import '../widgets/round_end_ribbon.dart';
import '../widgets/score_display.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/round_end_overlay.dart';
import '../widgets/trump_indicator.dart';
import '../widgets/trump_reveal_overlay.dart';
import '../widgets/turn_timer.dart';
import '../../../../shared/animations/celebrations/loser_sad_animation.dart';
import '../../../../shared/animations/celebrations/winner_jump_animation.dart';
import '../../../../shared/animations/gameplay/bidding_pulse.dart';
import '../../../../shared/animations/gameplay/shake_animation.dart';
import '../../../../shared/widgets/glass_bottom_sheet.dart';

/// Stable global key on the trick zone — used by CardHand to fly played
/// cards toward where they'll land. Only one 29 screen mounts at a time,
/// so a top-level static key is safe.
final GlobalKey _twentyNineTrickZoneKey = GlobalKey();

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
  final ShakeController _handShake = ShakeController();

  /// One GlobalKey per seat, used to anchor opponent card flights and the
  /// trick-collect animation.
  final Map<String, GlobalKey> _seatKeys = {};

  /// Snapshot of the previous trick + a derived winner id, so TrickZone can
  /// fire its collect animation when a trick completes.
  Map<int, int> _prevTricksWon = const {};
  List<TrickCard> _prevTrick = const [];
  /// Per-player card lists from the previous state. Used to detect which
  /// card the player just played when the engine collapses "play 4th card"
  /// and "clear trick" into a single state update — without this we only
  /// have the 3-card `_prevTrick` and the 4th card never appears in the
  /// held trick.
  Map<String, List<PlayingCard>> _prevHandsCards = const {};
  String? _lastTrickWinnerId;
  Timer? _winnerClearTimer;
  // Trick-winner celebration (pulse ring + jump) is delayed until AFTER
  // the cards finish collecting. The visual order the user sees:
  //  1. cards stay in place during the trick hold (2200ms)
  //  2. cards swoop toward the winner (~950ms collect)
  //  3. _celebrationWinnerId becomes set → winner's seat pulses + jumps
  //  4. _celebrationWinnerId clears 1300ms later
  String? _celebrationWinnerId;
  Timer? _celebrationStartTimer;
  Timer? _celebrationClearTimer;

  bool _wasRoundEnd = false;
  Timer? _readyTicker;
  int _secondsElapsed = 0;
  static const int _countdownLimit = 30;

  @override
  void dispose() {
    _handShake.dispose();
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
      for (final id in widget.state.playerOrder)
        (id: id, isBot: members[id]?.isBot ?? false),
    ];
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
            roomId: widget.roomId,
            roundNumber: widget.state.roundNumber,
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
      _startNextRound();
    }
  }

  Set<String> _winnerIdsForRound(TwentyNineState state, int winningTeam) {
    final ids = <String>{};
    for (final pid in state.playerOrder) {
      if (state.teamForPlayer(pid) == winningTeam) {
        ids.add(pid);
      }
    }
    return ids;
  }

  String _twentyNineRibbonMessage(TwentyNineState state, int winningTeam) {
    final localTeam = state.teamForPlayer(widget.localPlayerId);
    final won = winningTeam == localTeam;
    final biddingTeam = state.bidWinnerTeam ?? 0;
    final bidTeamPts = state.teamPoints[biddingTeam] ?? 0;
    final threshold = state.currentBid == 29 ? 28 : state.currentBid;
    final bidMet = bidTeamPts >= threshold;
    final teamLabel = winningTeam == localTeam ? 'Your team' : 'Opponents';
    final outcome = bidMet ? 'made $threshold' : 'broke the bid';
    return '$teamLabel won the round — $outcome ${won ? '🎉' : ''}'.trim();
  }

  void _openTwentyNineScoreboard(
    BuildContext context,
    TwentyNineState state,
    int winningTeam,
  ) {
    final localTeam = state.teamForPlayer(widget.localPlayerId);
    final biddingTeam = state.bidWinnerTeam ?? 0;
    final bidTeamPts = state.teamPoints[biddingTeam] ?? 0;
    final threshold = state.currentBid == 29 ? 28 : state.currentBid;
    final bidMet = bidTeamPts >= threshold;
    GlassBottomSheet.show<void>(
      context: context,
      title: 'Round ${state.roundNumber - 1}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TwentyNineScoreTable(
              winningTeam: winningTeam,
              localTeam: localTeam,
              bid: state.currentBid,
              biddingTeam: biddingTeam,
              teamPoints: state.teamPoints,
              bidMet: bidMet,
              sessionScores: state.sessionScores,
              roundNumber: state.roundNumber - 1,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  _readyTicker?.cancel();
                  _readyTicker = null;
                  Navigator.of(context).pop();
                  _startNextRound();
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

  void _detectTrickWinner(TwentyNineState state) {
    final prevTrick = _prevTrick;
    final prevTricks = _prevTricksWon;
    final prevHands = _prevHandsCards;
    _prevTrick = state.currentTrick;
    _prevTricksWon = state.tricksWon;
    _prevHandsCards = {
      for (final entry in state.hands.entries)
        entry.key: List<PlayingCard>.from(entry.value.cards),
    };

    final isCleared = state.currentTrick.isEmpty;
    final playerCount = state.playerOrder.length;
    final wasFull = prevTrick.length == playerCount;
    final wasNearlyFull = prevTrick.length == playerCount - 1;
    if (!isCleared) return;
    if (!wasFull && !wasNearlyFull) return;

    // Build the full trick. When `wasFull`, prevTrick already has all cards.
    // When `wasNearlyFull`, reconstruct the missing card via hand-diff: the
    // engine collapses the play-4th + clear-trick into one state update, so
    // the 4th card never landed in prevTrick. We find it by looking for the
    // player whose hand shrank by 1 between states and identifying which card
    // is missing from their new hand.
    List<TrickCard> fullTrick;
    if (wasFull) {
      fullTrick = prevTrick;
    } else {
      String? playerWhoPlayed;
      PlayingCard? fourthCard;
      for (final pid in state.playerOrder) {
        final prevCards = prevHands[pid] ?? const <PlayingCard>[];
        final currCards = state.hands[pid]?.cards ?? const <PlayingCard>[];
        if (prevCards.length - currCards.length != 1) continue;
        final currSet = currCards.toSet();
        final missing = prevCards.where((c) => !currSet.contains(c)).toList();
        if (missing.length == 1) {
          playerWhoPlayed = pid;
          fourthCard = missing.first;
          break;
        }
      }
      if (playerWhoPlayed == null || fourthCard == null) return;
      final seatIndex = state.playerOrder.indexOf(playerWhoPlayed);
      fullTrick = [
        ...prevTrick,
        TrickCard(
          playerId: playerWhoPlayed,
          card: fourthCard,
          seatIndex: seatIndex,
        ),
      ];
    }

    int? winnerTeam;
    for (final entry in state.tricksWon.entries) {
      final before = prevTricks[entry.key] ?? 0;
      if (entry.value > before) {
        winnerTeam = entry.key;
        break;
      }
    }
    if (winnerTeam == null) return;

    String? winnerId;
    for (final tc in fullTrick) {
      if (state.teamForPlayer(tc.playerId) == winnerTeam) {
        if (winnerId == null) {
          winnerId = tc.playerId;
        }
      }
    }
    if (winnerId == null) return;

    // Update synchronously — we're in build but these private fields are
    // read later in the same build pass (the TrickZone construction below
    // uses _heldTrickForCollect). The postFrame-+-setState dance the old
    // code used cost one extra empty frame between "engine cleared the
    // trick" and "screen showed the reconstructed held trick" — visible to
    // the user as the cards flashing out before reappearing. The clear
    // timer still uses setState because it fires later, outside build.
    _lastTrickWinnerId = winnerId;
    _heldTrickForCollect = fullTrick;
    // Reset any prior celebration so the previous winner doesn't keep
    // pulsing while a new trick is being held.
    _celebrationStartTimer?.cancel();
    _celebrationClearTimer?.cancel();
    if (_celebrationWinnerId != null) {
      _celebrationWinnerId = null;
    }
    _winnerClearTimer?.cancel();
    _winnerClearTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _lastTrickWinnerId = null;
        _heldTrickForCollect = null;
      });
    });
    // Light up the winner's seat only AFTER the collect animation has had
    // time to land the cards. 2200ms hold + ~950ms collect = ~3150ms total.
    _celebrationStartTimer = Timer(
      const Duration(milliseconds: 3150),
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

  List<TrickCard>? _heldTrickForCollect;

  Set<PlayingCard> _legalCardsFor(String playerId) {
    final state = widget.state;
    final hand = state.hands[playerId];
    if (hand == null) return const {};
    final cards = hand.cards;
    if (state.currentTrick.isEmpty) return cards.toSet();
    final leadSuit = state.currentTrick.first.suit;
    if (hand.hasSuit(leadSuit)) {
      return cards.where((c) => c.suit == leadSuit).toSet();
    }
    // When trump is hidden, the player may freely discard; the engine doesn't
    // restrict trump play here. Defaulting to "any non-lead card" is correct
    // for both phases — see _validatePlayCard in TwentyNineRules.
    if (state.trumpRevealerThisTrick == playerId &&
        state.trumpSuit != null &&
        hand.hasSuit(state.trumpSuit!)) {
      return cards.where((c) => c.suit == state.trumpSuit).toSet();
    }
    return cards.toSet();
  }

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
    final members = ref.watch(roomMembersProvider);
    _detectTrickWinner(state);
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

    final isRoundEnd = state.phase == GamePhase.roundEnd;
    final winningTeamForRound = isRoundEnd ? _roundWinningTeam(state) : null;
    final winnerPlayerIds = (isRoundEnd && winningTeamForRound != null)
        ? _winnerIdsForRound(state, winningTeamForRound)
        : const <String>{};
    final showPulse = (state.phase == GamePhase.bidding ||
            state.phase == GamePhase.trumpSelection) &&
        state.currentPlayerId == widget.localPlayerId;

    _syncAutoAdvance(isRoundEnd, members);

    final playerRecords = _playerRecords(members);
    final isPaused = isRoundEnd && !RoundAdvanceGuard.hasAnyHumans(playerRecords);
    final readySet = ref.watch(readyBroadcastControllerProvider);
    final remainingSeconds = (_countdownLimit - _secondsElapsed).clamp(0, _countdownLimit);
    final isLocalReady = readySet.contains(widget.localPlayerId);
    // chipsRow removed — per-player ready chips now live inside each PlayerNode.

    if (cards.isEmpty &&
        !isSpectator &&
        state.phase != GamePhase.roundEnd &&
        state.phase != GamePhase.gameEnd) {
      // Diagnostic: a non-spectator participant should always have a hand
      // outside roundEnd/gameEnd. Print per-player card counts so we can
      // see if the server is dealing into the right keys.
      final perPlayer = state.hands
          .map((k, v) => MapEntry(k.substring(0, 8), v.cards.length));
      print('[29Screen] EMPTY HAND for localPlayer=${widget.localPlayerId.substring(0, 8)} '
          'phase=${state.phase} round=${state.roundNumber} '
          'trick=${state.currentTrick.length} '
          'cardsPerPlayer=$perPlayer '
          'currentPlayer=${state.currentPlayerId?.substring(0, 8)}');
    }
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Positioned.fill(child: GameTable(child: const SizedBox.shrink())),

        // Game layout
        Positioned.fill(
          child: RoundEndCelebrationLayer(
            winnerPlayerIds: winnerPlayerIds,
            seatKeys: _seatKeys,
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
                        final seatKey = _seatKeys.putIfAbsent(
                            playerId, () => GlobalKey());
                        final node = PlayerNode(
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
                                    key: ValueKey('winner-$playerId-${state.roundNumber}'),
                                    child: node,
                                  )
                                : LoserSadAnimation(
                                    key: ValueKey('loser-$playerId-${state.roundNumber}'),
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

                      // Trick zone (keyed so CardHand can fly played
                      // cards toward its global position).
                      Center(
                        child: KeyedSubtree(
                          key: _twentyNineTrickZoneKey,
                          child: TrickZone(
                            currentTrick: _heldTrickForCollect != null &&
                                    _lastTrickWinnerId != null
                                ? _heldTrickForCollect!
                                : state.currentTrick,
                            playerOrder: state.playerOrder,
                            playerEmojis: playerEmojis,
                            winningPlayerId: _lastTrickWinnerId,
                            trumpSuit:
                                state.trumpRevealed ? state.trumpSuit : null,
                            seatKeys: _seatKeys,
                            localPlayerId: widget.localPlayerId,
                            lastTrickWinnerId: _lastTrickWinnerId,
                            trickHold: const Duration(milliseconds: 2200),
                            fullTrickSize: state.playerOrder.length,
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
                  roomId: widget.roomId,
                ),
                const SizedBox(height: 4),

                // Player hand
                if (!isSpectator)
                  SizedBox(
                    height: 130,
                    child: TurnIndicator(
                      isYourTurn:
                          isMyTurn && state.phase == GamePhase.playing,
                      child: BiddingPulse(
                        isActive: showPulse,
                        child: ShakeAnimation(
                          controller: _handShake,
                          child: CardHand(
                            cards: cards,
                            isPlayable:
                                isMyTurn && state.phase == GamePhase.playing,
                            validCards:
                                isMyTurn && state.phase == GamePhase.playing
                                    ? _legalCardsFor(widget.localPlayerId)
                                    : null,
                            sorter: twentyNineCardSort,
                            flightTargetKey: _twentyNineTrickZoneKey,
                            localEmoji: playerEmojis[widget.localPlayerId],
                            onCardTap: (card) => _playCard(card),
                            onIllegalTap: (_) {
                              _handShake.shake();
                              final msg = isMyTurn
                                  ? 'You must follow suit if you can.'
                                  : 'Wait for your turn.';
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            },
                          ),
                        ),
                      ),
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

        // Round end ribbon (non-blocking) — bottom-sheet for the full
        // scoreboard, RoundEndCelebrationLayer above paints confetti/trophy.
        // When the room is bot-only (no human players left) the ribbon
        // pauses with a waiting message and omits the ready coordination UI.
        if (isRoundEnd && winningTeamForRound != null)
          Align(
            alignment: Alignment.topCenter,
            child: isPaused
                ? RoundEndRibbon(
                    message:
                        '${_twentyNineRibbonMessage(state, winningTeamForRound)} • Waiting for a player to join...',
                    onShowScoreboard: () => _openTwentyNineScoreboard(
                      context,
                      state,
                      winningTeamForRound,
                    ),
                  )
                : RoundEndRibbon(
                    message: _twentyNineRibbonMessage(state, winningTeamForRound),
                    onShowScoreboard: () => _openTwentyNineScoreboard(
                      context,
                      state,
                      winningTeamForRound,
                    ),
                    countdownSeconds: remainingSeconds,
                    isLocalReady: isLocalReady,
                    onReadyTap: isLocalReady
                        ? null
                        : () {
                            ref
                                .read(readyBroadcastControllerProvider.notifier)
                                .markReady(widget.localPlayerId);
                            _maybeFireNextRound();
                          },
                  ),
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
            // Reuses the newRound move — the server resets sessionScores
            // when the move arrives in gameEnd phase (see applyNewRound).
            onPlayAgain: () => _startNextRound(),
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

  Future<void> _playCard(PlayingCard card) async {
    await ref.read(gameStateProvider.notifier).sendMove(
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
