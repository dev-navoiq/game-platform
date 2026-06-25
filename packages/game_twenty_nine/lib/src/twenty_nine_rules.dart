import 'package:game_core/game_core.dart';

import 'twenty_nine_config.dart';
import 'twenty_nine_move.dart';
import 'twenty_nine_scoring.dart';
import 'twenty_nine_state.dart';

/// Rules engine for Twenty-Nine.
///
/// Twenty-Nine is a 4-player, 2v2 trick-taking game played with a 32-card
/// deck. Players bid on how many card-points their team will win.
/// Trump is secretly chosen by the bid winner and revealed when needed.
class TwentyNineRules extends GameRules<TwentyNineState, TwentyNineMove> {
  final TwentyNineScorer _scorer;
  Map<String, dynamic> _serverConfig = {};

  TwentyNineRules() : _scorer = const TwentyNineScorer();

  @override
  int get minPlayers => 4;

  @override
  int get maxPlayers => 4;

  @override
  List<int> get validPlayerCounts => const [4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  @override
  TwentyNineState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    if (serverConfig != null) applyServerConfig(serverConfig);
    assert(playerIds.length == 4, 'Twenty-Nine requires exactly 4 players');

    final deck = Deck.standard32();
    deck.shuffle();

    // Classic 29: deal only the first 4 cards per player; the remaining 4
    // are dealt after trump is declared. The leftover 16 cards live on the
    // state so the engine can deal them at declareTrump time.
    final hands = <String, Hand>{};
    for (final pid in playerIds) {
      hands[pid] = Hand(deck.drawMultiple(4));
    }
    final pending = List<PlayingCard>.unmodifiable(
      List<PlayingCard>.from(deck.cards.reversed),
    );

    // First bidder is to the left of the dealer.
    final firstBidder = playerIds[(dealerIndex + 1) % 4];

    return TwentyNineState(
      phase: GamePhase.bidding,
      currentPlayerId: firstBidder,
      hands: hands,
      dealerIndex: dealerIndex,
      playerOrder: playerIds,
      pendingDeck: pending,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  String? validateMove(TwentyNineState state, TwentyNineMove move) {
    if (state.currentPlayerId != move.playerId) {
      return 'NOT_YOUR_TURN';
    }

    return switch (move) {
      BidMove() => _validateBid(state, move),
      PassMove() => _validatePass(state),
      DeclareTrumpMove() => _validateDeclareTrump(state, move),
      PlayCardMove() => _validatePlayCard(state, move),
      RevealTrumpMove() => _validateRevealTrump(state, move),
      DoubleMove() => _validateDouble(state, move),
      RedoubleMove() => _validateRedouble(state, move),
      ClaimRoyalWeddingMove() => _validateClaimRoyalWedding(state, move),
    };
  }

  String? _validateClaimRoyalWedding(
      TwentyNineState state, ClaimRoyalWeddingMove move) {
    if (state.phase != GamePhase.playing) return 'NOT_PLAYING_PHASE';
    if (state.trumpSuit == null) return 'NO_TRUMP_DECLARED';
    // Must be at the start of a trick — the claimant should be leading.
    if (state.currentTrick.isNotEmpty) return 'TRICK_IN_PROGRESS';

    final myTeam = state.teamForPlayer(move.playerId);
    if (state.royalWeddingClaimedByTeam.contains(myTeam)) {
      return 'TEAM_ALREADY_CLAIMED';
    }

    // Must have won at least one trick this round.
    if ((state.tricksWon[myTeam] ?? 0) < 1) {
      return 'NO_TRICK_WON_YET';
    }

    // Must hold both K and Q of trump.
    final hand = state.hands[move.playerId];
    if (hand == null) return 'NO_HAND';
    final trump = state.trumpSuit!;
    final hasK = hand.cards
        .any((c) => c.suit == trump && c.rank == Rank.king);
    final hasQ = hand.cards
        .any((c) => c.suit == trump && c.rank == Rank.queen);
    if (!hasK || !hasQ) return 'NO_KING_QUEEN_OF_TRUMP';

    // Bidder team can only claim if the bid was ≥ 20 (the rule that lets
    // them reduce the threshold). Defender team has no bid restriction.
    final bidderTeam = state.bidWinnerTeam;
    final isBidderTeam = bidderTeam == myTeam;
    if (isBidderTeam &&
        state.currentBid < TwentyNineConfig.highBidThreshold) {
      return 'BID_BELOW_HIGH_THRESHOLD';
    }

    return null;
  }

  String? _validateDouble(TwentyNineState state, DoubleMove move) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    if (state.bidderId == null) return 'NO_BID_TO_DOUBLE';
    if (state.doublingMultiplier != 1) return 'ALREADY_DOUBLED';
    // Only defenders (non-bidding team) may double.
    final bidTeam = state.teamForPlayer(state.bidderId!);
    if (state.teamForPlayer(move.playerId) == bidTeam) {
      return 'DOUBLE_MUST_BE_DEFENDER';
    }
    return null;
  }

  String? _validateRedouble(TwentyNineState state, RedoubleMove move) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    if (state.bidderId == null) return 'NO_BID_TO_REDOUBLE';
    if (state.doublingMultiplier != 2) return 'NOT_DOUBLED';
    if (state.redoubledBy != null) return 'ALREADY_REDOUBLED';
    // Only the bidding team may redouble.
    final bidTeam = state.teamForPlayer(state.bidderId!);
    if (state.teamForPlayer(move.playerId) != bidTeam) {
      return 'REDOUBLE_MUST_BE_BIDDER_TEAM';
    }
    return null;
  }

