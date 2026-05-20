import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_sequence/game_sequence.dart';

void main() {
  late SequenceRules rules;

  setUp(() {
    rules = SequenceRules(const SequenceConfig(playerCount: 2));
  });

  SequenceState initialState2P() => rules.createInitialState(
        playerIds: ['alice', 'bob'],
        dealerIndex: 0,
      );

  group('Initial state', () {
    test('2 players, each has 7 cards', () {
      final state = initialState2P();
      expect(state.playerHands['alice']!.length, 7);
      expect(state.playerHands['bob']!.length, 7);
    });

    test('board has all cells unoccupied (except corners)', () {
      final state = initialState2P();
      var nonCornerOccupied = 0;
      for (var r = 0; r < 10; r++) {
        for (var c = 0; c < 10; c++) {
          final cell = state.board.cellAt(r, c);
          if (!cell.isCorner && cell.chip != null) nonCornerOccupied++;
        }
      }
      expect(nonCornerOccupied, 0);
    });

    test('player after dealer goes first', () {
      // dealerIndex=0 → alice is dealer → bob goes first
      expect(initialState2P().currentPlayerId, 'bob');
    });

    test('phase is playing', () {
      expect(initialState2P().phase, GamePhase.playing);
    });
  });

  group('Card placement', () {
    test('can play a card matching a board square', () {
      final state = initialState2P();
      // Find a card in bob's hand that has a matching empty position on board
      final bobsHand = state.playerHands['bob']!;
      SequenceMove? move;
      for (final card in bobsHand) {
        final positions = state.board.positionsForCard(card);
        for (final (r, c) in positions) {
          if (!state.board.isOccupied(r, c)) {
            move = SequenceMove(playerId: 'bob', card: card, row: r, col: c);
            break;
          }
        }
        if (move != null) break;
      }
      expect(move, isNotNull, reason: 'Bob should have a valid regular move');
      expect(rules.validateMove(state, move!), isNull);
    });

    test('playing a card advances to next player', () {
      final state = initialState2P();
      final bobsHand = state.playerHands['bob']!;
      for (final card in bobsHand) {
        final positions = state.board.positionsForCard(card);
        for (final (r, c) in positions) {
          if (!state.board.isOccupied(r, c)) {
            final move =
                SequenceMove(playerId: 'bob', card: card, row: r, col: c);
            final result = rules.applyMove(state, move);
            expect(result.isValid, isTrue);
            expect(result.newState.currentPlayerId, 'alice');
            expect(result.newState.playerHands['bob']!.length, 7,
                reason: 'Hand size stays 7 after drawing');
            return;
          }
        }
      }
      fail('No valid move found for bob');
    });

    test('cannot play card not in hand', () {
      final state = initialState2P();
      // Find a card NOT in bob's hand but on the board
      for (var r = 0; r < 10; r++) {
        for (var c = 0; c < 10; c++) {
          final cell = state.board.cellAt(r, c);
          if (cell.card != null &&
              !state.playerHands['bob']!.contains(cell.card)) {
            final move = SequenceMove(
                playerId: 'bob', card: cell.card!, row: r, col: c);
            expect(rules.validateMove(state, move), 'card_not_in_hand');
            return;
          }
        }
      }
    });

    test('cannot play on occupied square', () {
      final state = initialState2P();
      // Find bob's first valid move
      for (final card in state.playerHands['bob']!) {
        final positions = state.board.positionsForCard(card);
        for (final (r, c) in positions) {
          if (!state.board.isOccupied(r, c)) {
            // Place a chip
            var s = rules.applyMove(state,
                SequenceMove(playerId: 'bob', card: card, row: r, col: c)).newState;
            // Now try alice to play on the same square
            // Find alice a card that matches (r,c)
            final matchCard = s.board.cellAt(r, c).card;
            if (matchCard != null &&
                s.playerHands['alice']!.contains(matchCard)) {
              final badMove = SequenceMove(
                  playerId: 'alice', card: matchCard, row: r, col: c);
              expect(rules.validateMove(s, badMove), 'square_occupied');
            }
            return;
          }
        }
      }
    });
  });

  group('Two-eyed jack (wild)', () {
    test('two-eyed jack can be placed anywhere empty', () {
      final state = initialState2P();
      // Create a state with a two-eyed jack in bob's hand
      final twoEyedJack = const PlayingCard(Suit.diamonds, Rank.jack);
      final handWithJack = [twoEyedJack, ...state.playerHands['bob']!.take(6)];
      final s = state.copyWith(playerHands: {
        ...state.playerHands,
        'bob': handWithJack,
      });

      // Should be able to play on any empty non-corner square
      final move = SequenceMove(
          playerId: 'bob', card: twoEyedJack, row: 3, col: 3);
      expect(rules.validateMove(s, move), isNull);
    });
  });

  group('Sequence detection', () {
    test('placing 5 chips in a row creates a sequence', () {
      final state = initialState2P();
      // Manually place 4 red chips in a row and then place the 5th
      // Use row 5 columns 1-5 (all hearts)
      var board = state.board;
      for (var c = 1; c <= 4; c++) {
        board = board.withChip(5, c, ChipColor.red);
      }
      final s = state.copyWith(board: board);

      // Now place at (5, 5) — H6 is at row 5 col 5 in the layout
      final cell = s.board.cellAt(5, 5);
      // Find bob's hand with that card (or create state)
      final targetCard = cell.card!;
      final handWithCard = [targetCard, ...s.playerHands['bob']!.take(6)];
      final s2 = s.copyWith(playerHands: {
        ...s.playerHands,
        'bob': handWithCard,
      });

      final move = SequenceMove(
          playerId: 'bob', card: targetCard, row: 5, col: 5);
      final result = rules.applyMove(s2, move);
      expect(result.isValid, isTrue);
      expect(result.newState.sequenceCount[ChipColor.red], 1);
    });

    test('completing 2 sequences wins the 2-player game', () {
      // Give bob 2 completed sequences programmatically
      final state = initialState2P();
      final seqCount = {
        ChipColor.red: 1, // bob already has 1
        ChipColor.blue: 0,
        ChipColor.green: 0,
      };
      var board = state.board;

      // Place 4 red chips in row 1 cols 1-4
      for (var c = 1; c <= 4; c++) {
        board = board.withChip(1, c, ChipColor.red);
      }

      final s = state.copyWith(board: board, sequenceCount: seqCount);

      // Place at (1,5) to complete sequence
      final targetCard = s.board.cellAt(1, 5).card!;
      final handWithCard = [targetCard, ...s.playerHands['bob']!.take(6)];
      final s2 = s.copyWith(playerHands: {
        ...s.playerHands,
        'bob': handWithCard,
      });

      final move = SequenceMove(
          playerId: 'bob', card: targetCard, row: 1, col: 5);
      final result = rules.applyMove(s2, move);
      expect(result.isValid, isTrue);
      expect(result.newState.isGameOver, isTrue);
      expect(result.newState.winnerId, 'bob');
      expect(result.newState.phase, GamePhase.gameEnd);
    });
  });

  group('One-eyed jack (removal)', () {
    test('one-eyed jack removes opponent chip', () {
      final state = initialState2P();
      // Place a blue chip at (3, 3)
      var board = state.board.withChip(3, 3, ChipColor.blue);
      final s = state.copyWith(board: board);

      final oneEyedJack = const PlayingCard(Suit.hearts, Rank.jack);
      final handWithJack = [oneEyedJack, ...s.playerHands['bob']!.take(6)];
      final s2 = s.copyWith(playerHands: {
        ...s.playerHands,
        'bob': handWithJack,
      });

      final move = SequenceMove(
          playerId: 'bob', card: oneEyedJack, row: 3, col: 3, isRemoval: true);
      expect(rules.validateMove(s2, move), isNull);
      final result = rules.applyMove(s2, move);
      expect(result.isValid, isTrue);
      expect(result.newState.board.cellAt(3, 3).chip, isNull);
    });

    test('cannot remove chip that is part of a completed sequence', () {
      final state = initialState2P();
      // Mark (3,3) as locked
      var board = state.board.withChip(3, 3, ChipColor.blue);
      board = board.markSequence({(3, 3), (3, 4), (3, 5), (3, 6), (3, 7)});
      final s = state.copyWith(board: board);

      final oneEyedJack = const PlayingCard(Suit.hearts, Rank.jack);
      final handWithJack = [oneEyedJack, ...s.playerHands['bob']!.take(6)];
      final s2 = s.copyWith(playerHands: {
        ...s.playerHands,
        'bob': handWithJack,
      });

      final move = SequenceMove(
          playerId: 'bob', card: oneEyedJack, row: 3, col: 3, isRemoval: true);
      expect(rules.validateMove(s2, move), 'chip_locked_in_sequence');
    });
  });

  group('Scores', () {
    test('scores equal sequence count per player', () {
      final state = initialState2P();
      final seqCount = {
        ChipColor.red: 1, // bob = red
        ChipColor.blue: 0,
        ChipColor.green: 0,
      };
      final s = state.copyWith(sequenceCount: seqCount);
      final scores = rules.calculateScores(s);
      expect(scores['bob'], 1);
      expect(scores['alice'], 0);
    });
  });

  group('Registry', () {
    test('registerSequence registers the game', () {
      final registry = GameRegistry();
      registerSequence(registry);
      expect(registry.lookup('sequence'), isNotNull);
      expect(registry.lookup('sequence')!.category, GameCategory.boardGame);
    });
  });
}
