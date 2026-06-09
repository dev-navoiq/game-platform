import 'package:game_core/game_core.dart';

import 'bridge_config.dart';
import 'bridge_move.dart';
import 'bridge_scoring.dart';
import 'bridge_state.dart';

/// Contract Bridge rules engine.
///
/// Implements:
///  * 13-card deal to 4 players (NS vs EW partnerships)
///  * Auction with bid/pass/double/redouble, terminating after 3 passes
///    following any bid (4 passes from the start = passed out)
///  * Declarer = first partner of the winning side to name the final
///    denomination
///  * Dummy hand revealed after the opening lead; declarer plays dummy's cards
///  * 13-trick play with must-follow-suit; highest trump (or highest lead suit
///    if no trump played) wins the trick
///  * Duplicate-style scoring including doubled/redoubled, vulnerability,
///    slam bonuses, and laddered undertrick penalties
///  * Chicago format (4 deals/session) with rotating vulnerability
class BridgeRules extends GameRules<BridgeState, BridgeMove> {
  final BridgeScorer _scorer;
  Map<String, dynamic> _serverConfig = {};

  BridgeRules() : _scorer = const BridgeScorer();

  @override
  int get minPlayers => BridgeConfig.minPlayers;

  @override
  int get maxPlayers => BridgeConfig.maxPlayers;

