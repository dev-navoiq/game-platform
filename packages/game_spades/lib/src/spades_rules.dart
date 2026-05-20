import 'package:game_core/game_core.dart';

import 'spades_config.dart';
import 'spades_move.dart';
import 'spades_scoring.dart';
import 'spades_state.dart';

/// Rules engine for Spades.
///
/// 4-player, 2v2 trick-taking game. Spades always trump.
/// Teams bid the number of tricks they expect to win.
/// Overtricks count as bags; 10 bags = -100 penalty.
/// Nil bid: 0 tricks = +100; missed = -100.
/// Game ends when a team reaches 500 points.
class SpadesRules extends GameRules<SpadesState, SpadesMove> {
  final SpadesScorer _scorer;
  Map<String, dynamic> _serverConfig = {};

  SpadesRules() : _scorer = const SpadesScorer();

  @override
  int get minPlayers => SpadesConfig.playerCount;

  @override
  int get maxPlayers => SpadesConfig.playerCount;

  @override
  List<int> get validPlayerCounts => const [4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  @override
  SpadesState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) applyServerConfig(serverConfig);
    return _startRound(
      playerIds: playerIds,
      dealerIndex: dealerIndex,
      teamScores: const {0: 0, 1: 0},
      teamBags: const {0: 0, 1: 0},
      roundNumber: 1,
    );
  }

  SpadesState _startRound({
    required List<String> playerIds,
    required int dealerIndex,
    required Map<int, int> teamScores,
    required Map<int, int> teamBags,
    required int roundNumber,
  }) {
    final deck = Deck.standard52();
    deck.shuffle();

    final hands = <String, Hand>{};
    for (final pid in playerIds) {
      hands[pid] = Hand(deck.drawMultiple(13));
    }

    // Bidding starts left of dealer.
    final firstBidder = playerIds[(dealerIndex + 1) % playerIds.length];

    return SpadesState(
      phase: GamePhase.bidding,
      currentPlayerId: firstBidder,
      playerOrder: playerIds,
      dealerIndex: dealerIndex,
      hands: hands,
      bids: {},
      isNilBid: {},
      playerTricksWon: {for (final pid in playerIds) pid: 0},
      teamTricksWon: const {0: 0, 1: 0},
      teamBags: teamBags,
      teamScores: teamScores,
      roundNumber: roundNumber,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  String? validateMove(SpadesState state, SpadesMove move) {
    if (state.currentPlayerId != move.playerId) return 'NOT_YOUR_TURN';

    return switch (move) {
      SpadesBidMove() => _validateBid(state, move),
      SpadesPlayCardMove() => _validatePlayCard(state, move),
    };
  }

  String? _validateBid(SpadesState state, SpadesBidMove move) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    if (move.isNil && move.bid != 0) return 'NIL_BID_MUST_BE_ZERO';
    if (!move.isNil && (move.bid < 1 || move.bid > 13)) return 'BID_OUT_OF_RANGE';
    if (state.bids.containsKey(move.playerId)) return 'ALREADY_BID';
    return null;
  }

  String? _validatePlayCard(SpadesState state, SpadesPlayCardMove move) {
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

    // Cannot lead spades until broken (unless only spades remain).
    if (state.currentTrick.isEmpty &&
        move.card.suit == Suit.spades &&
        !state.spadesBroken) {
      if (hand.cards.any((c) => c.suit != Suit.spades)) {
        return 'SPADES_NOT_BROKEN';
      }
    }

    return null;
  }

  // ── Valid moves ────────────────────────────────────────────────────────────

  @override
  List<SpadesMove> getValidMoves(SpadesState state, String playerId) {
    if (state.currentPlayerId != playerId) return [];

    switch (state.phase) {
      case GamePhase.bidding:
        return [
          SpadesBidMove(playerId: playerId, bid: 0, isNil: true),
          for (var b = 1; b <= 13; b++)
            SpadesBidMove(playerId: playerId, bid: b),
        ];

      case GamePhase.playing:
        final hand = state.hands[playerId];
        if (hand == null) return [];
        return [
          for (final card in hand.cards)
            if (validateMove(
                    state,
                    SpadesPlayCardMove(
                        playerId: playerId, card: card)) ==
                null)
              SpadesPlayCardMove(playerId: playerId, card: card),
        ];

      default:
        return [];
    }
  }

  // ── Apply move ─────────────────────────────────────────────────────────────

  @override
  MoveResult<SpadesState> applyMove(SpadesState state, SpadesMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    return switch (move) {
      SpadesBidMove() => _applyBid(state, move),
      SpadesPlayCardMove() => _applyPlayCard(state, move),
    };
  }

  MoveResult<SpadesState> _applyBid(SpadesState state, SpadesBidMove move) {
    final newBids = Map<String, int>.from(state.bids)
      ..[move.playerId] = move.bid;
    final newIsNil = Map<String, bool>.from(state.isNilBid)
      ..[move.playerId] = move.isNil;

    // All players have bid → start play.
    if (newBids.length == state.playerOrder.length) {
      final firstLeader =
          state.playerOrder[(state.dealerIndex + 1) % state.playerOrder.length];
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.playing,
          bids: newBids,
          isNilBid: newIsNil,
          currentPlayerId: firstLeader,
          turnNumber: state.turnNumber + 1,
        ),
      );
    }

    return MoveResult.valid(
      newState: state.copyWith(
        bids: newBids,
        isNilBid: newIsNil,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
    );
  }

  MoveResult<SpadesState> _applyPlayCard(
      SpadesState state, SpadesPlayCardMove move) {
    final newHands = Map<String, Hand>.from(state.hands);
    newHands[move.playerId] = state.hands[move.playerId]!.copy()
      ..remove(move.card);

    final seatIndex = state.playerOrder.indexOf(move.playerId);
    final newTrick = [
      ...state.currentTrick,
      TrickCard(
          playerId: move.playerId, card: move.card, seatIndex: seatIndex),
    ];

    final newSpadesBroken =
        state.spadesBroken || move.card.suit == Suit.spades;

    if (newTrick.length == state.playerOrder.length) {
      return _completeTrick(state, newTrick, newHands, newSpadesBroken);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        spadesBroken: newSpadesBroken,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
    );
  }

  MoveResult<SpadesState> _completeTrick(
    SpadesState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    bool spadesBroken,
  ) {
    final leadSuit = trick.first.suit;
    final winnerId = _determineTrickWinner(trick, leadSuit, Suit.spades);
    final winnerTeam = state.teamForPlayer(winnerId);

    final newPlayerTricks = Map<String, int>.from(state.playerTricksWon);
    newPlayerTricks[winnerId] = (newPlayerTricks[winnerId] ?? 0) + 1;

    final newTeamTricks = Map<int, int>.from(state.teamTricksWon);
    newTeamTricks[winnerTeam] = (newTeamTricks[winnerTeam] ?? 0) + 1;

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.trickWon,
        playerId: winnerId,
        data: {'team': winnerTeam},
      ),
    ];

    // Hand ends when all 13 tricks played.
    final totalTricks =
        newTeamTricks.values.fold<int>(0, (a, b) => a + b);
    if (totalTricks == SpadesConfig.cardsPerPlayer) {
      return _completeRound(
          state, hands, newPlayerTricks, newTeamTricks, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: hands,
        currentTrick: [],
        playerTricksWon: newPlayerTricks,
        teamTricksWon: newTeamTricks,
        spadesBroken: spadesBroken,
        currentPlayerId: winnerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<SpadesState> _completeRound(
    SpadesState state,
    Map<String, Hand> hands,
    Map<String, int> playerTricksWon,
    Map<int, int> teamTricksWon,
    List<GameEvent> events,
  ) {
    final result = _scorer.scoreRound(
      playerOrder: state.playerOrder,
      bids: state.bids,
      isNilBid: state.isNilBid,
      playerTricksWon: playerTricksWon,
      teamTricksWon: teamTricksWon,
      currentScores: state.teamScores,
      currentBags: state.teamBags,
    );

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'roundPoints': result.roundPoints,
        'scores': result.updatedScores,
      },
    ));

    // Game ends when a team reaches 500.
    final gameOver = result.updatedScores.values
        .any((s) => s >= SpadesConfig.gameOverScore);

    if (gameOver) {
      events.add(GameEvent(
        type: GameEventType.gameEnded,
        data: {'finalScores': result.updatedScores},
      ));
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.gameEnd,
          hands: hands,
          currentTrick: [],
          playerTricksWon: playerTricksWon,
          teamTricksWon: teamTricksWon,
          teamScores: result.updatedScores,
          teamBags: result.updatedBags,
          roundNumber: state.roundNumber + 1,
          turnNumber: state.turnNumber + 1,
        ),
        events: events,
      );
    }

    // Next round with rotated dealer.
    final nextDealer =
        (state.dealerIndex + 1) % state.playerOrder.length;
    final nextState = _startRound(
      playerIds: state.playerOrder,
      dealerIndex: nextDealer,
      teamScores: result.updatedScores,
      teamBags: result.updatedBags,
      roundNumber: state.roundNumber + 1,
    );

    return MoveResult.valid(
      newState: nextState.copyWith(
        phase: GamePhase.roundEnd,
        socialMode: state.socialMode,
      ),
      events: events,
    );
  }

  // ── Trick winner ───────────────────────────────────────────────────────────

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
  bool isGameOver(SpadesState state) => state.isGameOver;

  @override
  List<String> getWinners(SpadesState state) {
    if (!isGameOver(state)) return [];
    final maxScore =
        state.teamScores.values.fold<int>(0, (a, b) => a > b ? a : b);
    final winningTeam = state.teamScores.entries
        .firstWhere((e) => e.value == maxScore)
        .key;
    return [
      state.playerOrder[winningTeam],
      state.playerOrder[winningTeam + 2],
    ];
  }

  @override
  Map<String, int> calculateScores(SpadesState state) {
    return {
      for (final pid in state.playerOrder)
        pid: state.teamScores[state.teamForPlayer(pid)] ?? 0,
    };
  }

  @override
  String? getNextPlayer(SpadesState state, List<String> playerIds) =>
      state.currentPlayerId;
}
