import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../../../../core/services/supabase_service.dart' show MoveRejection;
import '../../../../core/utils/player_avatar.dart';
import '../../../lobby/models/room_member.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_session_providers.dart';
import '../../services/ready_broadcast_controller.dart';
import '../../services/round_advance_guard.dart';
import '../widgets/bid_action_chip.dart';
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
import '../widgets/between_rounds_ready_icon.dart';
import '../widgets/round_end_ribbon.dart';
import '../widgets/seat_layout.dart';
import '../widgets/trick_zone.dart';
import '../widgets/round_end_overlay.dart';
import '../widgets/trump_indicator.dart';
import '../widgets/trump_reveal_overlay.dart';
import '../widgets/turn_timer.dart';
import '../widgets/twenty_nine_scorecards.dart';
import '../../../../shared/animations/celebrations/doubling_burst.dart';
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
  // Track (roundNumber, dealerIndex) so bid history resets on both new rounds
  // AND redeals (dealer rotates without roundNumber incrementing).
  (int, int) _bidHistoryDealKey = (0, -1);

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

  /// Most-recent bidding action per playerId for the current round/deal. Persists
  /// across modal minimize/restore so the chips stay accurate. Cleared on
  /// every new round and every redeal.
  final Map<String, BidActionChip> _bidHistory = {};
  int _lastBidSeen = 0;
  int _lastMultiplierSeen = 1;
  String? _lastBidderSeen;
  Set<int> _lastRoyalWeddingTeams = const {};

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

  /// Sync the per-player bidding history map against the latest engine
  /// state. We watch a handful of fields that the engine flips when a
  /// player's most recent action changes: [currentBid] / [bidderId] for
  /// bids, [doublingMultiplier] for double/redouble, [passCount] for
  /// passes, and [royalWeddingClaimedByTeam] for the K+Q claim.
  ///
  /// This intentionally tracks only the *most recent* action per player —
  /// for 29 with at most one full bidding rotation this is enough to
  /// answer "what did everyone do?" without a full event log.
  void _updateBidHistory(TwentyNineState state) {
    // Reset between rounds AND between redeals (dealer rotates without
    // roundNumber incrementing). Use a composite key so both cases clear.
    final dealKey = (state.roundNumber, state.dealerIndex);
    if (_bidHistoryDealKey != dealKey) {
      _bidHistoryDealKey = dealKey;
      _bidHistory.clear();
      _lastBidSeen = 0;
      _lastMultiplierSeen = 1;
      _lastBidderSeen = null;
      _lastRoyalWeddingTeams = const {};
    }

    // New bid placed.
    if (state.bidderId != null &&
        (state.bidderId != _lastBidderSeen ||
            state.currentBid != _lastBidSeen)) {
      _bidHistory[state.bidderId!] =
          BidActionChip(action: BidAction.bid, value: state.currentBid);
      _lastBidSeen = state.currentBid;
      _lastBidderSeen = state.bidderId;
    }

    // Double / redouble.
    if (state.doublingMultiplier != _lastMultiplierSeen) {
      if (state.doublingMultiplier == 2 && state.doubledBy != null) {
        _bidHistory[state.doubledBy!] =
            const BidActionChip(action: BidAction.doubled);
      } else if (state.doublingMultiplier == 4 &&
          state.redoubledBy != null) {
        _bidHistory[state.redoubledBy!] =
            const BidActionChip(action: BidAction.redoubled);
      }
      _lastMultiplierSeen = state.doublingMultiplier;
    }

    // Royal Wedding claim — represent it on the chip belonging to the
    // current player when the team count increases. We can't tell which
    // player on the team claimed, but they're the only one whose
    // bidAdjustment-related state changed.
    final claimed = state.royalWeddingClaimedByTeam;
    if (claimed.length > _lastRoyalWeddingTeams.length) {
      final newTeams = claimed.difference(_lastRoyalWeddingTeams);
      for (final team in newTeams) {
        // Mark every player on the claiming team — visually that's
        // honest, since the announcement benefits both partners.
        for (final pid in state.playerOrder) {
          if (state.teamForPlayer(pid) == team) {
            _bidHistory[pid] =
                const BidActionChip(action: BidAction.royalWedding);
          }
        }
      }
      _lastRoyalWeddingTeams = Set<int>.from(claimed);
    }

    // Passes are inferred: during bidding phase, any player who already
    // had a turn but hasn't appeared in history yet has passed. This
    // assumes turn order goes round once (true for 29).
    if (state.phase == GamePhase.bidding) {
      final firstBidderIdx = (state.dealerIndex + 1) % 4;
      final currentIdx = state.playerOrder.indexOf(state.currentPlayerId);
      var idx = firstBidderIdx;
      while (idx != currentIdx) {
        final pid = state.playerOrder[idx];
        _bidHistory.putIfAbsent(
          pid,
          () => const BidActionChip(action: BidAction.pass),
        );
        idx = (idx + 1) % 4;
        if (idx == firstBidderIdx) break;
      }
    }
  }

  /// Build the (label, chip) pairs the bidding modal renders so the local
  /// player can see what everyone else has done without dismissing the
  /// modal.
  List<({String label, BidActionChip chip})> _opponentActionsForModal(
      TwentyNineState state) {
    final members = ref.read(roomMembersProvider);
    final result = <({String label, BidActionChip chip})>[];
    final seatStart = (state.dealerIndex + 1) % 4;
    for (var i = 0; i < state.playerOrder.length; i++) {
      final pid = state.playerOrder[(seatStart + i) % 4];
      if (pid == widget.localPlayerId) continue;
      final chip = _bidHistory[pid];
      if (chip == null) continue;
      final name = members[pid]?.displayName ?? 'Player ${i + 1}';
      result.add((label: name, chip: chip));
    }
    return result;
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
    final baseThreshold = state.currentBid == 29 ? 28 : state.currentBid;
    final threshold = baseThreshold + state.bidAdjustment;
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
    final baseThreshold = state.currentBid == 29 ? 28 : state.currentBid;
    final threshold = baseThreshold + state.bidAdjustment;
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
              bidAdjustment: state.bidAdjustment,
              redPips: state.redPips,
              blackPips: state.blackPips,
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

    // Find the specific player who won the trick — not just any teammate.
    // The previous code picked the first member of the winning team in
    // fullTrick iteration order, which credited the wrong player whenever
    // the actual winner was the partner. We replicate the trick-winner
    // rule here: highest trump if any was played, else highest card in
    // the lead suit.
    final winnerId = _determineTrickWinnerId(fullTrick, state.trumpSuit);
    if (winnerId == null) return;
    // Sanity guard: if the engine's tricksWon delta points at a different
    // team than the card-rule winner, the engine is the source of truth
    // (it knows about partnered tricks etc.). Bail rather than pulse the
    // wrong seat.
    if (state.teamForPlayer(winnerId) != winnerTeam) return;

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

  /// Determine which player won a completed trick. Mirrors the server-side
  /// `determineTrickWinner` in `_shared/game_rules/twenty_nine.ts`:
  ///   • If trump is set, highest trump wins.
  ///   • Otherwise, highest card in the lead suit wins.
  ///
  /// Returns the winning player's id, or null on an empty trick. We keep
  /// this local instead of importing from the engine package so the screen
  /// doesn't pull a dependency just for the celebration label — the rule
  /// is small and stable.
  String? _determineTrickWinnerId(List<TrickCard> trick, Suit? trumpSuit) {
    if (trick.isEmpty) return null;
    final leadSuit = trick.first.card.suit;
    TrickCard winner = trick.first;

    for (var i = 1; i < trick.length; i++) {
      final cur = trick[i];

      if (trumpSuit != null) {
        final curIsTrump = cur.card.suit == trumpSuit;
        final winIsTrump = winner.card.suit == trumpSuit;
        if (curIsTrump && !winIsTrump) {
          winner = cur;
          continue;
        }
        if (winIsTrump && !curIsTrump) continue;
        if (curIsTrump && winIsTrump) {
          if (TwentyNineConfig.cardStrength(cur.card) >
              TwentyNineConfig.cardStrength(winner.card)) {
            winner = cur;
          }
          continue;
        }
      }

      // Neither trump: only lead-suit cards can beat the current winner.
      if (cur.card.suit != leadSuit) continue;
      if (winner.card.suit != leadSuit) {
        winner = cur;
        continue;
      }
      if (TwentyNineConfig.cardStrength(cur.card) >
          TwentyNineConfig.cardStrength(winner.card)) {
        winner = cur;
      }
    }
    return winner.playerId;
  }

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
    // Show trump reveal when trump just got revealed.
    if (widget.state.trumpRevealed &&
        !oldWidget.state.trumpRevealed &&
        widget.state.trumpSuit != null) {
      setState(() => _showTrumpReveal = true);
    }
    // Detect a redeal: dealer rotated without roundNumber incrementing.
    final s = widget.state;
    final o = oldWidget.state;
    final isRedeal = s.phase == GamePhase.bidding &&
        s.dealerIndex != o.dealerIndex &&
        s.roundNumber == o.roundNumber &&
        s.passCount == 0;
    if (isRedeal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('All players passed — re-dealing'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final members = ref.watch(roomMembersProvider);
    _detectTrickWinner(state);
    _updateBidHistory(state);
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

    // GameOverDialog was removed in favour of letting the round-end ribbon
    // and per-player jump/sad animations carry the outcome. Treating
    // gameEnd as round-end keeps both alive through game over.
    final isRoundEnd = state.phase == GamePhase.roundEnd ||
        state.phase == GamePhase.gameEnd;
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
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: isSpectator,
                  ),
                  onScoreboardTap: () => _openTwentyNineScoreboard(
                    context,
                    state,
                    winningTeamForRound ?? 0,
                  ),
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

                // Slim integer scoreboard during play. Full card scorecard
                // (red 6 / black 6) appears only on the round-end overlay so
                // the table stays uncluttered mid-game.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: _InlineMatchScore(
                      localScore: state.redPips[localTeam] ?? 0,
                      opponentScore:
                          state.redPips[localTeam == 0 ? 1 : 0] ?? 0,
                      target: 6,
                    ),
                  ),
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
                        final actionChip = _bidHistory[playerId];
                        final nodeWithChip = actionChip == null
                            ? node
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  node,
                                  const SizedBox(height: 3),
                                  actionChip,
                                ],
                              );
                        final wrapped = isRoundEnd
                            ? (winnerPlayerIds.contains(playerId)
                                ? WinnerJumpAnimation(
                                    key: ValueKey('winner-$playerId-${state.roundNumber}'),
                                    child: nodeWithChip,
                                  )
                                : LoserSadAnimation(
                                    key: ValueKey('loser-$playerId-${state.roundNumber}'),
                                    child: nodeWithChip,
                                  ))
                            : nodeWithChip;
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
              // 29 allows the very first bidder to pass too — engine validates.
              showPassButton: true,
              showDoubleButton: canDouble,
              showRedoubleButton: canRedouble,
              bidGridEnabled: state.doublingMultiplier == 1,
              // The "29 = take all 28 pts" special bid is always legal; surfacing
              // it explicitly stops the modal from looking like only Pass is
              // available when bots ratchet the grid out (minBid > 28).
              showBid29Button: true,
              opponentActions: _opponentActionsForModal(state),
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

        // Doubled / Redoubled burst — fires whenever doublingMultiplier
        // climbs (1 → 2 → 4). Sits above all gameplay layers, blocks no
        // input, clears itself after ~1.4s.
        Positioned.fill(
          child: DoublingBurst(
            multiplier: state.doublingMultiplier,
            round: state.roundNumber,
          ),
        ),

        // Royal Wedding button — surfaces when the local player is on the
        // lead, holds K+Q of trump, their team has won ≥1 trick and the
        // claim hasn't been used yet. The engine's getValidMoves is the
        // source of truth; we just ask "is the move legal right now?".
        if (_canClaimRoyalWedding(state, isMyTurn))
          Positioned(
            left: 16,
            bottom: 168,
            child: GestureDetector(
              key: const Key('royal-wedding-claim'),
              onTap: () => _claimRoyalWedding(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Royal Wedding',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                    .markReady(widget.localPlayerId);
                _maybeFireNextRound();
              },
            ),
          ),

        // GameOverDialog removed — the per-player winner-jump / loser-sad
        // animations on the round-end ribbon communicate the outcome, and
        // the scoreboard is accessible via the ribbon's button. Play Again
        // / Leave should live on a small icon row (see follow-up).
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

  /// declareTrump deals the second batch of (hidden) cards, so we can't
  /// predict it locally — wait for the authoritative server result.
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

  /// Send a deterministic move with an optimistic local prediction so the UI
  /// updates instantly; roll back + surface an error only if the server
  /// rejects it.
  Future<void> _sendOptimistic(
    GameMove localMove,
    Map<String, dynamic> wireMove,
  ) async {
    try {
      await ref.read(gameStateProvider.notifier).sendMoveOptimistic(
            roomId: widget.roomId,
            localMove: localMove,
            wireMove: wireMove,
          );
    } on MoveRejection catch (e) {
      _onMoveRejected(e);
    }
  }

  /// Benign rejections (turn/phase races, version conflicts) self-correct via
  /// the realtime backstop after the rollback, so don't nag the user. Anything
  /// else means the move was genuinely illegal — tell them.
  void _onMoveRejected(MoveRejection e) {
    const benign = {'NOT_YOUR_TURN', 'WRONG_PHASE', 'VERSION_CONFLICT'};
    if (benign.contains(e.code) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("That move wasn't allowed — try again.")),
    );
  }

  Future<void> _playCard(PlayingCard card) => _sendOptimistic(
        PlayCardMove(playerId: widget.localPlayerId, card: card),
        {
          'type': 'playCard',
          'player_id': widget.localPlayerId,
          'card': card.toJson(),
        },
      );

  void _placeBid(int bid) {
    _sendOptimistic(
      BidMove(playerId: widget.localPlayerId, bidValue: bid),
      BidMoveDto(playerId: widget.localPlayerId, bidValue: bid).toJson(),
    );
  }

  void _pass() {
    _sendOptimistic(
      PassMove(playerId: widget.localPlayerId),
      {'type': 'pass', 'player_id': widget.localPlayerId},
    );
  }

  void _double() {
    _sendOptimistic(
      DoubleMove(playerId: widget.localPlayerId),
      {'type': 'double', 'player_id': widget.localPlayerId},
    );
  }

  void _redouble() {
    _sendOptimistic(
      RedoubleMove(playerId: widget.localPlayerId),
      {'type': 'redouble', 'player_id': widget.localPlayerId},
    );
  }

  void _revealTrump() {
    _sendOptimistic(
      RevealTrumpMove(playerId: widget.localPlayerId),
      {'type': 'revealTrump', 'player_id': widget.localPlayerId},
    );
  }

  void _claimRoyalWedding() {
    _sendOptimistic(
      ClaimRoyalWeddingMove(playerId: widget.localPlayerId),
      {'type': 'claimRoyalWedding', 'player_id': widget.localPlayerId},
    );
  }

  /// Whether the Royal Wedding button should appear. Mirrors the server
  /// validator so the button is only visible when the move would succeed.
  bool _canClaimRoyalWedding(TwentyNineState state, bool isMyTurn) {
    if (state.phase != GamePhase.playing) return false;
    if (state.trumpSuit == null) return false;
    if (state.currentTrick.isNotEmpty) return false;
    if (!isMyTurn) return false;

    final myTeam = state.teamForPlayer(widget.localPlayerId);
    if (state.royalWeddingClaimedByTeam.contains(myTeam)) return false;
    if ((state.tricksWon[myTeam] ?? 0) < 1) return false;

    final hand = state.hands[widget.localPlayerId];
    if (hand == null) return false;
    final trump = state.trumpSuit!;
    final hasK =
        hand.cards.any((c) => c.suit == trump && c.rank == Rank.king);
    final hasQ =
        hand.cards.any((c) => c.suit == trump && c.rank == Rank.queen);
    if (!hasK || !hasQ) return false;

    final isBidderTeam = state.bidWinnerTeam == myTeam;
    if (isBidderTeam && state.currentBid < 20) return false;

    return true;
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
    final baseThreshold = state.currentBid == 29 ? 28 : state.currentBid;
    final threshold = baseThreshold + state.bidAdjustment;
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

/// Mid-game integer scoreboard. The full red/black card scorecard appears
/// only at round end (less visual noise during play).
class _InlineMatchScore extends StatelessWidget {
  final int localScore;
  final int opponentScore;
  final int target;

  const _InlineMatchScore({
    required this.localScore,
    required this.opponentScore,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Match  ',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          Text('$localScore',
              style: const TextStyle(
                  color: Color(0xFFC47B2B),
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const Text('  –  ',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          Text('$opponentScore',
              style: const TextStyle(
                  color: Color(0xFFD52F47),
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text('   first to $target',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
