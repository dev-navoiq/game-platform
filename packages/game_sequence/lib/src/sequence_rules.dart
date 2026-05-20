import 'dart:math' show max, min;

import 'package:game_core/game_core.dart';

import 'sequence_board.dart';
import 'sequence_config.dart';
import 'sequence_move.dart';
import 'sequence_state.dart';

class SequenceRules extends GameRules<SequenceState, SequenceMove> {
  SequenceConfig _config;

  SequenceRules([SequenceConfig? config])
      : _config = config ?? const SequenceConfig(playerCount: 2);

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 4;

  @override
  List<int> get validPlayerCounts => const [2, 3, 4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _config = SequenceConfig.fromJson(config);
  }

  @override
  SequenceState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    assert(playerIds.length >= 2 && playerIds.length <= 4,
        'Sequence requires 2-4 players');
    if (serverConfig != null) applyServerConfig(serverConfig);

    // Two standard 52-card decks, shuffle together, remove Jacks (they're wild)
    var deckCards = [...Deck.standard52().cards, ...Deck.standard52().cards]
        .where((c) => c.rank != Rank.jack)
        .toList();
    deckCards.shuffle();

    final colors = [ChipColor.red, ChipColor.blue, ChipColor.green];
    final playerColors = <String, ChipColor>{};
    final playerHands = <String, List<PlayingCard>>{};

    // Dealer goes last → start with player after dealer
    final orderedIds = [
      ...playerIds.sublist((dealerIndex + 1) % playerIds.length),
      ...playerIds.sublist(0, (dealerIndex + 1) % playerIds.length),
    ];

    for (var i = 0; i < orderedIds.length; i++) {
      playerColors[orderedIds[i]] = colors[i % colors.length];
      playerHands[orderedIds[i]] = deckCards.sublist(
          i * _config.handSize, (i + 1) * _config.handSize);
    }

    final drawPile =
        deckCards.sublist(orderedIds.length * _config.handSize);

