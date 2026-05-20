import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../core/bot_player.dart';
import '../core/personality.dart';

/// AI player for Twenty-Nine (4-player, 2v2, 32-card trick-taking).
class TwentyNineBot extends BotPlayer<TwentyNineState, TwentyNineMove> {
  TwentyNineBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  @override
  TwentyNineMove? selectMove(
    TwentyNineState state,
    List<TwentyNineMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    if (!shouldPlayOptimally()) {
      return selectRandom(validMoves);
    }

    return switch (state.phase) {
      GamePhase.bidding => _selectBiddingMove(state, validMoves),
      GamePhase.trumpSelection => _selectTrumpMove(state, validMoves),
      GamePhase.playing => _selectPlayingMove(state, validMoves),
      _ => validMoves.first,
    };
  }

  // ── Bidding ──────────────────────────────────────────────────────────────

  TwentyNineMove _selectBiddingMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final bidMoves = moves.whereType<BidMove>().toList();
    final passMoves = moves.whereType<PassMove>().toList();
    final doubleMoves = moves.whereType<DoubleMove>().toList();
    final redoubleMoves = moves.whereType<RedoubleMove>().toList();

    final hand = state.hands[playerId]!;
    final estimate = _estimateBid(hand);

    // Double/redouble opportunities: only when opponent (or partner) has
    // bid clearly above what we estimate the bidding team can realistically
    // make. Conservative by default.
    if (doubleMoves.isNotEmpty &&
        state.currentBid > 0 &&
        state.currentBid >= estimate + 6) {
      return doubleMoves.first;
    }
    if (redoubleMoves.isNotEmpty && estimate >= state.currentBid + 2) {
      return redoubleMoves.first;
    }

    if (bidMoves.isEmpty) {
      return passMoves.isNotEmpty ? passMoves.first : moves.first;
    }

    // Personality tweak: ±1 bid point. riskTolerance ranges 0.2–0.8,
    // so this shifts target by roughly -1 (cautious) to +1 (quick).
    final riskAdjust = ((personality.riskTolerance - 0.5) * 2).round();
    final target = estimate + riskAdjust;
    final minBid = state.minimumBid;

    // Only enter the auction if we actually have the cards for it.
    if (target < minBid) {
      return passMoves.isNotEmpty ? passMoves.first : bidMoves.first;
    }

    // Don't chase the auction higher than our estimate — if the current bid
    // already exceeds what we want, pass.
    if (state.currentBid >= target) {
      return passMoves.isNotEmpty ? passMoves.first : bidMoves.first;
    }

    // Bid the smallest value that is both ≥ minBid and ≤ target.
    final clampedTarget = target.clamp(minBid, TwentyNineConfig.maxBid);
    final bestBid = bidMoves
        .where((b) => b.bidValue != TwentyNineConfig.specialBid)
        .fold<BidMove?>(null, (best, b) {
      if (b.bidValue > clampedTarget) return best;
      if (best == null || b.bidValue < best.bidValue) return b;
      return best;
    });
    if (bestBid != null) return bestBid;

