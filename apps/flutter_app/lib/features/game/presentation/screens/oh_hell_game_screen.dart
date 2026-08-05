import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/animations/celebrations/loser_sad_animation.dart';
import '../../../../shared/animations/celebrations/winner_jump_animation.dart';
import '../../../../shared/animations/gameplay/bidding_pulse.dart';
import '../../../../shared/animations/gameplay/ohell_bust_animation.dart';
import '../../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../lobby/models/room_member.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_rewards_provider.dart';
import '../../providers/game_session_providers.dart';
import '../../services/ready_broadcast_controller.dart';
import '../../services/round_advance_guard.dart';
import '../widgets/bid_action_chip.dart';
import '../widgets/bid_pill.dart';
import '../widgets/bidding_modal.dart';
import '../widgets/game_toast.dart';
import '../widgets/card_hand.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/oh_hell_round_end_overlay.dart';
import '../widgets/ranked_game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/player_node.dart';
import '../widgets/round_end_celebration_layer.dart';
import '../widgets/between_rounds_ready_icon.dart';
import '../widgets/round_end_ribbon.dart';
import '../widgets/score_display.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/turn_timer.dart';

/// Stable global key on the trick zone — used by CardHand to fly played
/// cards toward where they'll land. Only one Oh Hell screen mounts at a time,
/// so a top-level static key is safe.
final GlobalKey _ohHellTrickZoneKey = GlobalKey();

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
  /// Reset when a new round's bidding phase starts (bids empty).
  final Set<String> _bustedAnimated = {};

  /// Cache of bid results captured BEFORE the engine clears bids at round end.
  /// Maps playerId → true if they made their bid exactly, false otherwise.
  /// Without this cache, _ohHellWinners() reads empty bids and everyone loses.
  Map<String, bool> _playerMadeBid = {};

  /// Completed-round index (0-based) → MY bid. The engine's round history
  /// keeps only points, so the score sheet's 'You bid' row is fed from this
  /// on-device capture (rounds before a mid-game rejoin render '—').
  final Map<int, int> _myBidHistory = {};

  /// One GlobalKey per seat — fed into PlayerNode and TrickZone so opponent
  /// card flights know where each player sits.
  final Map<String, GlobalKey> _seatKeys = {};

  /// Currently active bust: playerId of the seat the flames spew from.
  /// Cleared when the animation completes.
  String? _activeBustPlayerId;
  Alignment? _activeBustAlignment;

  /// Round number for which the deal animation has finished. The bidding
  /// modal stays hidden until this catches up to the current round so the
  /// cards have time to fan in first.
  int? _dealAnimatedRound;
  Timer? _dealTimer;

  /// Snapshot of the trick that just completed. The server clears
  /// currentTrick the moment the 4th card lands and the winner becomes the
  /// next leader; without this hold the cards vanish before the human can
  /// see who won.
  List<TrickCard>? _heldTrick;
  String? _heldWinnerId;
  String? _heldWinnerName;
  Timer? _heldTrickTimer;
  static const Duration _heldTrickDuration = Duration(milliseconds: 2200);
  // Trick-winner celebration is delayed until AFTER the cards finish
  // collecting (~950ms collect after hold). Mirrors 29 + Bridge.
  String? _celebrationWinnerId;
  Timer? _celebrationStartTimer;
  Timer? _celebrationClearTimer;

  /// Tracks the previous tricksWon + currentTrick so we can spot the
  /// trick-completion edge without needing server-side phase changes.
  Map<String, int> _prevTricksWon = const {};
  List<TrickCard> _prevTrick = const [];
  Map<String, List<PlayingCard>> _prevHandsCards = const {};

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

  /// Over/Under verdict flash (story #225): shown once per round the moment
  /// the last bid lands (bidding → playing edge). [_flashShownRound] guards
  /// re-fire on rebuilds; [_activeFlashDelta] drives the banner.
  GamePhase? _prevPhaseForFlash;
  int? _flashShownRound;
  int? _activeFlashDelta;
  Timer? _flashTimer;
  // Muted verdict tints — desaturated terracotta / slate so the chip and
  // banner read as information, not alarm (loud saturated first pass was
  // flagged in staging review).
  static const Color _overbidColor = Color(0xFF9E5B4E);
  static const Color _underbidColor = Color(0xFF54767F);

  /// Explainer toast for the Over/Under HUD chip (story #226).
  String? _statusToastMessage;

  bool _wasRoundEnd = false;
  Timer? _readyTicker;
  int _secondsElapsed = 0;
  static const int _countdownLimit = 30;

  /// The podium dialog is held back briefly at game end so the table-level
  /// yay/smoke celebrations get a moment on screen before the modal covers
  /// them.
  bool _gameOverDialogVisible = false;
  Timer? _gameOverDialogTimer;
  static const Duration _gameOverDialogDelay = Duration(milliseconds: 2600);

  @override
  void dispose() {
    _dealTimer?.cancel();
    _heldTrickTimer?.cancel();
    _celebrationStartTimer?.cancel();
    _celebrationClearTimer?.cancel();
    _readyTicker?.cancel();
    _gameOverDialogTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  int _totalBids(OhHellState state) =>
      state.bids.values.fold<int>(0, (a, b) => a + b);

  /// Opponents' bids so far, in actual bidding order (starting left of the
  /// dealer), for the bid panel's "So far" row. The local player never
  /// appears — the panel is only visible before they've bid.
  List<({String label, BidActionChip chip})> _bidActionsSoFar(
      OhHellState state, Map<String, RoomMember> members) {
    final n = state.playerOrder.length;
    final actions = <({String label, BidActionChip chip})>[];
    for (var i = 1; i <= n; i++) {
      final seatIndex = (state.dealerIndex + i) % n;
      final pid = state.playerOrder[seatIndex];
      final bid = state.bids[pid];
      if (bid == null || pid == widget.localPlayerId) continue;
      actions.add((
        label: PlayerAvatar.nameFor(
          playerId: pid,
          localPlayerId: widget.localPlayerId,
          seatIndex: seatIndex,
          displayName: members[pid]?.displayName,
        ),
        chip: BidActionChip(action: BidAction.bid, value: bid),
      ));
    }
    return actions;
  }

  /// One-line bidding summary for the bid panel + its minimized chip.
  String _claimSummary(OhHellState state) {
    final total = state.cardsThisRound;
    if (state.bids.isEmpty) {
      return 'You bid first · $total trick${total == 1 ? '' : 's'}';
    }
    final claimed = _totalBids(state);
    return '$claimed/$total bid claimed';
  }

  /// Fires the one-time OVERBID/UNDERBID banner on the bidding → playing
  /// edge. Joining mid-round (prev phase null) never flashes.
  void _checkForBidVerdictFlash(OhHellState state) {
    final prev = _prevPhaseForFlash;
    _prevPhaseForFlash = state.phase;
    if (prev != GamePhase.bidding || state.phase != GamePhase.playing) return;
    if (_flashShownRound == state.roundNumber) return;
    final delta = _totalBids(state) - state.cardsThisRound;
    if (delta == 0) return;
    _flashShownRound = state.roundNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _activeFlashDelta = delta);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 3400), () {
        if (!mounted) return;
        setState(() => _activeFlashDelta = null);
      });
    });
  }

  void _syncGameOverDialog(OhHellState state) {
    if (state.isGameOver) {
      if (_gameOverDialogVisible || _gameOverDialogTimer != null) return;
      _gameOverDialogTimer = Timer(_gameOverDialogDelay, () {
        if (!mounted) return;
        setState(() => _gameOverDialogVisible = true);
      });
    } else if (_gameOverDialogVisible || _gameOverDialogTimer != null) {
      // Play Again restarted the session — clear for the fresh game.
      _gameOverDialogTimer?.cancel();
      _gameOverDialogTimer = null;
      _gameOverDialogVisible = false;
    }
  }

  /// Final standings for the podium dialog, one entry per seat.
  List<RankedPlayerResult> _gameResults(
      OhHellState state, Map<String, RoomMember> members) {
    final emojis = PlayerAvatar.emojiMap(state.playerOrder);
    return [
      for (final pid in state.playerOrder)
        RankedPlayerResult(
          playerId: pid,
          name: PlayerAvatar.nameFor(
            playerId: pid,
            localPlayerId: widget.localPlayerId,
            seatIndex: state.playerOrder.indexOf(pid),
            displayName: members[pid]?.displayName,
          ),
          emoji: emojis[pid] ?? '🎮',
          score: state.scores[pid] ?? 0,
          isLocal: pid == widget.localPlayerId,
        ),
    ];
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

      // Subscribe only after the round actually ends — avoids noise on the
      // active-round channel.
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
      _startNextRound(ref);
    }
  }

  /// Caches bid results (made vs missed) BEFORE the engine clears bids at
  /// round end. Must be called every build while bids are still populated;
  /// the cache persists into roundEnd phase where bids are already empty.
  void _cacheBidResults(OhHellState state) {
    // Snapshot current bid results while bids are still available.
    if (state.bids.isNotEmpty) {
      for (final pid in state.playerOrder) {
        final bid = state.bids[pid];
        final won = state.tricksWon[pid] ?? 0;
        if (bid != null) {
          _playerMadeBid[pid] = (bid == won);
        }
      }
      // While round N is live, history holds N-1 entries — so the current
      // round's future history index is exactly roundHistory.length.
      final myBid = state.bids[widget.localPlayerId];
      if (myBid != null) {
        _myBidHistory[state.roundHistory.length] = myBid;
      }
    }
    // Clear the cache when a new round's bidding starts (bids empty).
    if (state.phase == GamePhase.bidding && state.bids.isEmpty) {
      _playerMadeBid.clear();
      // Fresh game (no history yet) → previous session's bids are stale.
      if (state.roundHistory.isEmpty) _myBidHistory.clear();
    }
  }

  /// Players who made their bid exactly this round. They get the jump
  /// animation at round end; everyone else (overshot or undershot) gets
  /// the sad shake. Multiple winners are valid — Oh Hell awards points to
  /// every player who matched their bid.
  ///
  /// Prefers cached results from [_playerMadeBid] when available, falling
  /// back to live state. This handles the race where bids are cleared
  /// before roundEnd finishes rendering.
  Set<String> _ohHellWinners(OhHellState state) {
    final winners = <String>{};
    for (final pid in state.playerOrder) {
      // Prefer cached result if available (covers roundEnd when bids empty).
      if (_playerMadeBid.containsKey(pid)) {
        if (_playerMadeBid[pid] == true) {
          winners.add(pid);
        }
        continue;
      }
      // Fallback to live state during active play.
      final bid = state.bids[pid];
      final won = state.tricksWon[pid] ?? 0;
      if (bid != null && bid == won) {
        winners.add(pid);
      }
    }
    return winners;
  }

  String _ohHellRibbonMessage(OhHellState state, Set<String> winnerIds, Map<String, RoomMember> members) {
    if (winnerIds.isEmpty) return 'Round ${state.roundNumber - 1} ended in a tie';
    final winnerId = winnerIds.first;
    final pts = state.roundHistory.isNotEmpty
        ? (state.roundHistory.last[winnerId] ?? 0)
        : 0;
    final name = PlayerAvatar.nameFor(
      playerId: winnerId,
      localPlayerId: widget.localPlayerId,
      seatIndex: state.playerOrder.indexOf(winnerId),
      displayName: members[winnerId]?.displayName,
    );
    return 'Round won by $name — +$pts pts';
  }

  void _openOhHellScoreboard(BuildContext context, OhHellState state, WidgetRef ref) {
    GlassBottomSheet.show<void>(
      context: context,
      title: state.phase == GamePhase.gameEnd
          ? 'Game Over'
          : 'Round ${state.roundNumber - 1}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OhHellScoreTable(
              roundNumber: state.roundNumber - 1,
              cardsThisRound: state.cardsThisRound,
              playerOrder: state.playerOrder,
              localPlayerId: widget.localPlayerId,
              bids: state.bids,
              tricksWon: state.tricksWon,
              roundPoints: state.roundHistory.isNotEmpty
                  ? state.roundHistory.last
                  : const {},
              scores: state.scores,
              roundHistory: state.roundHistory,
              isGameOver: state.phase == GamePhase.gameEnd,
              myBidHistory: _myBidHistory,
              playerNames: {
                for (final e in ref.read(roomMembersProvider).entries)
                  if (e.value.displayName.trim().isNotEmpty)
                    e.key: e.value.displayName,
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  _readyTicker?.cancel();
                  _readyTicker = null;
                  Navigator.of(context).pop();
                  _startNextRound(ref);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC47B2B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      state.phase == GamePhase.gameEnd
                          ? 'Play Again'
                          : 'Next Round',
                      style: const TextStyle(
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

  void _checkForTrickEnd(OhHellState state, Map<String, RoomMember> members) {
    // Need a prior frame to compare against; first build seeds the cache.
    final prevTrick = _prevTrick;
    final prevTricksWon = _prevTricksWon;
    final prevHands = _prevHandsCards;
    _prevTrick = state.currentTrick;
    _prevTricksWon = state.tricksWon;
    _prevHandsCards = {
      for (final entry in state.hands.entries)
        entry.key: List<PlayingCard>.from(entry.value.cards),
    };

    // A trick "just completed" when the previous frame had a full trick and
    // the new frame's currentTrick is empty. The engine collapses play-4th
    // + clear-trick into one state update, so we accept "nearly full" too
    // and reconstruct the missing card via hand-diff (see 29 screen for the
    // rationale).
    final isEmpty = state.currentTrick.isEmpty;
    final playerCount = state.playerOrder.length;
    final wasFull = prevTrick.length == playerCount;
    final wasNearlyFull = prevTrick.length == playerCount - 1;
    if (!isEmpty) return;
    if (!wasFull && !wasNearlyFull) return;

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
        final missing =
            prevCards.where((c) => !currSet.contains(c)).toList();
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

    String? winnerId;
    for (final pid in state.playerOrder) {
      final before = prevTricksWon[pid] ?? 0;
      final after = state.tricksWon[pid] ?? 0;
      if (after > before) {
        winnerId = pid;
        break;
      }
    }
    if (winnerId == null) return;

    final winnerName = PlayerAvatar.nameFor(
      playerId: winnerId,
      localPlayerId: widget.localPlayerId,
      seatIndex: state.playerOrder.indexOf(winnerId),
      displayName: members[winnerId]?.displayName,
    );

    _heldTrickTimer?.cancel();
    // Update synchronously — these fields are read later in the same
    // build pass via the TrickZone construction. The earlier postFrame
    // path cost one frame of empty trick zone between engine clear and
    // held set, which the user perceived as a flash.
    _heldTrick = fullTrick;
    _heldWinnerId = winnerId;
    _heldWinnerName = winnerName;
    _celebrationStartTimer?.cancel();
    _celebrationClearTimer?.cancel();
    if (_celebrationWinnerId != null) _celebrationWinnerId = null;
    _heldTrickTimer = Timer(_heldTrickDuration, () {
      if (!mounted) return;
      setState(() {
        _heldTrick = null;
        _heldWinnerId = null;
        _heldWinnerName = null;
      });
    });
    // Celebrate AFTER the collect finishes with a small visual breath:
    // 2200ms hold + ~950ms collect + 350ms beat = 3500ms.
    _celebrationStartTimer = Timer(
      const Duration(milliseconds: 3500),
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

  void _checkForBust(OhHellState state) {
    // Reset per-round memory when a NEW round's bidding phase starts.
    // The old roundNumber-based clear happened too early (before roundEnd
    // finished rendering), causing the cache to be wiped while still needed.
    if (state.phase == GamePhase.bidding && state.bids.isEmpty) {
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

  Set<PlayingCard> _legalCardsFor(String playerId) {
    final hand = widget.state.hands[playerId];
    if (hand == null) return const {};
    if (widget.state.currentTrick.isEmpty) return hand.cards.toSet();
    final leadSuit = widget.state.currentTrick.first.suit;
    if (hand.hasSuit(leadSuit)) {
      return hand.cards.where((c) => c.suit == leadSuit).toSet();
    }
    return hand.cards.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final roomId = widget.roomId;
    final localPlayerId = widget.localPlayerId;

    // Identity lookup populated by the room screen — without it every seat
    // falls back to "Bot N" and humans appear to be bots.
    final members = ref.watch(roomMembersProvider);

    // Cache bid results BEFORE they get cleared — _ohHellWinners() needs this
    // at roundEnd when the engine has already wiped state.bids.
    _cacheBidResults(state);
    _checkForBust(state);
    _checkForTrickEnd(state, members);
    _checkForBidVerdictFlash(state);
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

    final isRoundEnd = state.phase == GamePhase.roundEnd ||
        state.phase == GamePhase.gameEnd;
    // Seat verdicts (YAY / OH HELL) always reflect THE ROUND — did you make
    // your bid exactly — including the final round. The overall game result
    // is the podium's job (product decision 2026-08-04: a player who nails
    // their last bid but loses the game was reading the game-end "OH HELL"
    // as a scoring error).
    final winnerPlayerIds =
        !isRoundEnd ? const <String>{} : _ohHellWinners(state);
    final showPulse = state.phase == GamePhase.bidding &&
        state.currentPlayerId == localPlayerId;

    // Auto-advance only between rounds. At game end there is no next round
    // to advance to — the podium dialog takes over (its old 30s newRound
    // auto-fire bounced off the server's finished-room gate forever, which
    // is why games looked "stuck").
    _syncAutoAdvance(state.phase == GamePhase.roundEnd, members);
    _syncGameOverDialog(state);

    final playerRecords = _playerRecords(members);
    final isPaused = isRoundEnd && !RoundAdvanceGuard.hasAnyHumans(playerRecords);
    final readySet = ref.watch(readyBroadcastControllerProvider);
    final remainingSeconds = (_countdownLimit - _secondsElapsed).clamp(0, _countdownLimit);
    final isLocalReady = readySet.contains(localPlayerId);
    // chipsRow removed — per-player ready chips now live inside each PlayerNode.

    // Round-status HUD segment: live claim counter while bidding, then the
    // round's Over/Under verdict during play, hidden between rounds.
    final totalBids = _totalBids(state);
    final bidDelta = totalBids - state.cardsThisRound;
    String? roundStatusText;
    Color? roundStatusColor;
    String? statusExplainer;
    if (state.phase == GamePhase.bidding) {
      roundStatusText = '$totalBids/${state.cardsThisRound} bid claimed';
    } else if (state.phase == GamePhase.playing && bidDelta != 0) {
      roundStatusText = bidDelta > 0
          ? '$totalBids/${state.cardsThisRound} Overbid'
          : '$totalBids/${state.cardsThisRound} Underbid';
      roundStatusColor = bidDelta > 0 ? _overbidColor : _underbidColor;
      statusExplainer = bidDelta > 0
          ? '$totalBids tricks bid, only ${state.cardsThisRound} exist — someone has to bust 🔥'
          : 'Only $totalBids of ${state.cardsThisRound} tricks bid — ${-bidDelta} trick${bidDelta == -1 ? '' : 's'} nobody wants must go to someone';
    }
    final explainer = statusExplainer;

    return Stack(
      children: [
        // Game table background
        RoundEndCelebrationLayer(
          winnerPlayerIds: winnerPlayerIds,
          seatKeys: _seatKeys,
          child: GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Oh Hell',
                  // The engine bumps roundNumber at round COMPLETION, so
                  // during the ready screen the raw value already names the
                  // NEXT round. Show the round just played until the next
                  // one actually deals (mirrors the score sheet).
                  roundNumber: state.phase == GamePhase.roundEnd
                      ? (state.roundNumber > 1 ? state.roundNumber - 1 : 1)
                      : state.roundNumber,
                  totalRounds: state.totalRounds,
                  trumpInfo: '♥',
                  cardsDealt: state.cardsThisRound,
                  socialMode: state.socialMode,
                  isSpectator: isSpectator,
                  roundStatusText: roundStatusText,
                  roundStatusColor: roundStatusColor,
                  onRoundStatusTap: explainer == null
                      ? null
                      : () => setState(() => _statusToastMessage = explainer),
                  onScoreboardTap: () =>
                      _openOhHellScoreboard(context, state, ref),
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: isSpectator,
                  ),
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

                        final member = members[playerId];
                        final displayName = PlayerAvatar.nameFor(
                          playerId: playerId,
                          localPlayerId: localPlayerId,
                          seatIndex: seat.seatIndex,
                          displayName: member?.displayName,
                        );
                        final seatKey = _seatKeys.putIfAbsent(
                            playerId, () => GlobalKey());
                        final node = PlayerNode(
                          name: displayName,
                          emoji: playerEmojis[playerId] ?? '🎮',
                          won: won,
                          bid: bid,
                          isActive: isPlayerActive,
                          hasPlayed: hasPlayed,
                          isDealer: isDealer,
                          isBot: member?.isBot ?? false,
                          isSmall: seat.isSmall,
                          socialMode: state.socialMode,
                          showBidPill: true,
                          hasBid: state.bids.containsKey(playerId),
                          roomId: roomId,
                          playerId: playerId,
                          nodeKey: seatKey,
                          // Internal pulse/jump/sad ONLY mid-trick. At
                          // round end the outer wrapper (yay-cheer or
                          // sad) takes over so we don't double-animate.
                          // Both fire on the delayed _celebrationWinnerId
                          // timer (3150ms after trick = after the cards
                          // have swooped to the winner).
                          isTrickWinnerPulsing: !isRoundEnd &&
                              _celebrationWinnerId == playerId &&
                              (state.tricksWon[playerId] ?? 0) <=
                                  (state.bids[playerId] ?? 0),
                          isTrickWinnerBusted: !isRoundEnd &&
                              _celebrationWinnerId == playerId &&
                              (state.tricksWon[playerId] ?? 0) >
                                  (state.bids[playerId] ?? 0),
                          // Speech bubble: at round end → final verdict.
                          // Mid-game → only "OH HELL" when a bust just
                          // happened, so the regret is unmistakable. No
                          // mid-game YAY pill (a single trick win isn't
                          // worth the shout).
                          // A ready player's verdict pill dies with the game
                          // it describes — once they confirm ready for the
                          // next game, the badge replaces YAY/OH HELL (#20).
                          reactionEmote: isRoundEnd
                              ? (readySet.contains(playerId)
                                  ? null
                                  : winnerPlayerIds.contains(playerId)
                                      ? 'YAY!'
                                      : 'OH HELL')
                              : (_celebrationWinnerId == playerId &&
                                      (state.tricksWon[playerId] ?? 0) >
                                          (state.bids[playerId] ?? 0)
                                  ? 'OH HELL'
                                  : null),
                          isReady: isRoundEnd
                              ? readySet.contains(playerId)
                              : null,
                        );
                        final wrapped = isRoundEnd
                            ? (winnerPlayerIds.contains(playerId)
                                ? _RoundEndYayAnimation(
                                    key: ValueKey('winner-$playerId-${state.roundNumber}'),
                                    child: node,
                                  )
                                : _RoundEndOhHellSmoke(
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

                      // Trick zone (center) — show the held trick during
                      // the post-win pause so the player can see what just
                      // happened, otherwise show the live trick.
                      Center(
                        child: KeyedSubtree(
                          key: _ohHellTrickZoneKey,
                          child: TrickZone(
                            currentTrick: _heldTrick ?? state.currentTrick,
                            playerOrder: state.playerOrder,
                            playerEmojis: playerEmojis,
                            winningPlayerId: _heldWinnerId,
                            trumpSuit: Suit.hearts,
                            seatKeys: _seatKeys,
                            localPlayerId: localPlayerId,
                            lastTrickWinnerId: _heldWinnerId,
                            trickHold: const Duration(milliseconds: 2200),
                            fullTrickSize: state.playerOrder.length,
                          ),
                        ),
                      ),

                      // Trick winner banner removed — the winning card's
                      // bright/dimmed treatment plus the winner's
                      // PlayerNode jump animation communicate the result
                      // without a text overlay.

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
                              trumpInfo: '♥',
                              opponentActions:
                                  _bidActionsSoFar(state, members),
                              claimSummary: _claimSummary(state),
                              minimizedDetail:
                                  '$totalBids/${state.cardsThisRound} bid claimed',
                              onBidSelected: (bid) => _placeBid(ref, bid),
                            ),
                          ),
                        ),

                      // One-time OVERBID/UNDERBID verdict banner — sweeps in
                      // the moment the last bid lands, then settles into the
                      // quiet HUD chip. Dead-centre: the trick zone is empty
                      // while it shows (bots wait it out), and higher
                      // placements overlapped the top seats' bid pills.
                      if (_activeFlashDelta != null)
                        Align(
                          alignment: Alignment.center,
                          child: _BidVerdictBanner(
                            key: ValueKey(
                                'bid-verdict-${state.roundNumber}'),
                            delta: _activeFlashDelta!,
                          ),
                        ),

                      // Explainer toast for the Over/Under chip.
                      if (_statusToastMessage != null)
                        Align(
                          alignment: const Alignment(0, -0.55),
                          child: GameToast(
                            key: ValueKey(_statusToastMessage),
                            message: _statusToastMessage!,
                            displayDuration:
                                const Duration(milliseconds: 2500),
                            onDismissed: () {
                              if (!mounted) return;
                              setState(() => _statusToastMessage = null);
                            },
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

                // Local player avatar — sits centred above the hand, with
                // the same jump/sad + YAY/OH HELL reaction treatment as
                // opponents. Replaces the standalone BidPill (which lives
                // inside PlayerNode now).
                if (!isSpectator) _buildLocalPlayerNode(state, winnerPlayerIds, readySet),

                // Player hand
                if (!isSpectator)
                  BiddingPulse(
                    isActive: showPulse,
                    child: CardHand(
                      cards: cards,
                      isPlayable: isMyTurn && state.phase == GamePhase.playing,
                      validCards: isMyTurn && state.phase == GamePhase.playing
                          ? _legalCardsFor(localPlayerId)
                          : null,
                      flightTargetKey: _ohHellTrickZoneKey,
                      localEmoji: playerEmojis[localPlayerId],
                      onCardTap: (card) => _playCard(ref, card),
                      onIllegalTap: (_) {
                        final msg = isMyTurn
                            ? "You must follow suit if you can."
                            : "Wait for your turn.";
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

                // Bottom GameActions row removed — forfeit icon is on the
                // HUD now, freeing the area below the hand for the local
                // player's avatar + reaction.
              ],
            ),
          ),
        ),
        ),

        // RoundEndRibbon removed entirely — the scoreboard is on the HUD
        // icon and the ready toggle is on the bottom-right icon.

        // Compact ready icon above the hand — tap to ready up; flips to a
        // green check once the broadcast lands. Bot-only rooms (isPaused)
        // skip this because no human can ready.
        if (state.phase == GamePhase.roundEnd && !isPaused && !isSpectator)
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

        // Local-player avatar is now rendered inline in the Column above
        // the CardHand (see _buildLocalPlayerNode).

        // Podium dialog — crown for the topper, medals for 2nd/3rd,
        // sulking rows for the rest. Delayed ~2.6s so the seat-level
        // celebrations play first.
        if (state.isGameOver && _gameOverDialogVisible)
          Builder(builder: (context) {
            // Tournament matches: replaying a bracket game is not a thing —
            // the primary action becomes "View Bracket", and Home actually
            // goes home instead of popping back to wherever we came from
            // (#176).
            final tournamentId = ref.read(activeTournamentIdProvider);
            return RankedGameOverDialog(
              results: _gameResults(state, members),
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
              playAgainLabel:
                  tournamentId == null ? 'Play Again' : 'View Bracket',
              onPlayAgain: tournamentId == null
                  ? () => _startNextRound(ref)
                  : () => context
                      .go(AppRoutes.tournamentPath(tournamentId)),
              onLeave: tournamentId == null
                  ? () => Navigator.of(context).pop()
                  : () => context.go(AppRoutes.home),
            );
          }),
      ],
    );
  }

  /// Builds the inline local-player avatar that sits centred between the
  /// EmojiBar and the CardHand. Mirrors the seat-loop PlayerNode wiring so
  /// the user sees the same reactions opponents do.
  Widget _buildLocalPlayerNode(
    OhHellState state,
    Set<String> winnerPlayerIds,
    Set<String> readySet,
  ) {
    final localPlayerId = widget.localPlayerId;
    final isRoundEnd = state.phase == GamePhase.roundEnd ||
        state.phase == GamePhase.gameEnd;
    final members = ref.read(roomMembersProvider);
    final playerEmojis = PlayerAvatar.emojiMap(state.playerOrder);
    final displayName = PlayerAvatar.nameFor(
      playerId: localPlayerId,
      localPlayerId: localPlayerId,
      seatIndex: state.playerOrder.indexOf(localPlayerId),
      displayName: members[localPlayerId]?.displayName,
    );
    final node = PlayerNode(
      name: displayName,
      emoji: playerEmojis[localPlayerId] ?? '🐯',
      won: state.tricksWon[localPlayerId] ?? 0,
      bid: state.bids[localPlayerId] ?? 0,
      isActive: state.currentPlayerId == localPlayerId,
      hasPlayed: state.currentTrick
          .any((tc) => tc.playerId == localPlayerId),
      isDealer:
          state.playerOrder.indexOf(localPlayerId) == state.dealerIndex,
      isSmall: true,
      socialMode: state.socialMode,
      showBidPill: true,
      hasBid: state.bids.containsKey(localPlayerId),
      // roomId + playerId power the floating reaction/chat bubbles. The
      // local node never received them, so a player's OWN emoji taps were
      // invisible on their own seat — with the missing realtime publication
      // (#9) this made reactions look completely dead in solo games.
      roomId: widget.roomId,
      playerId: localPlayerId,
      // Internal pulse/jump/sad ONLY mid-trick — fires on
      // _celebrationWinnerId (3150ms after trick complete, i.e. after
      // the cards have swooped to the winner).
      isTrickWinnerPulsing: !isRoundEnd &&
          _celebrationWinnerId == localPlayerId &&
          (state.tricksWon[localPlayerId] ?? 0) <=
              (state.bids[localPlayerId] ?? 0),
      isTrickWinnerBusted: !isRoundEnd &&
          _celebrationWinnerId == localPlayerId &&
          (state.tricksWon[localPlayerId] ?? 0) >
              (state.bids[localPlayerId] ?? 0),
      // Same as opponent seats: ready replaces the verdict pill (#20).
      reactionEmote: isRoundEnd
          ? (readySet.contains(localPlayerId)
              ? null
              : winnerPlayerIds.contains(localPlayerId)
                  ? 'YAY!'
                  : 'OH HELL')
          : (_celebrationWinnerId == localPlayerId &&
                  (state.tricksWon[localPlayerId] ?? 0) >
                      (state.bids[localPlayerId] ?? 0)
              ? 'OH HELL'
              : null),
      isReady: isRoundEnd ? readySet.contains(localPlayerId) : null,
    );
    final wrapped = isRoundEnd
        ? (winnerPlayerIds.contains(localPlayerId)
            ? _RoundEndYayAnimation(
                key: ValueKey('local-winner-${state.roundNumber}'),
                child: node,
              )
            : _RoundEndOhHellSmoke(
                key: ValueKey('local-loser-${state.roundNumber}'),
                child: node,
              ))
        : node;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(child: wrapped),
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
    // Optimistic: the played card leaves the hand and lands in the trick
    // immediately; the server response/realtime reconciles. Without this,
    // the card flashed back into the hand during the round-trip (#211).
    ref.read(gameStateProvider.notifier).sendMoveOptimistic(
      roomId: widget.roomId,
      localMove: OhHellPlayCardMove(
        playerId: widget.localPlayerId,
        card: card,
      ),
      wireMove: {
        'type': 'playCard',
        'player_id': widget.localPlayerId,
        'card': card.toJson(),
      },
      // On rejection the notifier already rolled the card back into the
      // hand; nothing else to do (client-side legality checks make this
      // path near-impossible anyway).
    ).catchError((_) {});
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

/// One-time round verdict banner (story #225): "Overbid — 2" /
/// "Underbid — 1". Scales+fades in, holds ~2.5s so it's actually
/// readable (staging feedback), fades out; ~3.2s total, parent removes at
/// 3.4s.
class _BidVerdictBanner extends StatefulWidget {
  final int delta;

  const _BidVerdictBanner({super.key, required this.delta});

  @override
  State<_BidVerdictBanner> createState() => _BidVerdictBannerState();
}

class _BidVerdictBannerState extends State<_BidVerdictBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 11),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 77),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 11,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 89),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOver = widget.delta > 0;
    final n = widget.delta.abs();
    final color = isOver
        ? _OhHellGameScreenState._overbidColor
        : _OhHellGameScreenState._underbidColor;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            // Glass treatment (matches the modal shell) instead of a solid
            // saturated fill — the verdict should inform, not shout.
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            isOver ? 'Overbid — $n' : 'Underbid — $n',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Game/round-end YAY celebration — the avatar bounces 10 times and emits
/// a floating "yay!" text on each jump. Replaces [WinnerJumpAnimation] for
/// Oh Hell winners because the user asked for a more emphatic celebration
/// than the standard 3-bounce.
/// Round-end OH HELL smoke effect for losers. Wraps [LoserSadAnimation]
/// (existing sad shake + droop + tear) AND emits a row of 🔥 emojis that
/// rise + fade like smoke, paired with a smoky "OH HELL" text that
/// dissolves upward. Replaces the plain LoserSadAnimation at round end.
class _RoundEndOhHellSmoke extends StatefulWidget {
  final Widget child;

  const _RoundEndOhHellSmoke({super.key, required this.child});

  @override
  State<_RoundEndOhHellSmoke> createState() => _RoundEndOhHellSmokeState();
}

class _RoundEndOhHellSmokeState extends State<_RoundEndOhHellSmoke> {
  static const int _fireCount = 6;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        LoserSadAnimation(
          showTear: true,
          child: widget.child,
        ),
        // Fire emojis rising from around the avatar, staggered.
        for (var i = 0; i < _fireCount; i++)
          _FirePuff(
            key: ValueKey('fire-$i'),
            startDelay: Duration(milliseconds: i * 220),
            offsetX: ((i - _fireCount / 2) * 14) + ((i.isOdd ? -6 : 6)),
          ),
        // Smoky OH HELL text that drifts up + fades.
        _SmokyText(key: const ValueKey('smoke-text')),
      ],
    );
  }
}

/// One 🔥 emoji rising upward and fading (smoke-like).
class _FirePuff extends StatefulWidget {
  final Duration startDelay;
  final double offsetX;

  const _FirePuff({super.key, required this.startDelay, required this.offsetX});

  @override
  State<_FirePuff> createState() => _FirePuffState();
}

class _FirePuffState extends State<_FirePuff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;
  late final Animation<double> _scale;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 5,
      ),
    ]).animate(_controller);
    _translateY = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _startTimer = Timer(widget.startDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -6,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(widget.offsetX, _translateY.value),
                child: Transform.scale(
                  scale: _scale.value,
                  child: const Text(
                    '🔥',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Smoky "OH HELL" text that drifts upward and fades. Light-gray with
/// blurred shadow for the smoke read.
class _SmokyText extends StatefulWidget {
  const _SmokyText({super.key});

  @override
  State<_SmokyText> createState() => _SmokyTextState();
}

class _SmokyTextState extends State<_SmokyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.95),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.95),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 0.0),
        weight: 4,
      ),
    ]).animate(_controller);
    _translateY = Tween<double>(begin: -4, end: -80).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -36,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, _translateY.value),
                child: Text(
                  'OH HELL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.75),
                    letterSpacing: 0.6,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 1),
                      ),
                      Shadow(
                        color: Colors.white.withOpacity(0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoundEndYayAnimation extends StatefulWidget {
  final Widget child;

  const _RoundEndYayAnimation({super.key, required this.child});

  @override
  State<_RoundEndYayAnimation> createState() =>
      _RoundEndYayAnimationState();
}

class _RoundEndYayAnimationState extends State<_RoundEndYayAnimation>
    with SingleTickerProviderStateMixin {
  static const int _jumpCount = 10;
  static const Duration _bounceDuration = Duration(milliseconds: 500);

  late final AnimationController _controller;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _bounceDuration * _jumpCount,
    );
    final items = <TweenSequenceItem<double>>[];
    for (var i = 0; i < _jumpCount; i++) {
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -22.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 1,
        ),
      );
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: -22.0, end: 0.0)
              .chain(CurveTween(curve: Curves.bounceOut)),
          weight: 1.5,
        ),
      );
    }
    _translateY = TweenSequence<double>(items).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _translateY,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _translateY.value),
            child: child,
          ),
          child: widget.child,
        ),
        // One floating "yay!" emission per jump, staggered.
        for (var i = 0; i < _jumpCount; i++)
          _FloatingYayText(
            startDelay: _bounceDuration * i,
          ),
      ],
    );
  }
}

