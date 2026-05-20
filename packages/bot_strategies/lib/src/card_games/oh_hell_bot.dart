import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

import '../core/bot_player.dart';
import '../core/personality.dart';

/// AI player for Oh Hell (3–7 players, exact-bid trick-taking).
class OhHellBot extends BotPlayer<OhHellState, OhHellMove> {
  OhHellBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  /// Hearts are always trump in this implementation.
  static const Suit _trump = Suit.hearts;

  @override
  OhHellMove? selectMove(
    OhHellState state,
    List<OhHellMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    if (!shouldPlayOptimally()) {
      return selectRandom(validMoves);
    }

    return switch (state.phase) {
      GamePhase.bidding => _selectBid(state, validMoves),
      GamePhase.playing => _selectPlay(state, validMoves),
      _ => validMoves.first,
    };
  }

  // ── Bidding ──────────────────────────────────────────────────────────────

  OhHellMove _selectBid(OhHellState state, List<OhHellMove> moves) {
    final bidMoves = moves.whereType<OhHellBidMove>().toList();
    if (bidMoves.isEmpty) return moves.first;

    final hand = state.hands[playerId]!;

    // Count expected tricks from hand quality.
    var expectedTricks = 0.0;
    for (final card in hand.cards) {
      final value = card.rank.index; // 0=two .. 12=ace

      if (card.suit == _trump) {
        // Trump cards are more likely to win.
        expectedTricks += 0.3 + (value / 12.0) * 0.7;
      } else {
        if (value >= 11) {
          expectedTricks += 0.5; // K or A
        } else if (value >= 9) {
          expectedTricks += 0.3; // J or Q
        }
      }
    }

    // Personality adjusts aggressiveness.
    expectedTricks *= (0.8 + personality.riskTolerance * 0.4);

    final targetBid = expectedTricks.round().clamp(0, hand.size);

    // Pick closest valid bid.
    return bidMoves.reduce((a, b) {
      final diffA = (a.bid - targetBid).abs();
      final diffB = (b.bid - targetBid).abs();
      return diffA <= diffB ? a : b;
    });
  }

  // ── Card play ────────────────────────────────────────────────────────────

  OhHellMove _selectPlay(OhHellState state, List<OhHellMove> moves) {
    final playMoves = moves.whereType<OhHellPlayCardMove>().toList();
    if (playMoves.isEmpty) return moves.first;

    final myBid = state.bids[playerId] ?? 0;
    final myTricks = state.tricksWon[playerId] ?? 0;
    final tricksNeeded = myBid - myTricks;

    if (tricksNeeded > 0) {
      return _tryToWin(state, playMoves);
    } else if (tricksNeeded == 0) {
      return _tryToLose(state, playMoves);
    } else {
      // Already over bid — play lowest.
      return _playLowest(playMoves);
    }
  }

  OhHellMove _tryToWin(OhHellState state, List<OhHellPlayCardMove> moves) {
    final trick = state.currentTrick;

    if (trick.isEmpty) {
      // Leading — play highest.
      return _playHighest(moves);
    }

    // Try to win with lowest winning card.
    final winningMoves =
        moves.where((m) => _wouldWinTrick(m.card, trick)).toList();

    if (winningMoves.isNotEmpty) {
      return _playLowest(winningMoves);
    }

    // Can't win — play lowest.
    return _playLowest(moves);
  }

  OhHellMove _tryToLose(OhHellState state, List<OhHellPlayCardMove> moves) {
    final trick = state.currentTrick;

    // Prefer non-winning cards.
    final losingMoves =
        moves.where((m) => !_wouldWinTrick(m.card, trick)).toList();

    if (losingMoves.isNotEmpty) {
      return _playLowest(losingMoves);
    }

    // Forced to win — play highest (might as well).
    return _playHighest(moves);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  OhHellPlayCardMove _playHighest(List<OhHellPlayCardMove> moves) {
    return moves.reduce(
        (a, b) => a.card.rank.index > b.card.rank.index ? a : b);
  }

  OhHellPlayCardMove _playLowest(List<OhHellPlayCardMove> moves) {
    return moves.reduce(
        (a, b) => a.card.rank.index < b.card.rank.index ? a : b);
  }

  bool _wouldWinTrick(PlayingCard card, List<TrickCard> trick) {
    if (trick.isEmpty) return true;

    final leadSuit = trick.first.suit;
    final currentWinner = _findWinningCard(trick);
    if (currentWinner == null) return true;

    return _beats(card, currentWinner, leadSuit);
  }

  PlayingCard? _findWinningCard(List<TrickCard> trick) {
    if (trick.isEmpty) return null;

    final leadSuit = trick.first.suit;
    PlayingCard winner = trick.first.card;

    for (var i = 1; i < trick.length; i++) {
      final card = trick[i].card;
      if (_beats(card, winner, leadSuit)) {
        winner = card;
      }
    }
    return winner;
  }

  bool _beats(PlayingCard a, PlayingCard b, Suit leadSuit) {
    if (a.suit == _trump && b.suit != _trump) return true;
    if (a.suit != _trump && b.suit == _trump) return false;
    if (a.suit == b.suit) return a.rank.index > b.rank.index;
    return false;
  }

  @override
  bool isComplexDecision(OhHellState state, OhHellMove move) {
    return move is OhHellBidMove;
  }
}
