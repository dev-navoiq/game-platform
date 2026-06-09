import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';

import '../core/bot_player.dart';

/// Standard American Yellow Card (SAYC) Bridge bot.
///
/// Implements a first-pass SAYC bidding system (opening bids, simple responses,
/// rebids, slam exploration via Blackwood, takeout doubles, overcalls) plus
/// rule-of-thumb card play (opening leads, 2nd-low/3rd-high, ruffing, simple
/// trump management). Decisions are local — no double-dummy lookahead, no
/// partnership inference beyond what the auction log makes explicit.
class BridgeBot extends BotPlayer<BridgeState, BridgeMove> {
  BridgeBot({
    required super.playerId,
    required super.name,
    required super.difficulty,
    super.personality,
    super.random,
  });

  // ── Public selectMove ──────────────────────────────────────────────────────

  @override
  BridgeMove? selectMove(
    BridgeState state,
    List<BridgeMove> validMoves,
  ) {
    if (validMoves.isEmpty) return null;

    if (!shouldPlayOptimally()) {
      return selectRandom(validMoves);
    }

    switch (state.phase) {
      case GamePhase.bidding:
        return _selectAuctionCall(state, validMoves);
      case GamePhase.playing:
        return _selectCardPlay(state, validMoves);
      case GamePhase.roundEnd:
      case GamePhase.gameEnd:
        final newDeal = validMoves.whereType<BridgeNewDealMove>().firstOrNull;
        return newDeal ?? validMoves.first;
      default:
        return validMoves.first;
    }
  }

  @override
  bool isComplexDecision(BridgeState state, BridgeMove move) {
    return move is BridgeBidMove ||
        move is BridgeDoubleMove ||
        move is BridgeRedoubleMove;
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║                              BIDDING                                     ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  BridgeMove _selectAuctionCall(BridgeState state, List<BridgeMove> moves) {
    final hand = state.hands[playerId];
    if (hand == null) return _passOrFirst(moves);

    final history = state.auctionHistory;
    final mySeat = state.playerOrder.indexOf(playerId);
    if (mySeat < 0) return _passOrFirst(moves);

    final myParity = mySeat % 2;
    final partnerSeat = (mySeat + 2) % 4;
    final hcp = hcpOfHand(hand);
    final suitLengths = _suitLengths(hand);

    final partnerCalls =
        history.where((c) => c.seatIndex == partnerSeat).toList();
    final partnerLastBid =
        partnerCalls.where((c) => c.isBid).toList().reversedOrNull;
    final opponentBids = history
        .where((c) => c.isBid && c.seatIndex % 2 != myParity)
        .toList();
    final myLastBid =
        history.where((c) => c.seatIndex == mySeat && c.isBid).reversedOrNull;
    final highestBid = _highestBid(history);

    // ── Blackwood response: partner asked 4NT ──
    if (partnerLastBid != null &&
        partnerLastBid.level == 4 &&
        partnerLastBid.denomination == BridgeDenomination.noTrump &&
        _partnershipHasAgreedTrump(history, myParity)) {
      return _blackwoodResponse(hand, moves);
    }

    // ── Slam exploration after we've agreed a major ──
    if (_shouldStartBlackwood(state, history, mySeat, hand, hcp)) {
      final bw = _firstBidMatching(moves, 4, BridgeDenomination.noTrump);
      if (bw != null) return bw;
    }

    // ── Responding to partner's opening or rebid ──
    if (partnerLastBid != null) {
      final response =
          _selectResponseOrRebid(state, moves, hand, hcp, suitLengths, history,
              mySeat, partnerLastBid, myLastBid);
      if (response != null) return response;
    }

    // ── Competitive: overcalls and takeout doubles ──
    if (partnerLastBid == null && opponentBids.isNotEmpty) {
      final competitive = _selectCompetitive(
          moves, hand, hcp, suitLengths, opponentBids, history, mySeat);
      if (competitive != null) return competitive;
    }

    // ── Opening bid (no prior bid on either side, or all passes so far) ──
    if (highestBid == null) {
      final opening = _selectOpeningBid(moves, hand, hcp, suitLengths);
      if (opening != null) return opening;
    }

    return _passOrFirst(moves);
  }

  // ── Opening bids ──────────────────────────────────────────────────────────

  BridgeMove? _selectOpeningBid(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
  ) {
    final balanced = _isBalanced(lengths);

    if (hcp >= 22) {
      final bid = _firstBidMatching(moves, 2, BridgeDenomination.clubs);
      if (bid != null) return bid;
    }

    if (hcp >= 20 && hcp <= 21 && balanced) {
      final bid = _firstBidMatching(moves, 2, BridgeDenomination.noTrump);
      if (bid != null) return bid;
    }

    if (hcp >= 15 && hcp <= 17 && balanced) {
      final bid = _firstBidMatching(moves, 1, BridgeDenomination.noTrump);
      if (bid != null) return bid;
    }

    if (hcp >= 11) {
      // Open longer major (5+); with 5-5 prefer spades.
      final spades = lengths[Suit.spades] ?? 0;
      final hearts = lengths[Suit.hearts] ?? 0;

      if (spades >= 5 && spades >= hearts) {
        final bid = _firstBidMatching(moves, 1, BridgeDenomination.spades);
        if (bid != null) return bid;
      }
      if (hearts >= 5 && hearts > spades) {
        final bid = _firstBidMatching(moves, 1, BridgeDenomination.hearts);
        if (bid != null) return bid;
      }

      // Otherwise open a minor — longer minor; with 3-3 open clubs;
      // with 4-4 open diamonds.
      final clubs = lengths[Suit.clubs] ?? 0;
      final diamonds = lengths[Suit.diamonds] ?? 0;
      BridgeDenomination minor;
      if (diamonds > clubs) {
        minor = BridgeDenomination.diamonds;
      } else if (clubs > diamonds) {
        minor = BridgeDenomination.clubs;
      } else {
        // Equal length minors: open 1D with 4-4, 1C with 3-3 or shorter.
        minor = clubs >= 4
            ? BridgeDenomination.diamonds
            : BridgeDenomination.clubs;
      }
      final bid = _firstBidMatching(moves, 1, minor);
      if (bid != null) return bid;
    }

    // Weak two: 5-11 HCP, exactly 6-card suit of decent quality.
    if (hcp >= 5 && hcp <= 11) {
      for (final suit in [Suit.spades, Suit.hearts, Suit.diamonds]) {
        final len = lengths[suit] ?? 0;
        if (len == 6 && _suitHasDecentQuality(hand, suit)) {
          final denom = _denomForSuit(suit);
          final bid = _firstBidMatching(moves, 2, denom);
          if (bid != null) return bid;
        }
      }
    }

    // Preempt: 7-card suit, 6-10 HCP.
    if (hcp >= 6 && hcp <= 10) {
      for (final suit in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]) {
        final len = lengths[suit] ?? 0;
        if (len >= 7) {
          final denom = _denomForSuit(suit);
          final bid = _firstBidMatching(moves, 3, denom);
          if (bid != null) return bid;
        }
      }
    }

    return null;
  }