/// One staggered "yay!" particle: fades in, rises ~60px, fades out.
class _FloatingYayText extends StatefulWidget {
  final Duration startDelay;

  const _FloatingYayText({required this.startDelay});

  @override
  State<_FloatingYayText> createState() => _FloatingYayTextState();
}

class _FloatingYayTextState extends State<_FloatingYayText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 4,
      ),
    ]).animate(_controller);
    _translateY = Tween<double>(begin: 0, end: -60).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _startTimer = Timer(widget.startDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _opacity.value,
                child: Transform.translate(
                  offset: Offset(0, _translateY.value),
                  child: Text(
                    'yay!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFC47B2B),
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Big celebratory / consolation banner pinned in the mid-screen at game
/// end. Used because the local seat has no PlayerNode (the player's
/// avatar lives implicitly on the CardHand at the bottom).
class _LocalGameEndBanner extends StatefulWidget {
  final bool isWinner;

  const _LocalGameEndBanner({required this.isWinner});

  @override
  State<_LocalGameEndBanner> createState() => _LocalGameEndBannerState();
}

class _LocalGameEndBannerState extends State<_LocalGameEndBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isWinner
                ? const Color(0xFFC47B2B) // accent gold
                : Colors.black.withOpacity(0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.isWinner
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isWinner
                    ? const Color(0xFFC47B2B).withOpacity(0.45)
                    : Colors.black.withOpacity(0.4),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            widget.isWinner ? '🎉 YAY! YOU WON 🎉' : '😭 OH HELL 😭',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