    return passMoves.isNotEmpty ? passMoves.first : bidMoves.first;
  }

  /// Estimate how many card-points (out of 28) our partnership can realistically
  /// take with this hand, assuming a suit we are long in is trump.
  ///
  /// The result is used directly as the bot's target bid. Calibrated so that:
  ///   • A weak hand (no Js/9s, no long suit) → ~14 (will pass the auction).
  ///   • An average hand → ~16–18.
  ///   • A strong hand (J+9 of trump, long suit, outside aces) → ~22–26.
  int _estimateBid(Hand hand) {
    if (hand.cards.isEmpty) return 0;

    // Count point-cards in hand and short/long suit structure.
    final suitCounts = <Suit, int>{};
    final suitPoints = <Suit, int>{};
    var ownPoints = 0;
    for (final card in hand.cards) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      final pts = TwentyNineConfig.getCardPoints(card);
      suitPoints[card.suit] = (suitPoints[card.suit] ?? 0) + pts;
      ownPoints += pts;
    }

    // Choose our best candidate trump suit: highest combined score of
    // length + point-cards in that suit.
    Suit? trump;
    var bestTrumpScore = -1.0;
    for (final entry in suitCounts.entries) {
      final len = entry.value.toDouble();
      final pts = (suitPoints[entry.key] ?? 0).toDouble();
      final score = len * 1.5 + pts;
      if (score > bestTrumpScore) {
        bestTrumpScore = score;
        trump = entry.key;
      }
    }

    final trumpCards =
        trump == null ? <PlayingCard>[] : hand.cardsOfSuit(trump);

    // Rough trick-taking power from the trump suit.
    var trumpControl = 0.0;
    for (final c in trumpCards) {
      final s = TwentyNineConfig.cardStrength(c);
      if (s == 8) trumpControl += 1.0; // J of trump
      else if (s == 7) trumpControl += 0.8; // 9 of trump
      else if (s == 6) trumpControl += 0.6; // A of trump
      else if (s == 5) trumpControl += 0.45; // 10 of trump
      else if (s == 4) trumpControl += 0.3; // K of trump
      else trumpControl += 0.15;
    }
    // Extra length bonus — small trumps become useful with a 5+ card suit.
    if (trumpCards.length >= 5) trumpControl += 0.8;
    else if (trumpCards.length >= 4) trumpControl += 0.4;

    // Side-suit winners: A or J of a side suit (likely trick-takers,
    // especially Js — they're the strongest card in their suit).
    var sideWinners = 0.0;
    for (final card in hand.cards) {
      if (card.suit == trump) continue;
      if (card.rank == Rank.jack) sideWinners += 0.75;
      else if (card.rank == Rank.nine) sideWinners += 0.4;
      else if (card.rank == Rank.ace) sideWinners += 0.35;
      else if (card.rank == Rank.ten) sideWinners += 0.1;
    }

    // Void / singleton in a side suit → can trump it later.
    var ruffPotential = 0.0;
    for (final entry in suitCounts.entries) {
      if (entry.key == trump) continue;
      if (entry.value == 0) ruffPotential += 0.6;
      else if (entry.value == 1) ruffPotential += 0.3;
    }

    // Expected card-points captured:
    //   • Own point-cards (we keep what we already control).
    //   • A fraction of the remaining 28 − ownPoints scaled by control.
    //   • Partner contribution: small constant, since strong hands signal
    //     partner is likely weaker (and vice versa).
    final control =
        (trumpControl + sideWinners + ruffPotential).clamp(0.0, 10.0);
    final remaining = (TwentyNineConfig.totalCardPoints - ownPoints)
        .toDouble()
        .clamp(0.0, 28.0);
    final captureFraction = (control / 6.0).clamp(0.0, 0.7);
    final expected = ownPoints + remaining * captureFraction + 1.5;

    // Bots must not bid what they merely *hope* to make — subtract a safety
    // margin so the auction settles near a realistic contract.
    return (expected - 2).round();
  }

  // ── Trump selection ──────────────────────────────────────────────────────

  TwentyNineMove _selectTrumpMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final trumpMoves = moves.whereType<DeclareTrumpMove>().toList();
    if (trumpMoves.isEmpty) return moves.first;

    final hand = state.hands[playerId]!;

    // Evaluate each suit's strength.
    final suitStrengths = <Suit, double>{};
    for (final suit in Suit.values) {
      final suitCards = hand.cardsOfSuit(suit);
      if (suitCards.isEmpty) continue;

      var strength = suitCards.length.toDouble();
      for (final card in suitCards) {
        strength += TwentyNineConfig.cardStrength(card) / 8.0;
      }
      suitStrengths[suit] = strength;
    }

    if (suitStrengths.isEmpty) return trumpMoves.first;

    final bestSuit =
        suitStrengths.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return trumpMoves.firstWhere(
      (m) => m.suit == bestSuit,
      orElse: () => trumpMoves.first,
    );
  }

  // ── Card play ────────────────────────────────────────────────────────────

  TwentyNineMove _selectPlayingMove(
    TwentyNineState state,
    List<TwentyNineMove> moves,
  ) {
    final playMoves = moves.whereType<PlayCardMove>().toList();
    if (playMoves.isEmpty) return moves.first;

    final isLeading = state.currentTrick.isEmpty;
    final partnerId = state.getPartner(playerId);

    if (isLeading) {
      return _selectLeadCard(state, playMoves);
    } else {
      return _selectFollowCard(state, playMoves, partnerId);
    }
  }

  TwentyNineMove _selectLeadCard(
    TwentyNineState state,
    List<PlayCardMove> moves,
  ) {
    final myTeam = state.teamForPlayer(playerId);
    final myPoints = state.teamPoints[myTeam] ?? 0;
    final opponentPoints =
        state.teamPoints[myTeam == 0 ? 1 : 0] ?? 0;

    if (myPoints > opponentPoints) {
      // Winning — lead high to secure tricks.
      return moves.reduce((a, b) =>
          TwentyNineConfig.cardStrength(a.card) >
                  TwentyNineConfig.cardStrength(b.card)
              ? a
              : b);
    } else {
      // Losing — lead low to draw out trumps.
      return moves.reduce((a, b) =>
          TwentyNineConfig.cardStrength(a.card) <
                  TwentyNineConfig.cardStrength(b.card)
              ? a
              : b);
    }
  }

  TwentyNineMove _selectFollowCard(
    TwentyNineState state,
    List<PlayCardMove> moves,
    String? partnerId,
  ) {
    final trick = state.currentTrick;
    final winningEntry = _findWinningTrickCard(trick, state.trumpSuit);
    final partnerIsWinning =
        winningEntry != null && winningEntry.playerId == partnerId;

    if (partnerIsWinning) {
      // Partner winning — play lowest.
      return moves.reduce((a, b) =>
          TwentyNineConfig.cardStrength(a.card) <
                  TwentyNineConfig.cardStrength(b.card)
              ? a
              : b);
    }

    // Opponent winning — try to win with lowest winning card.
    final winningMoves = moves
        .where((m) => _wouldWinTrick(m.card, trick, state.trumpSuit))
        .toList();

    if (winningMoves.isNotEmpty) {
      return winningMoves.reduce((a, b) =>
          TwentyNineConfig.cardStrength(a.card) <
                  TwentyNineConfig.cardStrength(b.card)
              ? a
              : b);
    }

    // Can't win — throw lowest.
    return moves.reduce((a, b) =>
        TwentyNineConfig.cardStrength(a.card) <
                TwentyNineConfig.cardStrength(b.card)
            ? a
            : b);
  }

  // ── Trick evaluation helpers ─────────────────────────────────────────────

  TrickCard? _findWinningTrickCard(List<TrickCard> trick, Suit? trump) {
    if (trick.isEmpty) return null;

    final leadSuit = trick.first.suit;
    TrickCard winner = trick.first;

    for (var i = 1; i < trick.length; i++) {
      final card = trick[i];
      if (_beats(card.card, winner.card, leadSuit, trump)) {
        winner = card;
      }
    }
    return winner;
  }

  bool _beats(PlayingCard a, PlayingCard b, Suit leadSuit, Suit? trump) {
    // Trump beats non-trump.
    if (a.suit == trump && b.suit != trump) return true;
    if (a.suit != trump && b.suit == trump) return false;
    // Same suit — compare strength.
    if (a.suit == b.suit) {
      return TwentyNineConfig.cardStrength(a) >
          TwentyNineConfig.cardStrength(b);
    }
    // Different non-trump suits — later card doesn't beat.
    return false;
  }

  bool _wouldWinTrick(PlayingCard card, List<TrickCard> trick, Suit? trump) {
    final winner = _findWinningTrickCard(trick, trump);
    if (winner == null) return true;
    return _beats(card, winner.card, trick.first.suit, trump);
  }

  @override
  bool isComplexDecision(TwentyNineState state, TwentyNineMove move) {
    if (move is BidMove || move is DeclareTrumpMove) return true;
    // Late-game tricks are more complex.
    final handSize = state.hands[playerId]?.size ?? 0;
    return handSize <= 3;
  }
}