  // ── Responses + rebids ────────────────────────────────────────────────────

  BridgeMove? _selectResponseOrRebid(
    BridgeState state,
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
    List<AuctionCall> history,
    int mySeat,
    AuctionCall partnerLastBid,
    AuctionCall? myLastBid,
  ) {
    // Did I open the bidding? Rebid logic applies.
    final iHaveOpened = myLastBid != null;
    if (iHaveOpened) {
      return _selectRebid(
          moves, hand, hcp, lengths, history, mySeat, myLastBid, partnerLastBid);
    }

    // Partner opened — pick a response.
    final pd = partnerLastBid.denomination!;
    final pl = partnerLastBid.level!;

    // Response to 1NT opening.
    if (pl == 1 && pd == BridgeDenomination.noTrump) {
      return _respondTo1NT(moves, hand, hcp, lengths);
    }

    // Response to 2NT opening.
    if (pl == 2 && pd == BridgeDenomination.noTrump) {
      if (hcp >= 5) {
        final game = _firstBidMatching(moves, 3, BridgeDenomination.noTrump);
        if (game != null) return game;
      }
      return null;
    }

    // Response to a strong 2C opening — keep it simple: bid 2D (waiting).
    if (pl == 2 && pd == BridgeDenomination.clubs) {
      final waiting = _firstBidMatching(moves, 2, BridgeDenomination.diamonds);
      if (waiting != null) return waiting;
      return null;
    }

    // Response to 1 of a major.
    if (pl == 1 && pd.isMajor) {
      return _respondToMajor(moves, hand, hcp, lengths, pd);
    }

    // Response to 1 of a minor.
    if (pl == 1 && pd.isMinor) {
      return _respondToMinor(moves, hand, hcp, lengths, pd);
    }

    return null;
  }