  String? _validateBid(TwentyNineState state, BidMove move) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    // Once doubled or redoubled, the bid value is locked.
    if (state.doublingMultiplier != 1) return 'CONTRACT_LOCKED';
    if (move.bidValue == TwentyNineConfig.specialBid) return null;
    if (move.bidValue < state.minimumBid) return 'BID_TOO_LOW';
    if (move.bidValue > TwentyNineConfig.maxBid) return 'BID_TOO_HIGH';
    return null;
  }

  String? _validatePass(TwentyNineState state) {
    if (state.phase != GamePhase.bidding) return 'NOT_BIDDING_PHASE';
    return null;
  }

  String? _validateDeclareTrump(
      TwentyNineState state, DeclareTrumpMove move) {
    if (state.phase != GamePhase.trumpSelection) {
      return 'NOT_TRUMP_SELECTION_PHASE';
    }
    // currentPlayerId is set to trumpSelector when phase changes.
    // The NOT_YOUR_TURN check above already ensures the player is the selector.
    final hand = state.hands[move.playerId];
    if (hand == null || !hand.hasSuit(move.suit)) return 'NO_CARDS_OF_SUIT';
    return null;
  }

  String? _validatePlayCard(TwentyNineState state, PlayCardMove move) {
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

    // Classic 29 rule: the player who called for trump to be revealed in the
    // current trick MUST play a trump card on this trick if they hold any.
    if (state.trumpRevealerThisTrick == move.playerId &&
        state.trumpSuit != null &&
        hand.hasSuit(state.trumpSuit!) &&
        move.card.suit != state.trumpSuit) {
      return 'MUST_PLAY_TRUMP';
    }

    return null;
  }

  String? _validateRevealTrump(TwentyNineState state, RevealTrumpMove move) {
    if (state.phase != GamePhase.playing) return 'NOT_PLAYING_PHASE';
    if (state.trumpRevealed) return 'TRUMP_ALREADY_REVEALED';
    if (state.trumpSuit == null) return 'NO_TRUMP_DECLARED';

    // Can only reveal if currently void in the lead suit.
    if (state.currentTrick.isNotEmpty) {
      final hand = state.hands[move.playerId];
      if (hand != null && hand.hasSuit(state.currentTrick.first.suit)) {
        return 'CAN_FOLLOW_SUIT';
      }
    }
    return null;
  }

  // ── Valid moves ────────────────────────────────────────────────────────────

  @override
  List<TwentyNineMove> getValidMoves(
      TwentyNineState state, String playerId) {
    if (state.currentPlayerId != playerId) return [];

    switch (state.phase) {
      case GamePhase.bidding:
        final moves = <TwentyNineMove>[PassMove(playerId: playerId)];
        // Once doubled/redoubled, further raises are not allowed.
        if (state.doublingMultiplier == 1) {
          for (var v = state.minimumBid; v <= TwentyNineConfig.maxBid; v++) {
            moves.add(BidMove(playerId: playerId, bidValue: v));
          }
          moves.add(BidMove(
              playerId: playerId, bidValue: TwentyNineConfig.specialBid));
        }
        // Double (defender) / Redouble (bidder team).
        if (state.bidderId != null) {
          final bidTeam = state.teamForPlayer(state.bidderId!);
          final myTeam = state.teamForPlayer(playerId);
          if (state.doublingMultiplier == 1 && myTeam != bidTeam) {
            moves.add(DoubleMove(playerId: playerId));
          }
          if (state.doublingMultiplier == 2 &&
              state.redoubledBy == null &&
              myTeam == bidTeam) {
            moves.add(RedoubleMove(playerId: playerId));
          }
        }
        return moves;

      case GamePhase.trumpSelection:
        if (state.trumpSelector != playerId) return [];
        final hand = state.hands[playerId]!;
        return Suit.values
            .where((s) => hand.hasSuit(s))
            .map((s) => DeclareTrumpMove(playerId: playerId, suit: s))
            .toList();

      case GamePhase.playing:
        final hand = state.hands[playerId];
        if (hand == null) return [];
        final moves = <TwentyNineMove>[];

        // Offer reveal trump if conditions met.
        if (!state.trumpRevealed &&
            state.trumpSuit != null &&
            state.currentTrick.isNotEmpty &&
            !(hand.hasSuit(state.currentTrick.first.suit))) {
          moves.add(RevealTrumpMove(playerId: playerId));
        }

        // Royal Wedding (K+Q of trump) — surfaced when the conditions are
        // currently met. The validator owns the full check; this just keeps
        // bots aware that the move is an option.
        if (_validateClaimRoyalWedding(
              state,
              ClaimRoyalWeddingMove(playerId: playerId),
            ) ==
            null) {
          moves.add(ClaimRoyalWeddingMove(playerId: playerId));
        }

        // All legally playable cards.
        for (final card in hand.cards) {
          if (validateMove(
                  state, PlayCardMove(playerId: playerId, card: card)) ==
              null) {
            moves.add(PlayCardMove(playerId: playerId, card: card));
          }
        }
        return moves;

      default:
        return [];
    }
  }

  // ── Apply move ─────────────────────────────────────────────────────────────

  @override
  MoveResult<TwentyNineState> applyMove(
      TwentyNineState state, TwentyNineMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    return switch (move) {
      BidMove() => _applyBid(state, move),
      PassMove() => _applyPass(state, move),
      DeclareTrumpMove() => _applyDeclareTrump(state, move),
      PlayCardMove() => _applyPlayCard(state, move),
      RevealTrumpMove() => _applyRevealTrump(state, move),
      DoubleMove() => _applyDouble(state, move),
      RedoubleMove() => _applyRedouble(state, move),
      ClaimRoyalWeddingMove() => _applyClaimRoyalWedding(state, move),
    };
  }

  MoveResult<TwentyNineState> _applyClaimRoyalWedding(
      TwentyNineState state, ClaimRoyalWeddingMove move) {
    final myTeam = state.teamForPlayer(move.playerId);
    final bidderTeam = state.bidWinnerTeam;
    final isBidderTeam = bidderTeam == myTeam;
    // Bidder claim → threshold reduced by 4 (easier to make).
    // Defender claim → threshold raised by 4 (harder for bidder).
    final delta = isBidderTeam
        ? -TwentyNineConfig.royalWeddingAdjustment
        : TwentyNineConfig.royalWeddingAdjustment;

    return MoveResult.valid(
      newState: state.copyWith(
        bidAdjustment: state.bidAdjustment + delta,
        royalWeddingClaimedByTeam: {
          ...state.royalWeddingClaimedByTeam,
          myTeam,
        },
        turnNumber: state.turnNumber + 1,
      ),
      events: [
        GameEvent(
          type: GameEventType.bidPlaced,
          playerId: move.playerId,
          data: {
            'action': 'royalWedding',
            'team': myTeam,
            'isBidderTeam': isBidderTeam,
            'delta': delta,
          },
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyDouble(
      TwentyNineState state, DoubleMove move) {
    // Treat like a pass in the bidding rotation but raise the multiplier.
    return MoveResult.valid(
      newState: state.copyWith(
        doublingMultiplier: 2,
        doubledBy: move.playerId,
        passCount: state.passCount + 1,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: [
        GameEvent(
          type: GameEventType.bidPlaced,
          playerId: move.playerId,
          data: {
            'action': 'double',
            'bidValue': state.currentBid,
            'multiplier': 2,
          },
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyRedouble(
      TwentyNineState state, RedoubleMove move) {
    return MoveResult.valid(
      newState: state.copyWith(
        doublingMultiplier: 4,
        redoubledBy: move.playerId,
        passCount: state.passCount + 1,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: [
        GameEvent(
          type: GameEventType.bidPlaced,
          playerId: move.playerId,
          data: {
            'action': 'redouble',
            'bidValue': state.currentBid,
            'multiplier': 4,
          },
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyBid(
      TwentyNineState state, BidMove move) {
    return MoveResult.valid(
      newState: state.copyWith(
        currentBid: move.bidValue,
        bidderId: move.playerId,
        passCount: 0,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
      events: [
        GameEvent(
          type: GameEventType.bidPlaced,
          playerId: move.playerId,
          data: {'bidValue': move.bidValue},
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyPass(
      TwentyNineState state, PassMove move) {
    final newPassCount = state.passCount + 1;

    // 3 passes after a bid → bidding over, move to trump selection.
    if (newPassCount >= 3 && state.bidderId != null) {
      final trumpSelector = state.bidderId!;
      return MoveResult.valid(
        newState: state.copyWith(
          phase: GamePhase.trumpSelection,
          passCount: newPassCount,
          currentPlayerId: trumpSelector,
          trumpSelector: trumpSelector,
          turnNumber: state.turnNumber + 1,
        ),
        events: [
          GameEvent(
            type: GameEventType.bidWon,
            playerId: state.bidderId,
            data: {'bidValue': state.currentBid},
          ),
        ],
      );
    }

    // 4 passes with no bid → dissolve this deal and re-deal fresh hands,
    // rotating the dealer. Build the new state directly to avoid copyWith
    // sentinel proliferation (bidderId, trumpSuit, etc. must clear to null).
    if (newPassCount >= 4 && state.bidderId == null) {
      final deck = Deck.standard32();
      deck.shuffle();
      final newHands = <String, Hand>{};
      for (final pid in state.playerOrder) {
        newHands[pid] = Hand(deck.drawMultiple(4));
      }
      final newPending = List<PlayingCard>.unmodifiable(
        List<PlayingCard>.from(deck.cards.reversed),
      );
      final newDealerIndex = (state.dealerIndex + 1) % 4;
      final firstBidder = state.playerOrder[(newDealerIndex + 1) % 4];

      return MoveResult.valid(
        newState: TwentyNineState(
          phase: GamePhase.bidding,
          currentPlayerId: firstBidder,
          turnNumber: state.turnNumber + 1,
          roundNumber: state.roundNumber,
          socialMode: state.socialMode,
          hands: newHands,
          currentTrick: const [],
          dealerIndex: newDealerIndex,
          playerOrder: state.playerOrder,
          sessionScores: state.sessionScores,
          redPips: state.redPips,
          blackPips: state.blackPips,
          pendingDeck: newPending,
        ),
        events: [
          GameEvent(
            type: GameEventType.handDissolved,
            data: const {'reason': 'allPassed'},
          ),
        ],
      );
    }

    // Continue bidding.
    return MoveResult.valid(
      newState: state.copyWith(
        passCount: newPassCount,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
      ),
    );
  }

  MoveResult<TwentyNineState> _applyDeclareTrump(
      TwentyNineState state, DeclareTrumpMove move) {
    // First to play is the player left of dealer.
    final firstPlayer = state.playerOrder[(state.dealerIndex + 1) % 4];

    // Second deal: 4 more cards per player from pendingDeck. Layout: cards
    // are drawn in playerOrder order, 4 cards each, exactly as the initial
    // deal would have produced if 8 had been dealt up-front.
    final newHands = <String, Hand>{};
    if (state.pendingDeck.length == state.playerOrder.length * 4) {
      var cursor = 0;
      for (final pid in state.playerOrder) {
        final existing = state.hands[pid]?.cards ?? const <PlayingCard>[];
        final extras = state.pendingDeck.sublist(cursor, cursor + 4);
        newHands[pid] = Hand([...existing, ...extras]);
        cursor += 4;
      }
    } else {
      // Defensive: if pendingDeck is empty (legacy state restored from JSON
      // before this change shipped), keep hands as-is. Playing phase will
      // simply have 4 cards which still works.
      newHands.addAll(state.hands);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        phase: GamePhase.playing,
        trumpSuit: move.suit,
        currentPlayerId: firstPlayer,
        turnNumber: state.turnNumber + 1,
        hands: newHands,
        pendingDeck: const [],
      ),
      events: [
        GameEvent(
          type: GameEventType.trumpRevealed,
          playerId: move.playerId,
          data: {'suit': move.suit.name, 'hidden': true},
        ),
      ],
    );
  }

  MoveResult<TwentyNineState> _applyPlayCard(
      TwentyNineState state, PlayCardMove move) {
    // Remove card from hand.
    final newHands = Map<String, Hand>.from(state.hands);
    final updatedHand = state.hands[move.playerId]!.copy()
      ..remove(move.card);
    newHands[move.playerId] = updatedHand;

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

    // Auto-reveal trump when a player plays a trump card while trump is
    // still face-down. The card itself publicly discloses the suit, so the
    // game state should reflect that without requiring a separate reveal tap.
    final autoRevealing = state.trumpSuit != null &&
        !state.trumpRevealed &&
        move.card.suit == state.trumpSuit;
    if (autoRevealing) {
      events.add(GameEvent(
        type: GameEventType.trumpRevealed,
        playerId: move.playerId,
        data: {'suit': state.trumpSuit!.name, 'hidden': false, 'auto': true},
      ));
    }

    // Trick complete when all 4 players have played.
    if (newTrick.length == 4) {
      final intermediate = autoRevealing
          ? state.copyWith(
              trumpRevealed: true,
              trumpRevealerThisTrick: move.playerId,
            )
          : state;
      return _completeTrick(intermediate, newTrick, newHands, events);
    }

    return MoveResult.valid(
      newState: state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        currentPlayerId: state.nextPlayerId,
        turnNumber: state.turnNumber + 1,
        trumpRevealed: autoRevealing ? true : state.trumpRevealed,
        trumpRevealerThisTrick:
            autoRevealing ? move.playerId : state.trumpRevealerThisTrick,
      ),
      events: events,
    );
  }

  MoveResult<TwentyNineState> _applyRevealTrump(
      TwentyNineState state, RevealTrumpMove move) {
    return MoveResult.valid(
      newState: state.copyWith(
        trumpRevealed: true,
        trumpRevealerThisTrick: move.playerId,
      ),
      events: [
        GameEvent(
          type: GameEventType.trumpRevealed,
          playerId: move.playerId,
          data: {'suit': state.trumpSuit!.name, 'hidden': false},
        ),
      ],
    );
  }

  // ── Trick completion ───────────────────────────────────────────────────────

  MoveResult<TwentyNineState> _completeTrick(
    TwentyNineState state,
    List<TrickCard> trick,
    Map<String, Hand> hands,
    List<GameEvent> events,
  ) {
    final leadSuit = trick.first.suit;
    final winnerId = _determineTrickWinner(trick, leadSuit, state.trumpSuit);
    final winnerTeam = state.teamForPlayer(winnerId);

    // Accumulate card points won this trick.
    final trickPoints =
        trick.fold<int>(0, (sum, tc) => sum + TwentyNineConfig.getCardPoints(tc.card));

    final newTricksWon = Map<int, int>.from(state.tricksWon);
    newTricksWon[winnerTeam] = (newTricksWon[winnerTeam] ?? 0) + 1;

    final newTeamPoints = Map<int, int>.from(state.teamPoints);
    newTeamPoints[winnerTeam] = (newTeamPoints[winnerTeam] ?? 0) + trickPoints;

    events.add(GameEvent(
      type: GameEventType.trickWon,
      playerId: winnerId,
      data: {
        'team': winnerTeam,
        'points': trickPoints,
        'trick': trick.map((t) => t.toJson()).toList(),
      },
    ));

    // Check if all 8 tricks have been played.
    final totalTricks = newTricksWon.values.fold<int>(0, (a, b) => a + b);
    if (totalTricks == 8) {
      return _completeRound(state, hands, newTricksWon, newTeamPoints, events);
    }

    // Winner leads the next trick. Clear the trump-revealer marker — the
    // "must play trump" obligation only applies within the revealing trick.
    return MoveResult.valid(
      newState: state.copyWith(
        hands: hands,
        currentTrick: [],
        tricksWon: newTricksWon,
        teamPoints: newTeamPoints,
        currentPlayerId: winnerId,
        turnNumber: state.turnNumber + 1,
        clearTrumpRevealer: true,
      ),
      events: events,
    );
  }

  MoveResult<TwentyNineState> _completeRound(
    TwentyNineState state,
    Map<String, Hand> hands,
    Map<int, int> tricksWon,
    Map<int, int> teamPoints,
    List<GameEvent> events,
  ) {
    final bidTeam = state.bidWinnerTeam!;
    final scoringResult = _scorer.scoreRound(
      bid: state.currentBid,
      biddingTeam: bidTeam,
      teamPoints: teamPoints,
      gameScores: state.sessionScores,
      doublingMultiplier: state.doublingMultiplier,
      bidAdjustment: state.bidAdjustment,
      redPips: state.redPips,
      blackPips: state.blackPips,
    );

    events.add(GameEvent(
      type: GameEventType.roundEnded,
      data: {
        'bidTeam': bidTeam,
        'bidValue': state.currentBid,
        'bidMet': scoringResult.biddingTeamScored,
        'sessionScores': scoringResult.updatedGameScores,
        'redPips': scoringResult.updatedRedPips,
        'blackPips': scoringResult.updatedBlackPips,
        'effectiveThreshold': scoringResult.effectiveThreshold,
      },
    ));

    // Session ends if any team's red reaches scorecardMax (they've won) or
    // their black reaches scorecardMax (they've lost — opponent has won).
    final max = TwentyNineConfig.scorecardMax;
    final gameOver = scoringResult.updatedRedPips.values.any((p) => p >= max) ||
        scoringResult.updatedBlackPips.values.any((p) => p >= max);

    if (gameOver) {
      events.add(GameEvent(
        type: GameEventType.gameEnded,
        data: {
          'sessionScores': scoringResult.updatedGameScores,
          'redPips': scoringResult.updatedRedPips,
          'blackPips': scoringResult.updatedBlackPips,
        },
      ));
    }

    return MoveResult.valid(
      newState: state.copyWith(
        phase: gameOver ? GamePhase.gameEnd : GamePhase.roundEnd,
        hands: hands,
        currentTrick: [],
        tricksWon: tricksWon,
        teamPoints: teamPoints,
        sessionScores: scoringResult.updatedGameScores,
        redPips: scoringResult.updatedRedPips,
        blackPips: scoringResult.updatedBlackPips,
        roundNumber: state.roundNumber + 1,
        turnNumber: state.turnNumber + 1,
      ),
      events: events,
    );
  }

  // ── Trick-winner determination ─────────────────────────────────────────────

  String _determineTrickWinner(
    List<TrickCard> trick,
    Suit leadSuit,
    Suit? trumpSuit,
  ) {
    TrickCard? winner;

    for (final tc in trick) {
      if (winner == null) {
        winner = tc;
        continue;
      }

      final current = tc.card;
      final winning = winner.card;

      if (trumpSuit != null) {
        final currentIsTrump = current.suit == trumpSuit;
        final winningIsTrump = winning.suit == trumpSuit;

        if (currentIsTrump && !winningIsTrump) {
          winner = tc;
          continue;
        }
        if (winningIsTrump && !currentIsTrump) {
          continue;
        }
        if (currentIsTrump && winningIsTrump) {
          if (TwentyNineConfig.cardStrength(current) >
              TwentyNineConfig.cardStrength(winning)) {
            winner = tc;
          }
          continue;
        }
      }

      // Neither is trump: only lead-suit cards can win.
      if (current.suit != leadSuit) continue;
      if (winning.suit != leadSuit) {
        winner = tc;
        continue;
      }
      if (TwentyNineConfig.cardStrength(current) >
          TwentyNineConfig.cardStrength(winning)) {
        winner = tc;
      }
    }

    return winner!.playerId;
  }

  // ── Game-end queries ───────────────────────────────────────────────────────

  @override
  bool isGameOver(TwentyNineState state) => state.isGameOver;

  @override
  List<String> getWinners(TwentyNineState state) {
    if (!isGameOver(state)) return [];
    final max = TwentyNineConfig.scorecardMax;
    // Winner is whichever team reached red == max OR whichever team's
    // opponent reached black == max. Both conditions converge on the same
    // team, but the data may come from either side.
    bool team0Wins() =>
        (state.redPips[0] ?? 0) >= max || (state.blackPips[1] ?? 0) >= max;
    bool team1Wins() =>
        (state.redPips[1] ?? 0) >= max || (state.blackPips[0] ?? 0) >= max;
    if (team0Wins()) {
      return [state.playerOrder[0], state.playerOrder[2]];
    }
    if (team1Wins()) {
      return [state.playerOrder[1], state.playerOrder[3]];
    }
    // Fallback to legacy sessionScores (for states restored from JSON
    // written before this change shipped).
    final scores = state.sessionScores;
    if ((scores[0] ?? 0) >= max) {
      return [state.playerOrder[0], state.playerOrder[2]];
    }
    if ((scores[1] ?? 0) >= max) {
      return [state.playerOrder[1], state.playerOrder[3]];
    }
    return [];
  }

  @override
  Map<String, int> calculateScores(TwentyNineState state) {
    return {
      for (final pid in state.playerOrder)
        pid: state.sessionScores[state.teamForPlayer(pid)] ?? 0,
    };
  }

  @override
  String? getNextPlayer(TwentyNineState state, List<String> playerIds) =>
      state.currentPlayerId;
}
