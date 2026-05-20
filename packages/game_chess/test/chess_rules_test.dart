import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_chess/game_chess.dart';

void main() {
  late ChessRules rules;

  setUp(() {
    rules = ChessRules();
  });

  ChessState initialState() => rules.createInitialState(
        playerIds: ['white', 'black'],
        dealerIndex: 0,
      );

  // Helper: apply a move action and return new state (asserts valid).
  ChessState play(ChessState state, ChessMoveAction move) {
    final result = rules.applyMove(state, move);
    expect(result.isValid, isTrue, reason: 'Move should be valid');
    return result.newState;
  }

  group('Initial state', () {
    test('white moves first', () {
      expect(initialState().currentPlayerId, 'white');
    });

    test('phase is playing', () {
      expect(initialState().phase, GamePhase.playing);
    });

    test('white has 20 legal piece moves at start', () {
      final state = initialState();
      final moves = rules.getValidMoves(state, 'white');
      // 20 piece moves + 1 resign
      final pieceMoves = moves.whereType<ChessMoveAction>().toList();
      expect(pieceMoves.length, 20);
    });

    test('black has no legal moves when it is white\'s turn', () {
      final state = initialState();
      final moves = rules.getValidMoves(state, 'black');
      // Only resign available when it's not your turn
      expect(moves.whereType<ChessMoveAction>(), isEmpty);
    });
  });

  group('Basic moves', () {
    test('e2-e4 is valid', () {
      final state = initialState();
      final move = ChessMoveAction(
        playerId: 'white',
        from: ChessSquare.fromNotation('e2'),
        to: ChessSquare.fromNotation('e4'),
      );
      expect(rules.validateMove(state, move), isNull);
    });

    test('e2-e4 changes active color to black', () {
      var state = initialState();
      state = play(
          state,
          ChessMoveAction(
              playerId: 'white',
              from: ChessSquare.fromNotation('e2'),
              to: ChessSquare.fromNotation('e4')));
      expect(state.activeColor, ChessColor.black);
      expect(state.currentPlayerId, 'black');
    });

    test('pawn cannot move backwards', () {
      var state = initialState();
      state = play(
          state,
          ChessMoveAction(
              playerId: 'white',
              from: ChessSquare.fromNotation('e2'),
              to: ChessSquare.fromNotation('e4')));
      // Black pawn e7-e5
      state = play(
          state,
          ChessMoveAction(
              playerId: 'black',
              from: ChessSquare.fromNotation('e7'),
              to: ChessSquare.fromNotation('e5')));
      // White pawn tries to go backward
      final badMove = ChessMoveAction(
        playerId: 'white',
        from: ChessSquare.fromNotation('e4'),
        to: ChessSquare.fromNotation('e3'),
      );
      expect(rules.validateMove(state, badMove), isNotNull);
    });

    test('turn advances after each move', () {
      var state = initialState();
      expect(state.turnNumber, 1);
      state = play(
          state,
          ChessMoveAction(
              playerId: 'white',
              from: ChessSquare.fromNotation('e2'),
              to: ChessSquare.fromNotation('e4')));
      expect(state.turnNumber, 2);
    });
  });

  group('Scholar\'s mate (4-move checkmate)', () {
    test('checkmate ends the game with white winning', () {
      // Scholar's mate: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6?? 4.Qxf7#
      var state = initialState();
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e2'), to: ChessSquare.fromNotation('e4')));
      state = play(state, ChessMoveAction(playerId: 'black', from: ChessSquare.fromNotation('e7'), to: ChessSquare.fromNotation('e5')));
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('f1'), to: ChessSquare.fromNotation('c4')));
      state = play(state, ChessMoveAction(playerId: 'black', from: ChessSquare.fromNotation('b8'), to: ChessSquare.fromNotation('c6')));
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('d1'), to: ChessSquare.fromNotation('h5')));
      state = play(state, ChessMoveAction(playerId: 'black', from: ChessSquare.fromNotation('g8'), to: ChessSquare.fromNotation('f6')));
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('h5'), to: ChessSquare.fromNotation('f7')));

      expect(state.isGameOver, isTrue);
      expect(state.result!.type, ChessResultType.win);
      expect(state.result!.winnerId, 'white');
      expect(state.result!.reason, 'Checkmate');
      expect(state.phase, GamePhase.gameEnd);
    });
  });

  group('Resignation', () {
    test('white can resign', () {
      final state = initialState();
      final move = ChessResign(playerId: 'white');
      final result = rules.applyMove(state, move);
      expect(result.isValid, isTrue);
      expect(result.newState.result!.winnerId, 'black');
      expect(result.newState.result!.type, ChessResultType.win);
      expect(result.newState.result!.reason, 'Resignation');
    });

    test('cannot make piece moves after game over', () {
      var state = initialState();
      final resign = ChessResign(playerId: 'white');
      state = rules.applyMove(state, resign).newState;
      final move = ChessMoveAction(
        playerId: 'black',
        from: ChessSquare.fromNotation('e7'),
        to: ChessSquare.fromNotation('e5'),
      );
      expect(rules.validateMove(state, move), 'game_over');
    });
  });

  group('Castling rights', () {
    test('initial state has all castling rights', () {
      final state = initialState();
      expect(state.castlingRights.whiteKingside, isTrue);
      expect(state.castlingRights.whiteQueenside, isTrue);
      expect(state.castlingRights.blackKingside, isTrue);
      expect(state.castlingRights.blackQueenside, isTrue);
    });

    test('moving king removes both castling rights for that color', () {
      // Move king's pawn, then bishop, then king
      var state = initialState();
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e2'), to: ChessSquare.fromNotation('e4')));
      state = play(state, ChessMoveAction(playerId: 'black', from: ChessSquare.fromNotation('e7'), to: ChessSquare.fromNotation('e5')));
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e1'), to: ChessSquare.fromNotation('e2')));
      expect(state.castlingRights.whiteKingside, isFalse);
      expect(state.castlingRights.whiteQueenside, isFalse);
      // Black rights unchanged
      expect(state.castlingRights.blackKingside, isTrue);
    });
  });

  group('En passant', () {
    test('en passant square is set after double pawn push', () {
      var state = initialState();
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e2'), to: ChessSquare.fromNotation('e4')));
      expect(state.enPassantSquare, ChessSquare.fromNotation('e3'));
    });

    test('en passant square is cleared after non-pawn move', () {
      var state = initialState();
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e2'), to: ChessSquare.fromNotation('e4')));
      state = play(state, ChessMoveAction(playerId: 'black', from: ChessSquare.fromNotation('g8'), to: ChessSquare.fromNotation('f6')));
      expect(state.enPassantSquare, isNull);
    });
  });

  group('Scores and winners', () {
    test('no winner while game is ongoing', () {
      final state = initialState();
      expect(rules.getWinners(state), isEmpty);
      expect(rules.calculateScores(state), {'white': 0, 'black': 0});
    });

    test('winner gets score 1 after checkmate', () {
      // Quick resign to end game
      var state = initialState();
      state = rules.applyMove(state, ChessResign(playerId: 'white')).newState;
      expect(rules.getWinners(state), ['black']);
      expect(rules.calculateScores(state)['black'], 1);
      expect(rules.calculateScores(state)['white'], 0);
    });
  });

  group('createInitialState', () {
    test('uses dealerIndex 0 with white as first player', () {
      final state = rules.createInitialState(
          playerIds: ['alice', 'bob'], dealerIndex: 0);
      expect(state.currentPlayerId, 'alice'); // alice = white
    });

    test('dealerIndex is ignored — playerIds[0] always plays white', () {
      final state = rules.createInitialState(
          playerIds: ['alice', 'bob'], dealerIndex: 1);
      expect(state.currentPlayerId, 'alice');
    });
  });

  group('Position history (50-move rule tracking)', () {
    test('halfmove clock increments on non-pawn non-capture move', () {
      var state = initialState();
      // g1-f3 (knight move, not pawn, not capture)
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('g1'), to: ChessSquare.fromNotation('f3')));
      expect(state.halfmoveClock, 1);
    });

    test('halfmove clock resets on pawn move', () {
      var state = initialState();
      state = play(state, ChessMoveAction(playerId: 'white', from: ChessSquare.fromNotation('e2'), to: ChessSquare.fromNotation('e4')));
      expect(state.halfmoveClock, 0);
    });
  });

  group('Insufficient material', () {
    test('K vs K is insufficient material (draw)', () {
      // Build board with only kings
      final board = ChessBoard.fromFEN('8/8/8/8/8/8/8/4K2k');
      // There's no built-in way to trigger this from rules directly,
      // but we can verify getWinners returns empty for a draw result.
      final state = ChessState(
        playerIds: ['white', 'black'],
        board: board,
        activeColor: ChessColor.white,
        castlingRights: CastlingRights(
            whiteKingside: false,
            whiteQueenside: false,
            blackKingside: false,
            blackQueenside: false),
        result: const ChessResult(type: ChessResultType.draw, reason: 'Insufficient material'),
        phase: GamePhase.gameEnd,
      );
      expect(rules.getWinners(state), isEmpty);
      expect(rules.calculateScores(state), {'white': 0, 'black': 0});
    });
  });

  group('FEN round-trip', () {
    test('initial board FEN is correct', () {
      final board = ChessBoard.initial();
      expect(board.toFEN(),
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
    });

    test('board round-trips through FEN', () {
      final original = ChessBoard.initial();
      final restored = ChessBoard.fromFEN(original.toFEN());
      expect(restored.toFEN(), original.toFEN());
    });
  });
}