  BridgeMove? _respondTo1NT(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
  ) {
    final hearts = lengths[Suit.hearts] ?? 0;
    final spades = lengths[Suit.spades] ?? 0;

    // Jacoby transfer: 5+ in a major — any strength.
    if (hearts >= 5) {
      final transfer = _firstBidMatching(moves, 2, BridgeDenomination.diamonds);
      if (transfer != null) return transfer;
    }
    if (spades >= 5) {
      final transfer = _firstBidMatching(moves, 2, BridgeDenomination.hearts);
      if (transfer != null) return transfer;
    }

    if (hcp < 8) return null;

    final hasFourCardMajor = hearts >= 4 || spades >= 4;

    // Stayman: 8+ HCP with a 4-card major.
    if (hasFourCardMajor) {
      final stayman = _firstBidMatching(moves, 2, BridgeDenomination.clubs);
      if (stayman != null) return stayman;
    }

    if (hcp >= 10 && hcp <= 15) {
      final game = _firstBidMatching(moves, 3, BridgeDenomination.noTrump);
      if (game != null) return game;
    }

    if (hcp >= 8 && hcp <= 9) {
      final inv = _firstBidMatching(moves, 2, BridgeDenomination.noTrump);
      if (inv != null) return inv;
    }
    return null;
  }