    return SequenceState(
      playerIds: orderedIds,
      board: SequenceBoard.empty(),
      playerHands: playerHands,
      playerColors: playerColors,
      sequenceCount: {
        ChipColor.red: 0,
        ChipColor.blue: 0,
        ChipColor.green: 0,
      },
      drawPile: drawPile,
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  @override
  String? validateMove(SequenceState state, SequenceMove move) {
    if (state.isGameOver) return 'game_over';
    if (state.currentPlayerId != move.playerId) return 'not_your_turn';

    final hand = state.playerHands[move.playerId]!;
    if (!hand.contains(move.card)) return 'card_not_in_hand';

    final color = state.playerColors[move.playerId]!;

    if (move.isRemoval) {
      if (!_isOneEyedJack(move.card)) return 'not_one_eyed_jack';
      if (!_config.allowRemoval) return 'removal_disabled';
      final cell = state.board.cellAt(move.row, move.col);
      if (cell.chip == null) return 'no_chip_to_remove';
      if (cell.chip == color) return 'cannot_remove_own_chip';
      if (cell.isChipLocked) return 'chip_locked_in_sequence';
    } else {
      if (state.board.isOccupied(move.row, move.col)) return 'square_occupied';

      if (_isTwoEyedJack(move.card)) {
        // Two-eyed jack can place anywhere empty — valid
      } else {
        // Regular card — must match the board square's card
        final cell = state.board.cellAt(move.row, move.col);
        if (cell.card != move.card) return 'card_mismatch';
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Valid moves
  // ---------------------------------------------------------------------------

  @override
  List<SequenceMove> getValidMoves(SequenceState state, String playerId) {
    if (state.isGameOver) return [];
    if (state.currentPlayerId != playerId) return [];

    final hand = state.playerHands[playerId]!;
    final color = state.playerColors[playerId]!;
    final moves = <SequenceMove>[];

    for (final card in hand) {
      if (_isTwoEyedJack(card)) {
        // Can place anywhere empty
        for (var r = 0; r < SequenceBoard.size; r++) {
          for (var c = 0; c < SequenceBoard.size; c++) {
            if (!state.board.isOccupied(r, c)) {
              moves.add(SequenceMove(
                  playerId: playerId, card: card, row: r, col: c));
            }
          }
        }
      } else if (_isOneEyedJack(card) && _config.allowRemoval) {
        // Can remove any opponent's non-locked chip
        for (var r = 0; r < SequenceBoard.size; r++) {
          for (var c = 0; c < SequenceBoard.size; c++) {
            final cell = state.board.cellAt(r, c);
            if (cell.chip != null &&
                cell.chip != color &&
                !cell.isChipLocked) {
              moves.add(SequenceMove(
                  playerId: playerId,
                  card: card,
                  row: r,
                  col: c,
                  isRemoval: true));
            }
          }
        }
      } else {
        // Regular card — can play on any matching empty square
        for (final (r, c) in state.board.positionsForCard(card)) {
          if (!state.board.isOccupied(r, c)) {
            moves.add(
                SequenceMove(playerId: playerId, card: card, row: r, col: c));
          }
        }
      }
    }

    return moves;
  }

  // ---------------------------------------------------------------------------
  // Apply move
  // ---------------------------------------------------------------------------

  @override
  MoveResult<SequenceState> applyMove(SequenceState state, SequenceMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    final color = state.playerColors[move.playerId]!;
    var board = state.board;
    var seqCount = Map<ChipColor, int>.from(state.sequenceCount);
    final events = <GameEvent>[];

    if (move.isRemoval) {
      board = board.withoutChip(move.row, move.col);
      events.add(GameEvent(type: GameEventType.pieceCaptured, data: {
        'playerId': move.playerId,
        'row': move.row,
        'col': move.col,
      }));
    } else {
      board = board.withChip(move.row, move.col, color);
      events.add(GameEvent(type: GameEventType.pieceMoved, data: {
        'playerId': move.playerId,
        'row': move.row,
        'col': move.col,
      }));

      // Check for new sequences
      final newSeqs = _findNewSequences(board, move.row, move.col, color);
      for (final seq in newSeqs) {
        board = board.markSequence(seq);
        seqCount[color] = (seqCount[color] ?? 0) + 1;
      }
    }

    // Update hand: remove played card, draw a new one
    final newHands =
        Map<String, List<PlayingCard>>.from(state.playerHands);
    newHands[move.playerId] = List<PlayingCard>.from(
        newHands[move.playerId]!)
      ..remove(move.card);

    final newDrawPile = List<PlayingCard>.from(state.drawPile);
    if (newDrawPile.isNotEmpty) {
      newHands[move.playerId]!.add(newDrawPile.removeAt(0));
    }

    // Check win condition
    String? winnerId;
    var phase = state.phase;
    if ((seqCount[color] ?? 0) >= _config.sequencesToWin) {
      winnerId = move.playerId;
      phase = GamePhase.gameEnd;
      events.add(GameEvent(
          type: GameEventType.gameEnded,
          data: {'winnerId': winnerId, 'reason': 'sequences_complete'}));
    }

    final nextIdx =
        (state.currentPlayerIndex + 1) % state.playerIds.length;

    final newState = state.copyWith(
      board: board,
      playerHands: newHands,
      sequenceCount: seqCount,
      drawPile: newDrawPile,
      currentPlayerIndex: nextIdx,
      winnerId: winnerId,
      phase: phase,
      turnNumber: state.turnNumber + 1,
    );
    return MoveResult.valid(newState: newState, events: events);
  }

  // ---------------------------------------------------------------------------
  // Sequence detection
  // ---------------------------------------------------------------------------

  List<Set<(int, int)>> _findNewSequences(
      SequenceBoard board, int row, int col, ChipColor color) {
    final found = <Set<(int, int)>>[];
    for (final (dr, dc) in [
      (0, 1),  // horizontal
      (1, 0),  // vertical
      (1, 1),  // diagonal down-right
      (1, -1), // diagonal down-left
    ]) {
      final seq = _checkLine(board, row, col, dr, dc, color);
      if (seq != null && !_overlapsExistingSequence(board, seq)) {
        found.add(seq);
      }
    }
    return found;
  }

  Set<(int, int)>? _checkLine(SequenceBoard board, int row, int col, int dr,
      int dc, ChipColor color) {
    // Collect consecutive matching positions centred at (row,col).
    final positions = <(int, int)>[];

    // Walk backwards from (row,col)
    var r = row - dr;
    var c = col - dc;
    while (r >= 0 && r < SequenceBoard.size && c >= 0 && c < SequenceBoard.size) {
      if (!_cellMatchesColor(board, r, c, color)) break;
      positions.insert(0, (r, c));
      r -= dr;
      c -= dc;
    }

    // Add the placed cell
    positions.add((row, col));

    // Walk forwards from (row,col)
    r = row + dr;
    c = col + dc;
    while (r >= 0 && r < SequenceBoard.size && c >= 0 && c < SequenceBoard.size) {
      if (!_cellMatchesColor(board, r, c, color)) break;
      positions.add((r, c));
      r += dr;
      c += dc;
    }

    if (positions.length < 5) return null;

    // Find a window of 5 that includes the placed cell (row, col).
    final placedIdx = positions.indexWhere((p) => p == (row, col));
    final start = max(0, min(placedIdx - 4, positions.length - 5));
    return positions.sublist(start, start + 5).toSet();
  }

  bool _cellMatchesColor(SequenceBoard board, int r, int c, ChipColor color) {
    final cell = board.cellAt(r, c);
    return cell.isCorner || cell.chip == color;
  }

  bool _overlapsExistingSequence(
      SequenceBoard board, Set<(int, int)> newSeq) {
    int sharedLocked = 0;
    for (final pos in newSeq) {
      final (r, c) = pos;
      if (board.cellAt(r, c).isChipLocked) sharedLocked++;
    }
    // A new sequence may share at most ONE locked cell with any existing sequence.
    return sharedLocked > 1;
  }

  // ---------------------------------------------------------------------------
  // Jack helpers
  // ---------------------------------------------------------------------------

  bool _isTwoEyedJack(PlayingCard card) =>
      card.rank == Rank.jack &&
      (card.suit == Suit.diamonds || card.suit == Suit.clubs);

  bool _isOneEyedJack(PlayingCard card) =>
      card.rank == Rank.jack &&
      (card.suit == Suit.hearts || card.suit == Suit.spades);

  // ---------------------------------------------------------------------------
  // Game-over queries
  // ---------------------------------------------------------------------------

  @override
  bool isGameOver(SequenceState state) => state.isGameOver;

  @override
  List<String> getWinners(SequenceState state) {
    if (state.winnerId != null) return [state.winnerId!];
    return [];
  }

  @override
  Map<String, int> calculateScores(SequenceState state) {
    return {
      for (final id in state.playerIds)
        id: (state.sequenceCount[state.playerColors[id]] ?? 0),
    };
  }

  @override
  String? getNextPlayer(SequenceState state, List<String> playerIds) {
    if (state.isGameOver) return null;
    return state.currentPlayerId;
  }
}

