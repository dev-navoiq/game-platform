import 'package:game_core/game_core.dart';

import 'hearts_config.dart';
import 'hearts_move.dart';
import 'hearts_scoring.dart';
import 'hearts_state.dart';

/// Rules engine for Hearts.
///
/// 4-player trick-taking game. Goal: avoid scoring points.
/// Hearts = 1 pt each; Queen of Spades = 13 pts.
/// Shooting the moon: take all 26 → everyone else gets 26.
/// Game ends when any player reaches 100 points.
class HeartsRules extends GameRules<HeartsState, HeartsMove> {
  final HeartsScorer _scorer;
  Map<String, dynamic> _serverConfig = {};

  HeartsRules() : _scorer = const HeartsScorer();

  @override
  int get minPlayers => HeartsConfig.playerCount;

  @override
  int get maxPlayers => HeartsConfig.playerCount;

  @override
  List<int> get validPlayerCounts => const [4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  @override
  HeartsState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) applyServerConfig(serverConfig);
    return _startHand(
      playerIds: playerIds,
      scores: {for (final pid in playerIds) pid: 0},
      roundNumber: 1,
    );
  }

  HeartsState _startHand({
    required List<String> playerIds,
    required Map<String, int> scores,
    required int roundNumber,
  }) {
    final deck = Deck.standard52();
    deck.shuffle();

    final hands = <String, Hand>{};
    for (final pid in playerIds) {
      hands[pid] = Hand(deck.drawMultiple(13));
    }

    final direction = HeartsState.directionForRound(roundNumber);
    final phase = direction == PassDirection.keep
        ? GamePhase.playing
        : GamePhase.cardPassing;

    // Find player with 2♣ to lead first trick (only relevant after passing).
    String? firstPlayer;
    if (phase == GamePhase.playing) {
      firstPlayer = _findTwoOfClubs(playerIds, hands);
    }

    return HeartsState(
      phase: phase,
      currentPlayerId: firstPlayer,
      playerOrder: playerIds,
      hands: hands,
      scores: scores,
      handPoints: {for (final pid in playerIds) pid: 0},
      passDirection: direction,
      roundNumber: roundNumber,
    );
  }

  /// Find the player holding the Two of Clubs.
  String _findTwoOfClubs(List<String> playerIds, Map<String, Hand> hands) {
    const twoOfClubs = PlayingCard(Suit.clubs, Rank.two);
    for (final pid in playerIds) {
      if (hands[pid]?.contains(twoOfClubs) ?? false) return pid;
    }
    return playerIds[0]; // Fallback.
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  String? validateMove(HeartsState state, HeartsMove move) {
    if (state.phase == GamePhase.cardPassing) {
      if (move is! HeartsSelectPassMove) return 'WRONG_MOVE_TYPE';
      return _validateSelectPass(state, move);
    }

    if (state.currentPlayerId != move.playerId) return 'NOT_YOUR_TURN';

    return switch (move) {
      HeartsSelectPassMove() => 'WRONG_MOVE_TYPE',
      HeartsPlayCardMove() => _validatePlayCard(state, move),
    };
  }

  String? _validateSelectPass(
      HeartsState state, HeartsSelectPassMove move) {
    if (state.passSelections.containsKey(move.playerId)) {
      return 'ALREADY_SELECTED';
    }
    if (move.cards.length != 3) return 'MUST_PASS_THREE_CARDS';
    final hand = state.hands[move.playerId];
    if (hand == null) return 'NO_HAND';
    for (final card in move.cards) {
      if (!hand.contains(card)) return 'CARD_NOT_IN_HAND';
    }
    return null;
  }

  String? _validatePlayCard(HeartsState state, HeartsPlayCardMove move) {
    if (state.phase != GamePhase.playing) return 'NOT_PLAYING_PHASE';

    final hand = state.hands[move.playerId];
    if (hand == null) return 'NO_HAND';
    if (!hand.contains(move.card)) return 'CARD_NOT_IN_HAND';

    // First trick: must lead/follow 2♣ rules.
    if (state.turnNumber == 0 && state.currentTrick.isEmpty) {
      // Leader must play 2♣.
      final twoClubs = PlayingCard(Suit.clubs, Rank.two);
      if (move.card != twoClubs) return 'MUST_LEAD_TWO_OF_CLUBS';
    }

    // Must follow lead suit if possible.
    if (state.currentTrick.isNotEmpty) {
      final leadSuit = state.currentTrick.first.suit;
      if (move.card.suit != leadSuit && hand.hasSuit(leadSuit)) {
        return 'MUST_FOLLOW_SUIT';
      }
    }

    // Cannot lead hearts until broken (unless only hearts remain).
    if (state.currentTrick.isEmpty &&
        move.card.suit == Suit.hearts &&
        !state.heartsBroken) {
      if (hand.cards.any((c) => c.suit != Suit.hearts)) {
        return 'HEARTS_NOT_BROKEN';
      }
    }

    // Cannot play hearts or Q♠ on first trick.
    if (state.turnNumber < state.playerOrder.length) {
      if (move.card.suit == Suit.hearts) return 'NO_POINTS_ON_FIRST_TRICK';
      if (move.card.suit == Suit.spades && move.card.rank == Rank.queen) {
        return 'NO_POINTS_ON_FIRST_TRICK';
      }
    }

    return null;
  }

  // ── Valid moves ────────────────────────────────────────────────────────────

  @override
  List<HeartsMove> getValidMoves(HeartsState state, String playerId) {
    if (state.phase == GamePhase.cardPassing) {
      if (state.passSelections.containsKey(playerId)) return [];
      final hand = state.hands[playerId];
      if (hand == null) return [];
      // Player must select any 3 cards — return all individual playable cards
      // (the UI combines them into a HeartsSelectPassMove).
      return [
        for (final card in hand.cards)
          HeartsPlayCardMove(playerId: playerId, card: card),
      ];
    }

    if (state.currentPlayerId != playerId) return [];
    final hand = state.hands[playerId];
    if (hand == null) return [];

    return [
      for (final card in hand.cards)
        if (validateMove(
                state, HeartsPlayCardMove(playerId: playerId, card: card)) ==
            null)
          HeartsPlayCardMove(playerId: playerId, card: card),
    ];
  }

  // ── Apply move ─────────────────────────────────────────────────────────────

  @override
  MoveResult<HeartsState> applyMove(HeartsState state, HeartsMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    return switch (move) {
      HeartsSelectPassMove() => _applySelectPass(state, move),
      HeartsPlayCardMove() => _applyPlayCard(state, move),
    };
  }

  MoveResult<HeartsState> _applySelectPass(
      HeartsState state, HeartsSelectPassMove move) {
    final newSelections = Map<String, List<PlayingCard>>.from(state.passSelections)
      ..[move.playerId] = move.cards;

    // All players have selected → execute the pass.
    if (newSelections.length == state.playerOrder.length) {
      return _executePassing(state, newSelections);
    }

    return MoveResult.valid(
      newState: state.copyWith(passSelections: newSelections),
    );
  }

  MoveResult<HeartsState> _executePassing(
      HeartsState state,
      Map<String, List<PlayingCard>> selections) {
    final n = state.playerOrder.length;
    final offset = HeartsState.passOffset(state.passDirection, n);
    final newHands = {
      for (final pid in state.playerOrder) pid: state.hands[pid]!.copy(),
    };

    // Remove selected cards from each sender.
    for (final pid in state.playerOrder) {
      for (final card in selections[pid]!) {
        newHands[pid]!.remove(card);
      }
    }

    // Add received cards to each receiver.
    for (var i = 0; i < n; i++) {
      final sender = state.playerOrder[i];
      final receiver = state.playerOrder[(i + offset) % n];
      for (final card in selections[sender]!) {
        newHands[receiver]!.add(card);
      }
    }

    // Leader is whoever holds 2♣ now.
    final leader = _findTwoOfClubs(state.playerOrder, newHands);

    return MoveResult.valid(
      newState: state.copyWith(
        phase: GamePhase.playing,
        hands: newHands,
        currentPlayerId: leader,
        passSelections: {},
      ),
    );
  }

  MoveResult<HeartsState> _applyPlayCard(
      HeartsState state, HeartsPlayCardMove move) {
    final newHands = Map<String, Hand>.from(state.hands);
    newHands[move.playerId] = state.hands[move.playerId]!.copy()
      ..remove(move.card);

    final seatIndex = state.playerOrder.indexOf(move.playerId);
    final newTrick = [
      ...state.currentTrick,
      TrickCard(playerId: move.playerId, card: move.card, seatIndex: seatIndex),
    ];

    final newHeartsBroken =
        state.heartsBroken || move.card.suit == Suit.hearts;

    final events = <GameEvent>[
      GameEvent(
        type: GameEventType.cardPlayed,
        playerId: move.playerId,
        data: {'card': move.card.toJson()},
      ),
    ];

    if (newTrick.length == state.playerOrder.length) {
      return _completeTrick(state, newTrick, newHands, newHeartsBroken, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        heartsBroken: newHeartsBroken,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<HeartsState> _completeTrick(
    HeartsState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    bool heartsBroken,
    List<GameEvent> events,
  ) {
    final leadSuit = trick.first.suit;
    final winnerId = _determineTrickWinner(trick, leadSuit);

    // Count points in this trick.
    final trickPoints = HeartsScorer.countPoints(trick.map((t) => t.card).toList());

    final newHandPoints = Map<String, int>.from(state.handPoints);
    newHandPoints[winnerId] = (newHandPoints[winnerId] ?? 0) + trickPoints;

    events.add(GameEvent(
      type: GameEventType.trickWon,
      playerId: winnerId,
      data: {'points': trickPoints},
    ));

    // Hand ends when all 13 tricks are played.
    final totalTricks =
        hands.values.every((h) => h.size == 0);
    if (totalTricks) {
      return _completeHand(state, hands, newHandPoints, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: hands,
        currentTrick: [],
        handPoints: newHandPoints,
        heartsBroken: heartsBroken,
        currentPlayerId: winnerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  MoveResult<HeartsState> _completeHand(
    HeartsState state,
    Map<String, Hand> hands,
    Map<String, int> handPoints,
    List<GameEvent> events,
  ) {
    final result = _scorer.scoreHand(
      playerOrder: state.playerOrder,
      handPoints: handPoints,
      cumulativeScores: state.scores,
    );

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'handPoints': result.handPoints,
        'scores': result.updatedScores,
        'moonShooter': result.moonShooter,
      },
    ));

    // Game ends when any player reaches 100.
    final gameOver = result.updatedScores.values
        .any((s) => s >= HeartsConfig.gameOverScore);

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
          handPoints: result.handPoints,
          scores: result.updatedScores,
          roundNumber: state.roundNumber + 1,
          turnNumber: state.turnNumber + 1,
        ),
        events: events,
      );
    }

    // Start next hand.
    final nextHand = _startHand(
      playerIds: state.playerOrder,
      scores: result.updatedScores,
      roundNumber: state.roundNumber + 1,
    );

    return MoveResult.valid(
      newState: nextHand.copyWith(
        phase: GamePhase.roundEnd,
        socialMode: state.socialMode,
      ),
      events: events,
    );
  }

  // ── Trick winner ───────────────────────────────────────────────────────────

  String _determineTrickWinner(List<TrickCard> trick, Suit leadSuit) {
    TrickCard? winner;
    for (final tc in trick) {
      if (winner == null) {
        winner = tc;
        continue;
      }
      final cur = tc.card;
      final win = winner.card;
      // Only lead-suit cards can win; no trump in Hearts.
      if (cur.suit == leadSuit) {
        if (win.suit != leadSuit || cur.rank.index > win.rank.index) {
          winner = tc;
        }
      }
    }
    return winner!.playerId;
  }

  // ── Game-end queries ───────────────────────────────────────────────────────

  @override
  bool isGameOver(HeartsState state) => state.isGameOver;

  @override
  List<String> getWinners(HeartsState state) {
    if (!isGameOver(state)) return [];
    // Lowest score wins.
    final minScore =
        state.scores.values.fold<int>(999, (a, b) => a < b ? a : b);
    return state.scores.entries
        .where((e) => e.value == minScore)
        .map((e) => e.key)
        .toList();
  }

  @override
  Map<String, int> calculateScores(HeartsState state) =>
      Map.from(state.scores);

  @override
  String? getNextPlayer(HeartsState state, List<String> playerIds) =>
      state.currentPlayerId;
}