  BridgeMove? _respondToMajor(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
    BridgeDenomination opened,
  ) {
    if (hcp < 6) return null;

    final trumpSuit = opened.suit!;
    final support = lengths[trumpSuit] ?? 0;
    final balanced = _isBalanced(lengths);

    // Limit raise (10-12) with 3+ support.
    if (support >= 3 && hcp >= 10 && hcp <= 12) {
      final bid = _firstBidMatching(moves, 3, opened);
      if (bid != null) return bid;
    }
    // Simple raise (6-9) with 3+ support.
    if (support >= 3 && hcp >= 6 && hcp <= 9) {
      final bid = _firstBidMatching(moves, 2, opened);
      if (bid != null) return bid;
    }
    // Jump to game with 13+ and trump support — bid 4 of major.
    if (support >= 3 && hcp >= 13) {
      final bid = _firstBidMatching(moves, 4, opened);
      if (bid != null) return bid;
    }

    // 1S over 1H with 4+ spades and 6+ HCP.
    if (opened == BridgeDenomination.hearts &&
        (lengths[Suit.spades] ?? 0) >= 4 &&
        hcp >= 6) {
      final bid = _firstBidMatching(moves, 1, BridgeDenomination.spades);
      if (bid != null) return bid;
    }

    // New suit at 2-level: 11+ HCP, 5+ in new suit.
    if (hcp >= 11) {
      for (final suit in [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades]) {
        if (suit == trumpSuit) continue;
        if ((lengths[suit] ?? 0) >= 5) {
          final denom = _denomForSuit(suit);
          final bid = _firstBidMatching(moves, 2, denom);
          if (bid != null) return bid;
        }
      }
    }

    // NT responses without trump support.
    if (support < 3 && balanced) {
      if (hcp >= 13 && hcp <= 15) {
        final bid = _firstBidMatching(moves, 3, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
      if (hcp >= 11 && hcp <= 12) {
        final bid = _firstBidMatching(moves, 2, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
      if (hcp >= 6 && hcp <= 9) {
        final bid = _firstBidMatching(moves, 1, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
    }

    return null;
  }

  BridgeMove? _respondToMinor(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
    BridgeDenomination opened,
  ) {
    if (hcp < 6) return null;

    final balanced = _isBalanced(lengths);
    final hasFourCardMajor =
        (lengths[Suit.hearts] ?? 0) >= 4 || (lengths[Suit.spades] ?? 0) >= 4;

    // 1 of new suit — prefer majors first (cheaper level), then diamonds over clubs.
    for (final suit in [Suit.diamonds, Suit.hearts, Suit.spades]) {
      final suitDenom = _denomForSuit(suit);
      if (suitDenom == opened) continue;
      if ((lengths[suit] ?? 0) >= 4) {
        final bid = _firstBidMatching(moves, 1, suitDenom);
        if (bid != null) return bid;
      }
    }

    // NT responses without a 4-card major.
    if (balanced && !hasFourCardMajor) {
      if (hcp >= 13 && hcp <= 15) {
        final bid = _firstBidMatching(moves, 3, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
      if (hcp >= 11 && hcp <= 12) {
        final bid = _firstBidMatching(moves, 2, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
      if (hcp >= 6 && hcp <= 10) {
        final bid = _firstBidMatching(moves, 1, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
    }

    // 2 of opener's minor with 5+ support.
    if ((lengths[opened.suit!] ?? 0) >= 5 && hcp >= 6 && hcp <= 9) {
      final bid = _firstBidMatching(moves, 2, opened);
      if (bid != null) return bid;
    }

    return null;
  }

  BridgeMove? _selectRebid(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
    List<AuctionCall> history,
    int mySeat,
    AuctionCall myLastBid,
    AuctionCall partnerLastBid,
  ) {
    final totalPoints = hcp + _distributionPoints(lengths);
    final openedSuit = myLastBid.denomination;
    final partnerSuit = partnerLastBid.denomination;
    final partnerLevel = partnerLastBid.level!;

    // After single raise of our major (1M-2M).
    if (openedSuit != null &&
        openedSuit.isMajor &&
        partnerSuit == openedSuit &&
        partnerLevel == 2) {
      if (totalPoints >= 18) {
        final game = _firstBidMatching(moves, 4, openedSuit);
        if (game != null) return game;
      }
      // Otherwise pass with 12-14.
      return null;
    }

    // After 1NT response.
    if (partnerSuit == BridgeDenomination.noTrump && partnerLevel == 1) {
      if (hcp >= 18 && hcp <= 19 && _isBalanced(lengths)) {
        final bid = _firstBidMatching(moves, 3, BridgeDenomination.noTrump);
        if (bid != null) return bid;
      }
      if (hcp >= 15 && hcp <= 17 && openedSuit != null) {
        final jump = _firstBidMatching(moves, 3, openedSuit);
        if (jump != null) return jump;
      }
      if (openedSuit != null) {
        final bid = _firstBidMatching(moves, 2, openedSuit);
        if (bid != null) return bid;
      }
    }

    return null;
  }

  // ── Competitive: overcalls / takeout doubles ──────────────────────────────

  BridgeMove? _selectCompetitive(
    List<BridgeMove> moves,
    Hand hand,
    int hcp,
    Map<Suit, int> lengths,
    List<AuctionCall> opponentBids,
    List<AuctionCall> history,
    int mySeat,
  ) {
    final lastOpponentBid = opponentBids.last;
    if (lastOpponentBid.level != 1) {
      // Only handle 1-level overcalls/doubles in simplified scheme.
      return null;
    }
    final oppSuit = lastOpponentBid.denomination!;

    // Takeout double: 12+ HCP, shortness in opponent's suit (0-2), 3+ in unbid suits.
    if (hcp >= 12 && oppSuit != BridgeDenomination.noTrump) {
      final oppSuitLen = lengths[oppSuit.suit!] ?? 0;
      if (oppSuitLen <= 2 && _supportsUnbidSuits(oppSuit.suit!, lengths)) {
        final dbl = moves.whereType<BridgeDoubleMove>().firstOrNull;
        if (dbl != null) return dbl;
      }
    }

    // Overcall at the 1-level: 8-16 HCP with 5+ card suit ranking above opp's bid.
    if (hcp >= 8 && hcp <= 16) {
      for (final suit in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]) {
        if ((lengths[suit] ?? 0) >= 5 && _suitHasDecentQuality(hand, suit)) {
          final denom = _denomForSuit(suit);
          // 1-level overcall only.
          final bid = _firstBidMatching(moves, 1, denom);
          if (bid != null) return bid;
        }
      }
    }

    return null;
  }

  // ── Blackwood ──────────────────────────────────────────────────────────────

  /// Returns true if our last partnership bid established a trump fit at the
  /// 3+ level in a major and combined strength looks like enough for slam.
  bool _shouldStartBlackwood(
    BridgeState state,
    List<AuctionCall> history,
    int mySeat,
    Hand hand,
    int hcp,
  ) {
    if (hcp < 17) return false;
    final myParity = mySeat % 2;
    final ourBids = history
        .where((c) => c.isBid && c.seatIndex % 2 == myParity)
        .toList();
    if (ourBids.length < 2) return false;
    final lastTwo = ourBids.reversed.take(2).toList();
    if (lastTwo[0].denomination != lastTwo[1].denomination) return false;
    final agreed = lastTwo[0].denomination;
    if (agreed == null || !agreed.isMajor) return false;
    final lastBid = lastTwo[0];
    return (lastBid.level ?? 0) >= 3;
  }

  bool _partnershipHasAgreedTrump(List<AuctionCall> history, int parity) {
    final ourBids =
        history.where((c) => c.isBid && c.seatIndex % 2 == parity).toList();
    if (ourBids.length < 2) return false;
    final denoms = ourBids.map((c) => c.denomination).toSet();
    return denoms.length == 2 &&
        denoms.contains(BridgeDenomination.noTrump) == false;
  }

  BridgeMove _blackwoodResponse(Hand hand, List<BridgeMove> moves) {
    final aces = hand.cards.where((c) => c.rank == Rank.ace).length;
    final mapping = <int, BridgeDenomination>{
      0: BridgeDenomination.clubs,
      4: BridgeDenomination.clubs,
      1: BridgeDenomination.diamonds,
      2: BridgeDenomination.hearts,
      3: BridgeDenomination.spades,
    };
    final denom = mapping[aces] ?? BridgeDenomination.clubs;
    final bid = _firstBidMatching(moves, 5, denom);
    return bid ?? _passOrFirst(moves);
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║                              CARD PLAY                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  BridgeMove _selectCardPlay(BridgeState state, List<BridgeMove> moves) {
    final playMoves = moves.whereType<BridgePlayCardMove>().toList();
    if (playMoves.isEmpty) return moves.first;

    final trumpSuit = state.contract?.denomination.suit;
    final trick = state.currentTrick;
    final isOpeningLead = state.trickNumber == 0 && trick.isEmpty;

    if (isOpeningLead) {
      return _selectOpeningLead(state, playMoves, trumpSuit);
    }

    if (trick.isEmpty) {
      return _selectMidHandLead(state, playMoves, trumpSuit);
    }

    return _selectFollow(state, playMoves, trick, trumpSuit);
  }

  // ── Opening lead ──────────────────────────────────────────────────────────

  BridgePlayCardMove _selectOpeningLead(
    BridgeState state,
    List<BridgePlayCardMove> moves,
    Suit? trumpSuit,
  ) {
    final hand = state.hands[playerId]!;
    final contract = state.contract;
    final isNoTrump = contract?.denomination == BridgeDenomination.noTrump;

    // Suits partner bid during the auction (excluding pass/double/redouble).
    final partnerBidSuits = _partnerBidSuits(state);

    // Vs suit contract: prefer partner's suit if any.
    if (!isNoTrump && partnerBidSuits.isNotEmpty) {
      for (final suit in partnerBidSuits) {
        if (suit == trumpSuit) continue;
        final cards = hand.cardsOfSuit(suit);
        if (cards.isEmpty) continue;
        final card = _leadInPartnerSuit(cards);
        final move = _moveForCard(moves, card);
        if (move != null) return move;
      }
    }

    // Top of a 3+-card sequence in any non-trump suit (AKx, KQJ, QJ10).
    for (final suit in Suit.values) {
      if (!isNoTrump && suit == trumpSuit) continue;
      final cards = hand.cardsOfSuit(suit);
      final seqTop = _topOfSequence(cards);
      if (seqTop != null) {
        final move = _moveForCard(moves, seqTop);
        if (move != null) return move;
      }
    }

    // Avoid leading suits the declaring side bid (vs NT).
    final declaringBids =
        _declaringSideBidSuits(state, contract?.declarerSeat ?? -1);

    final candidateSuits = Suit.values.where((s) {
      if (!isNoTrump && s == trumpSuit) return false;
      if (isNoTrump && declaringBids.contains(s)) return false;
      return hand.hasSuit(s);
    }).toList();

    // 4th-best from longest+strongest.
    final ordered = _suitsByLengthThenStrength(hand, candidateSuits);
    for (final suit in ordered) {
      final cards = List<PlayingCard>.from(hand.cardsOfSuit(suit))
        ..sort((a, b) => b.rank.index.compareTo(a.rank.index));
      // Skip "leading away from AK" vs suit contracts when we hold both.
      if (!isNoTrump &&
          _holdsBoth(cards, Rank.ace, Rank.king) &&
          ordered.length > 1) {
        continue;
      }
      if (cards.length >= 4) {
        final fourthBest = cards[3];
        final move = _moveForCard(moves, fourthBest);
        if (move != null) return move;
      }
      if (cards.isNotEmpty) {
        final small = cards.last;
        final move = _moveForCard(moves, small);
        if (move != null) return move;
      }
    }

    // Fallback: lowest legal non-trump card; otherwise lowest of anything.
    final nonTrump = moves
        .where((m) => trumpSuit == null || m.card.suit != trumpSuit)
        .toList();
    if (nonTrump.isNotEmpty) return _lowestCardMove(nonTrump);
    return _lowestCardMove(moves);
  }

  PlayingCard _leadInPartnerSuit(List<PlayingCard> cards) {
    final sorted = List<PlayingCard>.from(cards)
      ..sort((a, b) => b.rank.index.compareTo(a.rank.index));
    if (sorted.length == 2) return sorted.first; // top of doubleton
    if (sorted.length == 1) return sorted.first;
    return sorted.last; // small from 3+
  }

  /// Returns the top card if [cards] contains a 3-in-a-row sequence headed by
  /// AK, KQ, or QJ (with the third card adjacent).
  PlayingCard? _topOfSequence(List<PlayingCard> cards) {
    final sorted = List<PlayingCard>.from(cards)
      ..sort((a, b) => b.rank.index.compareTo(a.rank.index));
    if (sorted.length < 3) return null;
    bool isSeq(Rank a, Rank b, Rank c) =>
        a.index - 1 == b.index && b.index - 1 == c.index;

    final top3 = sorted.take(3).map((c) => c.rank).toList();
    // AKQ → A
    if (isSeq(top3[0], top3[1], top3[2]) && top3[0] == Rank.ace) {
      return sorted.first;
    }
    // KQJ → K
    if (isSeq(top3[0], top3[1], top3[2]) && top3[0] == Rank.king) {
      return sorted.first;
    }
    // QJ10 → Q
    if (isSeq(top3[0], top3[1], top3[2]) && top3[0] == Rank.queen) {
      return sorted.first;
    }
    return null;
  }

  // ── Mid-hand lead (we won the previous trick) ─────────────────────────────

  BridgePlayCardMove _selectMidHandLead(
    BridgeState state,
    List<BridgePlayCardMove> moves,
    Suit? trumpSuit,
  ) {
    final hand = state.hands[state.currentPlayerId]!;
    final isDeclarerSide = _isDeclarerSide(state, state.currentPlayerId!);

    // Declarer: try to draw trumps if opponents likely still hold any.
    if (isDeclarerSide && trumpSuit != null) {
      final myTrumps = hand.cardsOfSuit(trumpSuit);
      final played = _trumpsPlayed(state, trumpSuit);
      if (played < 13 - myTrumps.length && myTrumps.isNotEmpty) {
        final highTrump = myTrumps
            .reduce((a, b) => a.rank.index > b.rank.index ? a : b);
        final move = _moveForCard(moves, highTrump);
        if (move != null) return move;
      }
    }

    // Top of a sequence in a long side suit.
    for (final suit in Suit.values) {
      if (suit == trumpSuit) continue;
      final cards = hand.cardsOfSuit(suit);
      final seq = _topOfSequence(cards);
      if (seq != null) {
        final move = _moveForCard(moves, seq);
        if (move != null) return move;
      }
    }

    // Low card from longest non-trump suit (establishing length).
    final candidates = Suit.values
        .where((s) => s != trumpSuit && hand.hasSuit(s))
        .toList();
    final ordered = _suitsByLengthThenStrength(hand, candidates);
    if (ordered.isNotEmpty) {
      final long = ordered.first;
      final cards = List<PlayingCard>.from(hand.cardsOfSuit(long))
        ..sort((a, b) => a.rank.index.compareTo(b.rank.index));
      final small = cards.first;
      final move = _moveForCard(moves, small);
      if (move != null) return move;
    }

    return _lowestCardMove(moves);
  }

  // ── Following to a trick already in progress ──────────────────────────────

  BridgePlayCardMove _selectFollow(
    BridgeState state,
    List<BridgePlayCardMove> moves,
    List<TrickCard> trick,
    Suit? trumpSuit,
  ) {
    final leadSuit = trick.first.card.suit;
    final hand = state.hands[state.currentPlayerId]!;
    final mustFollow = hand.hasSuit(leadSuit);
    final position = trick.length + 1; // 2nd, 3rd, or 4th to play

    final currentWinner = _currentWinner(trick, leadSuit, trumpSuit);
    final winnerSeat = currentWinner.seatIndex;
    final partnerWinning = _isPartner(state, winnerSeat);

    // Helper to filter to legal cards in the lead suit (when must-follow).
    final inSuit = moves.where((m) => m.card.suit == leadSuit).toList();

    if (mustFollow) {
      // 2nd hand low.
      if (position == 2) {
        return _lowestCardMove(inSuit);
      }
      // 3rd hand high — cheapest card that beats current winner; otherwise low.
      if (position == 3) {
        if (partnerWinning) return _lowestCardMove(inSuit);
        return _lowestWinner(inSuit, currentWinner.card, leadSuit, trumpSuit) ??
            _lowestCardMove(inSuit);
      }
      // 4th hand — minimum to win if possible, otherwise smallest.
      if (partnerWinning) return _lowestCardMove(inSuit);
      return _lowestWinner(inSuit, currentWinner.card, leadSuit, trumpSuit) ??
          _lowestCardMove(inSuit);
    }

    // Out of suit — consider ruffing or discarding.
    final canRuff = trumpSuit != null &&
        moves.any((m) => m.card.suit == trumpSuit);
    if (canRuff && !partnerWinning) {
      final trumps = moves.where((m) => m.card.suit == trumpSuit).toList();
      // Smallest trump that overtakes the current trump (if any) — else smallest.
      final currentTrump = currentWinner.card.suit == trumpSuit
          ? currentWinner.card
          : null;
      if (currentTrump != null) {
        final winners = trumps
            .where((m) => m.card.rank.index > currentTrump.rank.index)
            .toList();
        if (winners.isNotEmpty) return _lowestCardMove(winners);
        // Can't overtrump — don't waste a trump, discard small instead.
      } else {
        return _lowestCardMove(trumps);
      }
    }

    // Discard a small card from longest non-trump suit.
    final discards = moves
        .where((m) => trumpSuit == null || m.card.suit != trumpSuit)
        .toList();
    if (discards.isNotEmpty) {
      final hand = state.hands[state.currentPlayerId]!;
      final lengths = _suitLengths(hand);
      Suit? longest;
      var longestLen = -1;
      for (final s in Suit.values) {
        if (s == trumpSuit) continue;
        final len = lengths[s] ?? 0;
        if (len > longestLen &&
            discards.any((m) => m.card.suit == s)) {
          longestLen = len;
          longest = s;
        }
      }
      if (longest != null) {
        final fromLong =
            discards.where((m) => m.card.suit == longest).toList();
        return _lowestCardMove(fromLong);
      }
      return _lowestCardMove(discards);
    }

    return _lowestCardMove(moves);
  }

  // ── Card-play helpers ─────────────────────────────────────────────────────

  TrickCard _currentWinner(
      List<TrickCard> trick, Suit leadSuit, Suit? trumpSuit) {
    var winner = trick.first;
    for (var i = 1; i < trick.length; i++) {
      final tc = trick[i];
      if (_beats(tc.card, winner.card, leadSuit, trumpSuit)) winner = tc;
    }
    return winner;
  }

  bool _beats(PlayingCard a, PlayingCard b, Suit leadSuit, Suit? trumpSuit) {
    final aTrump = trumpSuit != null && a.suit == trumpSuit;
    final bTrump = trumpSuit != null && b.suit == trumpSuit;
    if (aTrump && !bTrump) return true;
    if (!aTrump && bTrump) return false;
    if (aTrump && bTrump) return a.rank.index > b.rank.index;
    if (a.suit == leadSuit && b.suit != leadSuit) return true;
    if (a.suit != leadSuit && b.suit == leadSuit) return false;
    if (a.suit == leadSuit && b.suit == leadSuit) {
      return a.rank.index > b.rank.index;
    }
    return false;
  }

  BridgePlayCardMove? _lowestWinner(
    List<BridgePlayCardMove> moves,
    PlayingCard target,
    Suit leadSuit,
    Suit? trumpSuit,
  ) {
    final winners =
        moves.where((m) => _beats(m.card, target, leadSuit, trumpSuit)).toList();
    if (winners.isEmpty) return null;
    return _lowestCardMove(winners);
  }

  BridgePlayCardMove _lowestCardMove(List<BridgePlayCardMove> moves) {
    return moves
        .reduce((a, b) => a.card.rank.index <= b.card.rank.index ? a : b);
  }

  bool _isPartner(BridgeState state, int seat) {
    final mySeat = state.playerOrder.indexOf(state.currentPlayerId!);
    return seat % 2 == mySeat % 2 && seat != mySeat;
  }

  bool _isDeclarerSide(BridgeState state, String pid) {
    final contract = state.contract;
    if (contract == null) return false;
    final declarerSeat = contract.declarerSeat;
    final mySeat = state.playerOrder.indexOf(pid);
    return mySeat % 2 == declarerSeat % 2;
  }

  Set<Suit> _partnerBidSuits(BridgeState state) {
    final mySeat = state.playerOrder.indexOf(playerId);
    final partnerSeat = (mySeat + 2) % 4;
    final result = <Suit>{};
    for (final c in state.auctionHistory) {
      if (!c.isBid) continue;
      if (c.seatIndex != partnerSeat) continue;
      final suit = c.denomination?.suit;
      if (suit != null) result.add(suit);
    }
    return result;
  }

  Set<Suit> _declaringSideBidSuits(BridgeState state, int declarerSeat) {
    if (declarerSeat < 0) return const {};
    final declarerParity = declarerSeat % 2;
    final result = <Suit>{};
    for (final c in state.auctionHistory) {
      if (!c.isBid) continue;
      if (c.seatIndex % 2 != declarerParity) continue;
      final suit = c.denomination?.suit;
      if (suit != null) result.add(suit);
    }
    return result;
  }

  int _trumpsPlayed(BridgeState state, Suit trumpSuit) {
    // Count trumps still in known hands + already-played cards.
    var played = 0;
    const initialTotal = 13;
    var remaining = 0;
    for (final hand in state.hands.values) {
      remaining += hand.cardsOfSuit(trumpSuit).length;
    }
    played = initialTotal - remaining;
    return played;
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║                              HELPERS                                     ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  /// High-card points (A=4, K=3, Q=2, J=1).
  static int hcpOfHand(Hand hand) {
    var hcp = 0;
    for (final card in hand.cards) {
      hcp += switch (card.rank) {
        Rank.ace => 4,
        Rank.king => 3,
        Rank.queen => 2,
        Rank.jack => 1,
        _ => 0,
      };
    }
    return hcp;
  }

  static Map<Suit, int> _suitLengths(Hand hand) {
    final result = {for (final s in Suit.values) s: 0};
    for (final card in hand.cards) {
      result[card.suit] = (result[card.suit] ?? 0) + 1;
    }
    return result;
  }

  /// Balanced = no void or singleton, at most one doubleton.
  /// Standard SAYC balanced shapes: 4-3-3-3, 4-4-3-2, 5-3-3-2.
  static bool _isBalanced(Map<Suit, int> lengths) {
    final counts = lengths.values.toList()..sort();
    if (counts.first < 2) return false;
    var doubletons = 0;
    for (final c in counts) {
      if (c == 2) doubletons++;
      if (c > 5) return false; // no 6+ suit in a balanced hand
    }
    return doubletons <= 1;
  }

  static int _distributionPoints(Map<Suit, int> lengths) {
    var pts = 0;
    for (final len in lengths.values) {
      if (len == 0) pts += 3;
      if (len == 1) pts += 2;
      if (len == 2) pts += 1;
    }
    return pts;
  }

  /// A suit has decent quality if it contains 2 of (A,K,Q) or 3 of (A,K,Q,J,10).
  bool _suitHasDecentQuality(Hand hand, Suit suit) {
    final ranks = hand.cardsOfSuit(suit).map((c) => c.rank).toSet();
    final top3 = {Rank.ace, Rank.king, Rank.queen};
    final top5 = {Rank.ace, Rank.king, Rank.queen, Rank.jack, Rank.ten};
    final hits3 = ranks.intersection(top3).length;
    final hits5 = ranks.intersection(top5).length;
    return hits3 >= 2 || hits5 >= 3;
  }

  bool _supportsUnbidSuits(Suit oppSuit, Map<Suit, int> lengths) {
    for (final s in Suit.values) {
      if (s == oppSuit) continue;
      if ((lengths[s] ?? 0) < 3) return false;
    }
    return true;
  }

  BridgeBidMove? _firstBidMatching(
      List<BridgeMove> moves, int level, BridgeDenomination denom) {
    for (final m in moves) {
      if (m is BridgeBidMove && m.level == level && m.denomination == denom) {
        return m;
      }
    }
    return null;
  }

  BridgePlayCardMove? _moveForCard(
      List<BridgePlayCardMove> moves, PlayingCard card) {
    for (final m in moves) {
      if (m.card == card) return m;
    }
    return null;
  }

  BridgeMove _passOrFirst(List<BridgeMove> moves) {
    final pass = moves.whereType<BridgePassMove>().firstOrNull;
    return pass ?? moves.first;
  }

  AuctionCall? _highestBid(List<AuctionCall> history) {
    AuctionCall? best;
    for (final c in history) {
      if (!c.isBid) continue;
      if (best == null) {
        best = c;
        continue;
      }
      if (c.level! > best.level! ||
          (c.level == best.level! &&
              c.denomination!.index > best.denomination!.index)) {
        best = c;
      }
    }
    return best;
  }

  List<Suit> _suitsByLengthThenStrength(Hand hand, List<Suit> suits) {
    final scored = suits.map((s) {
      final cards = hand.cardsOfSuit(s);
      final length = cards.length;
      final strength = cards.fold<int>(
          0,
          (sum, c) =>
              sum +
              switch (c.rank) {
                Rank.ace => 4,
                Rank.king => 3,
                Rank.queen => 2,
                Rank.jack => 1,
                _ => 0,
              });
      return (s, length, strength);
    }).toList()
      ..sort((a, b) {
        final byLen = b.$2.compareTo(a.$2);
        if (byLen != 0) return byLen;
        return b.$3.compareTo(a.$3);
      });
    return scored.map((t) => t.$1).toList();
  }

  bool _holdsBoth(List<PlayingCard> cards, Rank a, Rank b) {
    final ranks = cards.map((c) => c.rank).toSet();
    return ranks.contains(a) && ranks.contains(b);
  }

  BridgeDenomination _denomForSuit(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return BridgeDenomination.clubs;
      case Suit.diamonds:
        return BridgeDenomination.diamonds;
      case Suit.hearts:
        return BridgeDenomination.hearts;
      case Suit.spades:
        return BridgeDenomination.spades;
    }
  }
}

extension _ReverseFirstOrNull<T> on Iterable<T> {
  T? get reversedOrNull {
    T? last;
    for (final e in this) {
      last = e;
    }
    return last;
  }
}
