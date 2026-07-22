import 'package:game_core/game_core.dart';

import 'oh_hell_config.dart';
import 'oh_hell_move.dart';
import 'oh_hell_scoring.dart';
import 'oh_hell_state.dart';

/// Rules engine for Oh Hell (also known as Nomination Whist).
///
/// Players bid the exact number of tricks they expect to win each round.
/// The dealer cannot bid a number that makes the total equal to cards dealt.
/// Hearts are always trump. Exact bids score 10 + bid; misses score 0.
class OhHellRules extends GameRules<OhHellState, OhHellMove> {
  final OhHellScorer _scorer;
  Map<String, dynamic> _serverConfig = {};

  OhHellRules() : _scorer = const OhHellScorer();

  @override
  int get minPlayers => OhHellConfig.minPlayers;

  @override
  int get maxPlayers => OhHellConfig.maxPlayers;

  @override
  List<int> get validPlayerCounts =>
      List.generate(maxPlayers - minPlayers + 1, (i) => minPlayers + i);

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  @override
  OhHellState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) applyServerConfig(serverConfig);
    // Host-chosen length options live under `oh_hell` in the room config,
    // same shape the server reads in game_setup.ts.
    final options = _serverConfig['oh_hell'];
    final sequence = OhHellConfig.roundSequence(
      playerIds.length,
      maxCards: options is Map ? (options['max_cards'] as num?)?.toInt() : null,
      downOnly: options is Map && options['down_only'] == true,
    );
    return _startRound(
      playerIds: playerIds,
      dealerIndex: dealerIndex,
      roundSequenceIndex: 0,
      roundSequence: sequence,
      totalRounds: sequence.length,
      scores: {for (final pid in playerIds) pid: 0},
      roundNumber: 1,
    );
  }

  OhHellState _startRound({
    required List<String> playerIds,
    required int dealerIndex,
    required int roundSequenceIndex,
    required List<int> roundSequence,
    required int totalRounds,
    required Map<String, int> scores,
    required int roundNumber,
  }) {
    final cardsThisRound = roundSequence[roundSequenceIndex];
    final deck = Deck.standard52();
    deck.shuffle();

    final hands = <String, Hand>{};
    for (final pid in playerIds) {
      hands[pid] = Hand(deck.drawMultiple(cardsThisRound));
    }

    // Bidding starts left of dealer.
    final firstBidder = playerIds[(dealerIndex + 1) % playerIds.length];

    return OhHellState(
      phase: GamePhase.bidding,
      currentPlayerId: firstBidder,
      playerOrder: playerIds,
      dealerIndex: dealerIndex,
      hands: hands,
      cardsThisRound: cardsThisRound,
      roundSequenceIndex: roundSequenceIndex,
      totalRounds: totalRounds,
      roundSequence: roundSequence,
      bids: {},
      tricksWon: {for (final pid in playerIds) pid: 0},
      scores: scores,
      roundNumber: roundNumber,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  String? validateMove(OhHellState state, OhHellMove move) {
    if (state.currentPlayerId != move.playerId) return 'NOT_YOUR_TURN';

    return switch (move) {
      OhHellBidMove() => _validateBid(state, move),
      OhHellPlayCardMove() => _validatePlayCard(state, move),
    };
  }

  String? _validateBid(OhHellState state, OhHellBidMove move) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    if (move.bid < 0) return 'BID_TOO_LOW';
    if (move.bid > state.cardsThisRound) return 'BID_TOO_HIGH';

    // Forbidden bid: dealer cannot make total == cardsThisRound.
    final forbidden = state.forbiddenBidForDealer;
    if (forbidden >= 0 && move.bid == forbidden) return 'FORBIDDEN_BID';

    return null;
  }

  String? _validatePlayCard(OhHellState state, OhHellPlayCardMove move) {
    if (state.phase != GamePhase.playing) return 'NOT_PLAYING_PHASE';

    final hand = state.hands[move.playerId];
    if (hand == null) return 'NO_HAND';
    if (!hand.contains(move.card)) return 'CARD_NOT_IN_HAND';

    // Must follow lead suit when possible.
    if (state.currentTrick.isNotEmpty) {
      final leadSuit = state.currentTrick.first.suit;
      if (move.card.suit != leadSuit && hand.hasSuit(leadSuit)) {
        return 'MUST_FOLLOW_SUIT';
      }
    }
    return null;
  }

  // ── Valid moves ────────────────────────────────────────────────────────────

  @override
  List<OhHellMove> getValidMoves(OhHellState state, String playerId) {
    if (state.currentPlayerId != playerId) return [];

    switch (state.phase) {
      case GamePhase.bidding:
        final forbidden = state.forbiddenBidForDealer;
        return [
          for (var b = 0; b <= state.cardsThisRound; b++)
            if (b != forbidden) OhHellBidMove(playerId: playerId, bid: b),
        ];

      case GamePhase.playing:
        final hand = state.hands[playerId];
        if (hand == null) return [];
        return [
          for (final card in hand.cards)
            if (validateMove(
                    state, OhHellPlayCardMove(playerId: playerId, card: card)) ==
                null)
              OhHellPlayCardMove(playerId: playerId, card: card),
        ];

      default:
        return [];
    }
  }

  // ── Apply move ─────────────────────────────────────────────────────────────

  @override
  MoveResult<OhHellState> applyMove(OhHellState state, OhHellMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    return switch (move) {
      OhHellBidMove() => _applyBid(state, move),
      OhHellPlayCardMove() => _applyPlayCard(state, move),
    };
  }

  /// Starts the next round in the sequence — used after the human confirms
  /// the round-end overlay. Mirrors the server-side `applyNewRound` in
  /// `supabase/functions/_shared/game_rules/oh_hell.ts`.
  OhHellState applyNewRound(OhHellState state) {
    if (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameEnd) {
      return state;
    }
    final restarting = state.phase == GamePhase.gameEnd;
    final sequence = state.roundSequence ??
        OhHellConfig.roundSequence(state.playerOrder.length);
    final nextIndex = restarting ? 0 : state.roundSequenceIndex;
    final nextDealer = restarting
        ? state.dealerIndex
        : (state.dealerIndex + 1) % state.playerOrder.length;
    return _startRound(
      playerIds: state.playerOrder,
      dealerIndex: nextDealer,
      roundSequenceIndex: nextIndex,
      roundSequence: sequence,
      totalRounds: state.totalRounds,
      scores: restarting
          ? {for (final pid in state.playerOrder) pid: 0}
          : state.scores,
      roundNumber: restarting ? 1 : state.roundNumber,
    ).copyWith(
      roundHistory: restarting ? const [] : state.roundHistory,
      socialMode: state.socialMode,
    );
  }

  MoveResult<OhHellState> _applyBid(
      OhHellState state, OhHellBidMove move) {
    final newBids = Map<String, int>.from(state.bids)
      ..[move.playerId] = move.bid;

    // All players have bid → transition to playing.
    if (newBids.length == state.playerOrder.length) {
      // First player after dealer leads.
      final firstLeader =
          state.playerOrder[(state.dealerIndex + 1) % state.playerOrder.length];
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.playing,
          bids: newBids,
          currentPlayerId: firstLeader,
          turnNumber: state.turnNumber + 1,
        ),
        events: [
          GameEvent(
            type: GameEventType.bidPlaced,
            playerId: move.playerId,
            data: {'bid': move.bid, 'allBidsIn': true},
          ),
        ],
      );
    }

    return MoveResult.valid(
      newState: state.copyWith(
        bids: newBids,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: [
        GameEvent(
          type: GameEventType.bidPlaced,
          playerId: move.playerId,
          data: {'bid': move.bid},
        ),
      ],
    );
  }

  MoveResult<OhHellState> _applyPlayCard(
      OhHellState state, OhHellPlayCardMove move) {
    final newHands = Map<String, Hand>.from(state.hands);
    newHands[move.playerId] = state.hands[move.playerId]!.copy()
      ..remove(move.card);

    final seatIndex = state.playerOrder.indexOf(move.playerId);
    final newTrick = [
      ...state.currentTrick,
      TrickCard(playerId: move.playerId, card: move.card, seatIndex: seatIndex),
    ];

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.cardPlayed,
        playerId: move.playerId,
        data: {'card': move.card.toJson()},
      ),
    ];

    if (newTrick.length == state.playerOrder.length) {
      return _completeTrick(state, newTrick, newHands, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<OhHellState> _completeTrick(
    OhHellState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    List<GameEvent> events,
  ) {
    // Hearts are always trump.
    final leadSuit = trick.first.suit;
    final winnerId =
        _determineTrickWinner(trick, leadSuit, Suit.hearts);

    final newTricksWon = Map<String, int>.from(state.tricksWon);
    newTricksWon[winnerId] = (newTricksWon[winnerId] ?? 0) + 1;

    events.add(GameEvent(
      type: GameEventType.trickWon,
      playerId: winnerId,
      data: {'trick': trick.map((t) => t.toJson()).toList()},
    ));

    // Check if the round is over (all hands empty).
    final totalTricksPlayed =
        newTricksWon.values.fold<int>(0, (a, b) => a + b);
    if (totalTricksPlayed == state.cardsThisRound) {
      return _completeRound(state, hands, newTricksWon, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: hands,
        currentTrick: [],
        tricksWon: newTricksWon,
        currentPlayerId: winnerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<OhHellState> _completeRound(
    OhHellState state,
    Map<String, Hand> hands,
    Map<String, int> tricksWon,
    List<GameEvent> events,
  ) {
    final result = _scorer.scoreRound(
      playerOrder: state.playerOrder,
      bids: state.bids,
      tricksWon: tricksWon,
      cumulativeScores: state.scores,
    );

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'roundPoints': result.roundPoints,
        'scores': result.updatedScores,
      },
    ));

    final newHistory = [...state.roundHistory, result.roundPoints];

    // All rounds complete → game over.
    final nextIndex = state.roundSequenceIndex + 1;
    if (nextIndex >= state.totalRounds) {
      events.add(GameEvent(
        type: GameEventType.gameEnded,
        data: {'finalScores': result.updatedScores},
      ));
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.gameEnd,
          hands: hands,
          currentTrick: [],
          tricksWon: tricksWon,
          scores: result.updatedScores,
          roundHistory: newHistory,
          roundNumber: state.roundNumber + 1,
          turnNumber: state.turnNumber + 1,
        ),
        events: events,
      );
    }

    // Pause in roundEnd until a newRound move is dispatched. Keep the
    // hands/tricksWon/currentTrick from the round that just finished so
    // the scoreboard can show the final state until the human confirms.
    return MoveResult.valid(
      newState: state.copyWith(
        phase: GamePhase.roundEnd,
        hands: hands,
        currentTrick: [],
        tricksWon: tricksWon,
        scores: result.updatedScores,
        roundHistory: newHistory,
        roundSequenceIndex: nextIndex,
        roundNumber: state.roundNumber + 1,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  // ── Trick-winner determination ─────────────────────────────────────────────

  String _determineTrickWinner(
      List<TrickCard> trick, Suit leadSuit, Suit trumpSuit) {
    TrickCard? winner;
    for (final tc in trick) {
      if (winner == null) {
        winner = tc;
        continue;
      }
      final cur = tc.card;
      final win = winner.card;

      final curTrump = cur.suit == trumpSuit;
      final winTrump = win.suit == trumpSuit;

      if (curTrump && !winTrump) {
        winner = tc;
      } else if (!curTrump && winTrump) {
        // keep winner
      } else if (curTrump && winTrump) {
        if (cur.rank.index > win.rank.index) winner = tc;
      } else {
        // Neither trump; only lead-suit can win.
        if (cur.suit == leadSuit) {
          if (win.suit != leadSuit || cur.rank.index > win.rank.index) {
            winner = tc;
          }
        }
      }
    }
    return winner!.playerId;
  }

  // ── Game-end queries ───────────────────────────────────────────────────────

  @override
  bool isGameOver(OhHellState state) => state.isGameOver;

  @override
  List<String> getWinners(OhHellState state) {
    if (!isGameOver(state)) return [];
    final maxScore =
        state.scores.values.fold<int>(0, (a, b) => a > b ? a : b);
    return state.scores.entries
        .where((e) => e.value == maxScore)
        .map((e) => e.key)
        .toList();
  }

  @override
  Map<String, int> calculateScores(OhHellState state) =>
      Map.from(state.scores);

  @override
  String? getNextPlayer(OhHellState state, List<String> playerIds) =>
      state.currentPlayerId;
}