  @override
  List<int> get validPlayerCounts => const [4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  @override
  BridgeState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) applyServerConfig(serverConfig);
    if (playerIds.length != 4) {
      throw ArgumentError('Bridge requires exactly 4 players');
    }
    final totalDeals =
        (_serverConfig['totalDeals'] as int?) ?? BridgeConfig.totalDeals;
    return _startDeal(
      playerIds: playerIds,
      dealerIndex: dealerIndex,
      dealNumber: 1,
      scores: const {'NS': 0, 'EW': 0},
      dealHistory: const [],
      totalDeals: totalDeals,
    );
  }

  BridgeState _startDeal({
    required List<String> playerIds,
    required int dealerIndex,
    required int dealNumber,
    required Map<String, int> scores,
    required List<BridgeDealResult> dealHistory,
    required int totalDeals,
    RoomSocialMode socialMode = RoomSocialMode.full,
  }) {
    final deck = Deck.standard52();
    deck.shuffle();
    final hands = <String, Hand>{};
    for (final pid in playerIds) {
      hands[pid] = Hand(deck.drawMultiple(BridgeConfig.handSize));
    }

    return BridgeState(
      phase: GamePhase.bidding,
      currentPlayerId: playerIds[dealerIndex],
      playerOrder: playerIds,
      dealerIndex: dealerIndex,
      hands: hands,
      dealNumber: dealNumber,
      vulnerability: BridgeConfig.vulnerabilityForDeal(dealNumber),
      auctionHistory: const [],
      tricksWon: const {'NS': 0, 'EW': 0},
      scores: scores,
      dealHistory: dealHistory,
      totalDeals: totalDeals,
      socialMode: socialMode,
      roundNumber: dealNumber,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  String? validateMove(BridgeState state, BridgeMove move) {
    if (move is BridgeNewDealMove) {
      if (state.phase != GamePhase.roundEnd &&
          state.phase != GamePhase.gameEnd) {
        return 'NOT_ROUND_END';
      }
      return null;
    }

    final seatId = state.currentPlayerId;
    if (seatId == null) return 'NO_CURRENT_PLAYER';

    final isPlayPhase = state.phase == GamePhase.playing;
    final isDummyTurn = isPlayPhase && seatId == state.dummyId;
    final isAuthorized = move.playerId == seatId ||
        (isDummyTurn && move.playerId == state.declarerId);
    if (!isAuthorized) return 'NOT_YOUR_TURN';

    if (move is BridgePlayCardMove) {
      return _validatePlayCard(state, move, seatId);
    }
    if (state.phase != GamePhase.bidding) return 'WRONG_PHASE';

    if (move is BridgeBidMove) return _validateBid(state, move);
    if (move is BridgePassMove) return null;
    if (move is BridgeDoubleMove) {
      final seatIndex = state.playerOrder.indexOf(move.playerId);
      return _canDouble(state.auctionHistory, seatIndex);
    }
    if (move is BridgeRedoubleMove) {
      final seatIndex = state.playerOrder.indexOf(move.playerId);
      return _canRedouble(state.auctionHistory, seatIndex);
    }
    return 'UNKNOWN_MOVE';
  }

  String? _validateBid(BridgeState state, BridgeBidMove move) {
    if (move.level < 1 || move.level > 7) return 'BID_OUT_OF_RANGE';

    final lastBid = _lastBid(state.auctionHistory);
    if (lastBid == null) return null;
    if (move.level < lastBid.level!) return 'BID_TOO_LOW';
    if (move.level == lastBid.level! &&
        move.denomination.index <= lastBid.denomination!.index) {
      return 'BID_TOO_LOW';
    }
    return null;
  }

  String? _validatePlayCard(
      BridgeState state, BridgePlayCardMove move, String seatId) {
    if (state.phase != GamePhase.playing) return 'NOT_PLAYING_PHASE';

    final hand = state.hands[seatId];
    if (hand == null) return 'NO_HAND';
    if (!hand.contains(move.card)) return 'CARD_NOT_IN_HAND';

    if (state.currentTrick.isNotEmpty) {
      final leadSuit = state.currentTrick.first.suit;
      if (move.card.suit != leadSuit && hand.hasSuit(leadSuit)) {
        return 'MUST_FOLLOW_SUIT';
      }
    }
    return null;
  }

  String? _canDouble(List<AuctionCall> history, int currentSeat) {
    for (final c in history.reversed) {
      if (c.isPass) continue;
      if (c.isDouble || c.isRedouble) return 'ALREADY_DOUBLED';
      if (c.isBid) {
        // The bid must have come from an opponent (different parity).
        if (c.seatIndex % 2 == currentSeat % 2) return 'CANNOT_DOUBLE_PARTNER';
        return null;
      }
    }
    return 'NO_BID_TO_DOUBLE';
  }

  String? _canRedouble(List<AuctionCall> history, int currentSeat) {
    for (final c in history.reversed) {
      if (c.isPass) continue;
      if (c.isRedouble) return 'ALREADY_REDOUBLED';
      if (c.isBid) return 'NOT_DOUBLED';
      if (c.isDouble) {
        if (c.seatIndex % 2 == currentSeat % 2) return 'CANNOT_REDOUBLE_OWN';
        return null;
      }
    }
    return 'NO_BID_TO_REDOUBLE';
  }

  // ── Valid moves ────────────────────────────────────────────────────────────

  @override
  List<BridgeMove> getValidMoves(BridgeState state, String playerId) {
    final seatId = state.currentPlayerId;
    if (seatId == null) return const [];

    final canActAsDummy = state.phase == GamePhase.playing &&
        seatId == state.dummyId &&
        playerId == state.declarerId;

    switch (state.phase) {
      case GamePhase.bidding:
        if (playerId != seatId) return const [];
        return _legalBids(state, playerId);

      case GamePhase.playing:
        if (playerId != seatId && !canActAsDummy) return const [];
        final hand = state.hands[seatId];
        if (hand == null) return const [];
        return [
          for (final card in hand.cards)
            if (_validatePlayCard(state,
                    BridgePlayCardMove(playerId: playerId, card: card), seatId) ==
                null)
              BridgePlayCardMove(playerId: playerId, card: card),
        ];

      default:
        return const [];
    }
  }

  List<BridgeMove> _legalBids(BridgeState state, String playerId) {
    final seatIndex = state.playerOrder.indexOf(playerId);
    final moves = <BridgeMove>[BridgePassMove(playerId: playerId)];

    final lastBid = _lastBid(state.auctionHistory);
    for (var level = 1; level <= 7; level++) {
      for (final denom in BridgeDenomination.values) {
        if (lastBid == null) {
          moves.add(BridgeBidMove(
              playerId: playerId, level: level, denomination: denom));
          continue;
        }
        if (level > lastBid.level! ||
            (level == lastBid.level! &&
                denom.index > lastBid.denomination!.index)) {
          moves.add(BridgeBidMove(
              playerId: playerId, level: level, denomination: denom));
        }
      }
    }

    if (_canDouble(state.auctionHistory, seatIndex) == null) {
      moves.add(BridgeDoubleMove(playerId: playerId));
    }
    if (_canRedouble(state.auctionHistory, seatIndex) == null) {
      moves.add(BridgeRedoubleMove(playerId: playerId));
    }
    return moves;
  }

  // ── Apply ──────────────────────────────────────────────────────────────────

  @override
  MoveResult<BridgeState> applyMove(BridgeState state, BridgeMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    if (move is BridgeNewDealMove) {
      return MoveResult.valid(newState: applyNewDeal(state));
    }
    if (move is BridgePlayCardMove) return _applyPlayCard(state, move);
    if (move is BridgeBidMove) return _applyAuctionCall(state, move);
    if (move is BridgePassMove) return _applyAuctionCall(state, move);
    if (move is BridgeDoubleMove) return _applyAuctionCall(state, move);
    if (move is BridgeRedoubleMove) return _applyAuctionCall(state, move);
    return MoveResult.invalid(error: 'UNKNOWN_MOVE');
  }

  // ── Auction transitions ────────────────────────────────────────────────────

  MoveResult<BridgeState> _applyAuctionCall(
      BridgeState state, BridgeMove move) {
    final seatIndex = state.playerOrder.indexOf(state.currentPlayerId!);
    final call = _toAuctionCall(move, seatIndex);
    final newHistory = [...state.auctionHistory, call];

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.bidPlaced,
        playerId: move.playerId,
        data: call.toJson(),
      ),
    ];

    if (_isAuctionOver(newHistory)) {
      return _settleAuction(state, newHistory, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        auctionHistory: newHistory,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  AuctionCall _toAuctionCall(BridgeMove move, int seatIndex) {
    if (move is BridgeBidMove) {
      return AuctionCall(
        playerId: move.playerId,
        seatIndex: seatIndex,
        type: 'bid',
        level: move.level,
        denomination: move.denomination,
      );
    }
    if (move is BridgePassMove) {
      return AuctionCall(
          playerId: move.playerId, seatIndex: seatIndex, type: 'pass');
    }
    if (move is BridgeDoubleMove) {
      return AuctionCall(
          playerId: move.playerId, seatIndex: seatIndex, type: 'double');
    }
    if (move is BridgeRedoubleMove) {
      return AuctionCall(
          playerId: move.playerId, seatIndex: seatIndex, type: 'redouble');
    }
    throw StateError('Not an auction move: $move');
  }

  bool _isAuctionOver(List<AuctionCall> history) {
    if (history.isEmpty) return false;
    final lastNonPass = history.lastIndexWhere((c) => !c.isPass);
    if (lastNonPass == -1) return history.length >= 4; // passed out
    final trailingPasses = history.length - 1 - lastNonPass;
    return trailingPasses >= 3;
  }

  bool _isPassedOut(List<AuctionCall> history) =>
      history.length >= 4 && history.every((c) => c.isPass);

  MoveResult<BridgeState> _settleAuction(
    BridgeState state,
    List<AuctionCall> history,
    List<GameEvent> events,
  ) {
    if (_isPassedOut(history)) {
      // Passed-out deal — score 0 and move to round end.
      return _finishDeal(
        state.copyWith(
          auctionHistory: history,
          turnNumber: state.turnNumber + 1,
        ),
        contract: null,
        declarerTricks: 0,
        events: events,
      );
    }

    final lastBid = _lastBid(history)!;
    final doubleStatus = _currentDoubleStatus(history);
    final declarerCall =
        _findDeclarerCall(history, lastBid.denomination!, lastBid.seatIndex);
    final declarerSeat = declarerCall.seatIndex;
    final declarerId = declarerCall.playerId;
    final dummySeat = (declarerSeat + 2) % 4;
    final dummyId = state.playerOrder[dummySeat];
    final openingLeaderSeat = (declarerSeat + 1) % 4;

    final contract = BridgeContract(
      level: lastBid.level!,
      denomination: lastBid.denomination!,
      doubleStatus: doubleStatus,
      declarerId: declarerId,
      declarerSeat: declarerSeat,
    );

    events.add(GameEvent(
      type: GameEventType.bidWon,
      playerId: declarerId,
      data: {
        'contract': contract.toJson(),
        'dummyId': dummyId,
      },
    ));

    return MoveResult.valid(
      newState: state.copyWith(
        phase: GamePhase.playing,
        auctionHistory: history,
        contract: contract,
        dummyId: dummyId,
        currentPlayerId: state.playerOrder[openingLeaderSeat],
        currentTrick: const [],
        tricksWon: const {'NS': 0, 'EW': 0},
        trickNumber: 0,
        dummyRevealed: false,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  AuctionCall? _lastBid(List<AuctionCall> history) {
    for (final c in history.reversed) {
      if (c.isBid) return c;
    }
    return null;
  }

  BridgeDoubleStatus _currentDoubleStatus(List<AuctionCall> history) {
    for (final c in history.reversed) {
      if (c.isPass) continue;
      if (c.isRedouble) return BridgeDoubleStatus.redoubled;
      if (c.isDouble) return BridgeDoubleStatus.doubled;
      if (c.isBid) return BridgeDoubleStatus.undoubled;
    }
    return BridgeDoubleStatus.undoubled;
  }

  /// First partner of the winning side to name [denomination].
  AuctionCall _findDeclarerCall(
      List<AuctionCall> history, BridgeDenomination denomination, int winningSeat) {
    final winningParity = winningSeat % 2;
    for (final c in history) {
      if (!c.isBid) continue;
      if (c.seatIndex % 2 != winningParity) continue;
      if (c.denomination == denomination) return c;
    }
    // Shouldn't happen — the contract bid itself is in history.
    throw StateError('Could not find declarer');
  }

  // ── Card play ──────────────────────────────────────────────────────────────

  MoveResult<BridgeState> _applyPlayCard(
      BridgeState state, BridgePlayCardMove move) {
    final seatId = state.currentPlayerId!;
    final newHands = Map<String, Hand>.from(state.hands);
    newHands[seatId] = state.hands[seatId]!.copy()..remove(move.card);

    final seatIndex = state.playerOrder.indexOf(seatId);
    final newTrick = [
      ...state.currentTrick,
      TrickCard(playerId: seatId, card: move.card, seatIndex: seatIndex),
    ];

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.cardPlayed,
        playerId: seatId,
        data: {'card': move.card.toJson()},
      ),
    ];

    // Opening lead reveals dummy.
    final justRevealedDummy =
        !state.dummyRevealed && state.trickNumber == 0 && newTrick.length == 1;
    if (justRevealedDummy) {
      events.add(GameEvent(
        type: GameEventType.cardsDealt,
        playerId: state.dummyId,
        data: {'dummyRevealed': true},
      ));
    }

    if (newTrick.length == 4) {
      return _completeTrick(
        state,
        newTrick,
        newHands,
        events,
        revealDummy: justRevealedDummy,
      );
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        currentPlayerId: state.nextPlayerId,
        dummyRevealed: state.dummyRevealed || justRevealedDummy,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<BridgeState> _completeTrick(
    BridgeState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    List<GameEvent> events, {
    bool revealDummy = false,
  }) {
    final leadSuit = trick.first.suit;
    final trumpSuit = state.contract?.denomination.suit;
    final winner = _determineTrickWinner(trick, leadSuit, trumpSuit);
    final winnerSeat = state.playerOrder.indexOf(winner.playerId);
    final winnerTeam = BridgeConfig.teamForSeat(winnerSeat);

    final newTricksWon = Map<String, int>.from(state.tricksWon);
    newTricksWon[winnerTeam] = (newTricksWon[winnerTeam] ?? 0) + 1;

    events.add(GameEvent(
      type: GameEventType.trickWon,
      playerId: winner.playerId,
      data: {
        'trick': trick.map((t) => t.toJson()).toList(),
        'team': winnerTeam,
      },
    ));

    final newTrickNumber = state.trickNumber + 1;
    if (newTrickNumber >= BridgeConfig.totalTricks) {
      return _finishDeal(
        state.copyWith(
          hands: hands,
          currentTrick: const [],
          tricksWon: newTricksWon,
          trickNumber: newTrickNumber,
          dummyRevealed: state.dummyRevealed || revealDummy,
          turnNumber: state.turnNumber + 1,
        ),
        contract: state.contract,
        declarerTricks: newTricksWon[state.contract!.declarerTeam] ?? 0,
        events: events,
      );
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: hands,
        currentTrick: const [],
        tricksWon: newTricksWon,
        trickNumber: newTrickNumber,
        currentPlayerId: winner.playerId,
        dummyRevealed: state.dummyRevealed || revealDummy,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  TrickCard _determineTrickWinner(
      List<TrickCard> trick, Suit leadSuit, Suit? trumpSuit) {
    TrickCard winner = trick.first;
    for (var i = 1; i < trick.length; i++) {
      final tc = trick[i];
      final cur = tc.card;
      final win = winner.card;

      final curTrump = trumpSuit != null && cur.suit == trumpSuit;
      final winTrump = trumpSuit != null && win.suit == trumpSuit;

      if (curTrump && !winTrump) {
        winner = tc;
      } else if (!curTrump && winTrump) {
        // keep
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
    return winner;
  }

  // ── Deal completion ────────────────────────────────────────────────────────

  MoveResult<BridgeState> _finishDeal(
    BridgeState state, {
    required BridgeContract? contract,
    required int declarerTricks,
    required List<GameEvent> events,
  }) {
    final result = _scorer.scoreDeal(
      contract: contract,
      declarerTricks: declarerTricks,
      vulnerability: state.vulnerability,
    );

    final newScores = Map<String, int>.from(state.scores);
    newScores['NS'] = (newScores['NS'] ?? 0) + result.nsPoints;
    newScores['EW'] = (newScores['EW'] ?? 0) + result.ewPoints;

    final dealResult = BridgeDealResult(
      dealNumber: state.dealNumber,
      contract: contract,
      vulnerability: state.vulnerability,
      declarerTricks: result.declarerTricks,
      made: result.made,
      overtricks: result.overtricks,
      undertricks: result.undertricks,
      nsPoints: result.nsPoints,
      ewPoints: result.ewPoints,
    );
    final newHistory = [...state.dealHistory, dealResult];

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'dealResult': dealResult.toJson(),
        'scores': newScores,
      },
    ));

    final isLastDeal = state.dealNumber >= state.totalDeals;
    if (isLastDeal) {
      events.add(GameEvent(
        type: GameEventType.gameEnded,
        data: {'finalScores': newScores},
      ));
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.gameEnd,
          scores: newScores,
          dealHistory: newHistory,
          clearCurrentPlayer: true,
        ),
        events: events,
      );
    }

    return MoveResult.valid(
      newState: state.copyWith(
        phase: GamePhase.roundEnd,
        scores: newScores,
        dealHistory: newHistory,
        clearCurrentPlayer: true,
      ),
      events: events,
    );
  }

  /// Advance to the next deal after the round-end overlay confirms.
  BridgeState applyNewDeal(BridgeState state) {
    if (state.phase != GamePhase.roundEnd &&
        state.phase != GamePhase.gameEnd) {
      return state;
    }
    final restarting = state.phase == GamePhase.gameEnd;
    final nextDealNumber = restarting ? 1 : state.dealNumber + 1;
    final nextDealerIndex = restarting
        ? state.dealerIndex
        : (state.dealerIndex + 1) % state.playerOrder.length;

    return _startDeal(
      playerIds: state.playerOrder,
      dealerIndex: nextDealerIndex,
      dealNumber: nextDealNumber,
      scores: restarting ? const {'NS': 0, 'EW': 0} : state.scores,
      dealHistory: restarting ? const [] : state.dealHistory,
      totalDeals: state.totalDeals,
      socialMode: state.socialMode,
    );
  }

  // ── Game-end queries ───────────────────────────────────────────────────────

  @override
  bool isGameOver(BridgeState state) => state.isGameOver;

  @override
  List<String> getWinners(BridgeState state) {
    if (!isGameOver(state)) return const [];
    final ns = state.scores['NS'] ?? 0;
    final ew = state.scores['EW'] ?? 0;
    if (ns > ew) return BridgeConfig.seatsForTeam('NS')
        .map((i) => state.playerOrder[i])
        .toList();
    if (ew > ns) return BridgeConfig.seatsForTeam('EW')
        .map((i) => state.playerOrder[i])
        .toList();
    return [...state.playerOrder]; // tie
  }

  @override
  Map<String, int> calculateScores(BridgeState state) {
    // Expose per-player view by mapping each seat to its team's score.
    final result = <String, int>{};
    for (var i = 0; i < state.playerOrder.length; i++) {
      final team = BridgeConfig.teamForSeat(i);
      result[state.playerOrder[i]] = state.scores[team] ?? 0;
    }
    return result;
  }

  @override
  String? getNextPlayer(BridgeState state, List<String> playerIds) =>
      state.currentPlayerId;
}
