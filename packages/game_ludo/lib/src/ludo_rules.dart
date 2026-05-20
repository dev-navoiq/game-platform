import 'dart:math';

import 'package:game_core/game_core.dart';

import 'ludo_board.dart';
import 'ludo_config.dart';
import 'ludo_move.dart';
import 'ludo_state.dart';
import 'ludo_token.dart';

class LudoRules extends GameRules<LudoState, LudoMove> {
  LudoConfig _config;
  final Random _random;

  LudoRules([LudoConfig? config, Random? random])
      : _config = config ?? const LudoConfig(playerCount: 4),
        _random = random ?? Random();

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 4;

  @override
  List<int> get validPlayerCounts => const [2, 3, 4];

  @override
  void applyServerConfig(Map<String, dynamic> config) {
    _config = LudoConfig.fromJson(config);
  }

  @override
  LudoState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,
    Map<String, dynamic>? serverConfig,
  }) {
    assert(playerIds.length >= 2 && playerIds.length <= 4,
        'Ludo requires 2-4 players');
    if (serverConfig != null) applyServerConfig(serverConfig);
    // dealerIndex = first player index
    final orderedIds = [
      ...playerIds.sublist(dealerIndex),
      ...playerIds.sublist(0, dealerIndex),
    ];
    return LudoState.initial(
      playerIds: orderedIds,
      tokensPerPlayer: _config.tokensPerPlayer,
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  @override
  String? validateMove(LudoState state, LudoMove move) {
    if (state.isGameOver) return 'game_over';
    if (state.currentPlayerId != move.playerId) return 'not_your_turn';

    if (move is LudoRollDice) {
      if (state.lastRoll != null) return 'already_rolled';
    } else if (move is LudoMoveToken) {
      if (state.lastRoll == null) return 'must_roll_first';
      final token = _findToken(state, move.tokenId);
      if (token == null) return 'token_not_found';
      if (token.color != state.playerColors[move.playerId]) {
        return 'not_your_token';
      }
      final color = state.playerColors[move.playerId]!;
      final newPos = _calculateNewPosition(token, move.steps, color);
      if (newPos == null) return 'invalid_token_move';
    } else if (move is LudoPass) {
      if (state.lastRoll == null) return 'must_roll_first';
      // Pass is only valid when no token moves are possible
      final tokenMoves = _validTokenMoves(state, move.playerId);
      if (tokenMoves.isNotEmpty) return 'token_moves_available';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Valid moves
  // ---------------------------------------------------------------------------

  @override
  List<LudoMove> getValidMoves(LudoState state, String playerId) {
    if (state.isGameOver) return [];
    if (state.currentPlayerId != playerId) return [];

    if (state.lastRoll == null) {
      return [LudoRollDice(playerId: playerId)];
    }

    final tokenMoves = _validTokenMoves(state, playerId);
    if (tokenMoves.isNotEmpty) return tokenMoves;
    return [LudoPass(playerId: playerId)];
  }

  List<LudoMoveToken> _validTokenMoves(LudoState state, String playerId) {
    final roll = state.lastRoll!;
    final color = state.playerColors[playerId]!;
    final moves = <LudoMoveToken>[];

    for (final token in state.tokensFor(playerId)) {
      if (token.isFinished) continue;
      final newPos = _calculateNewPosition(token, roll, color);
      if (newPos != null) {
        moves.add(LudoMoveToken(
            playerId: playerId, tokenId: token.id, steps: roll));
      }
    }
    return moves;
  }

  // ---------------------------------------------------------------------------
  // Apply move
  // ---------------------------------------------------------------------------

  @override
  MoveResult<LudoState> applyMove(LudoState state, LudoMove move) {
    final error = validateMove(state, move);
    if (error != null) return MoveResult.invalid(error: error);

    return switch (move) {
      LudoRollDice() => _applyRoll(state, move),
      LudoMoveToken() => _applyTokenMove(state, move),
      LudoPass() => _applyPass(state, move),
    };
  }

  MoveResult<LudoState> _applyRoll(LudoState state, LudoRollDice move) {
    final roll = _random.nextInt(6) + 1;

    // Three consecutive sixes → lose the turn
    if (roll == 6 && state.consecutiveSixes >= 2) {
      final nextIdx = _nextActivePlayerIndex(state, state.currentPlayerIndex);
      final newState = state.copyWith(
        clearRoll: true,
        consecutiveSixes: 0,
        canRollAgain: false,
        currentPlayerIndex: nextIdx,
        turnNumber: state.turnNumber + 1,
      );
      return MoveResult.valid(newState: newState, events: [
        GameEvent(type: GameEventType.diceRolled,
            playerId: move.playerId,
            data: {'roll': roll, 'turnLost': true}),
      ]);
    }

    final newState = state.copyWith(
      lastRoll: roll,
      consecutiveSixes: roll == 6 ? state.consecutiveSixes + 1 : 0,
      canRollAgain: roll == 6 && _config.doubleRollOnSix,
    );
    return MoveResult.valid(newState: newState, events: [
      GameEvent(type: GameEventType.diceRolled,
          playerId: move.playerId,
          data: {'roll': roll}),
    ]);
  }

  MoveResult<LudoState> _applyTokenMove(
      LudoState state, LudoMoveToken move) {
    final token = _findToken(state, move.tokenId)!;
    final color = state.playerColors[move.playerId]!;
    final newPos = _calculateNewPosition(token, move.steps, color)!;

    var tokens = List<LudoToken>.from(state.tokens);
    final events = <GameEvent>[];

    // Capture opponents on non-safe main-track squares
    if (newPos.zone == LudoZone.main &&
        _config.safeSquaresEnabled &&
        !newPos.isSafe) {
      for (var i = 0; i < tokens.length; i++) {
        final other = tokens[i];
        if (other.color == token.color) continue;
        if (other.position.zone == LudoZone.main &&
            other.position.index == newPos.index) {
          tokens[i] = other.sendHome();
          events.add(GameEvent(
              type: GameEventType.pieceCaptured,
              playerId: move.playerId,
              data: {'capturedTokenId': other.id}));
        }
      }
    }

    // Move the token
    final tokenIdx = tokens.indexWhere((t) => t.id == token.id);
    tokens[tokenIdx] = token.moveTo(newPos);

    events.add(GameEvent(
        type: GameEventType.pieceMoved,
        playerId: move.playerId,
        data: {'tokenId': token.id, 'to': newPos.toString()}));

    // Check finish
    final finishedPlayers = List<String>.from(state.finishedPlayers);
    String? winnerId = state.winnerId;
    var phase = state.phase;

    final updatedState = state.copyWith(tokens: tokens);
    if (_hasPlayerFinished(updatedState, move.playerId) &&
        !finishedPlayers.contains(move.playerId)) {
      finishedPlayers.add(move.playerId);
      if (finishedPlayers.length == 1) {
        winnerId = move.playerId;
        phase = GamePhase.gameEnd;
        events.add(GameEvent(
            type: GameEventType.gameEnded,
            data: {'winnerId': winnerId}));
      }
    }

    // Next player
    var nextIdx = state.currentPlayerIndex;
    if (!state.canRollAgain) {
      nextIdx = _nextActivePlayerIndex(state, state.currentPlayerIndex);
    }

    final newState = state.copyWith(
      tokens: tokens,
      clearRoll: true,
      consecutiveSixes: state.canRollAgain ? state.consecutiveSixes : 0,
      canRollAgain: false,
      currentPlayerIndex: nextIdx,
      finishedPlayers: finishedPlayers,
      winnerId: winnerId,
      phase: phase,
      turnNumber: state.turnNumber + 1,
    );
    return MoveResult.valid(newState: newState, events: events);
  }

  MoveResult<LudoState> _applyPass(LudoState state, LudoPass move) {
    final nextIdx = _nextActivePlayerIndex(state, state.currentPlayerIndex);
    final newState = state.copyWith(
      clearRoll: true,
      consecutiveSixes: 0,
      canRollAgain: false,
      currentPlayerIndex: nextIdx,
      turnNumber: state.turnNumber + 1,
    );
    return MoveResult.valid(newState: newState);
  }

  // ---------------------------------------------------------------------------
  // Position calculation
  // ---------------------------------------------------------------------------

  LudoPosition? _calculateNewPosition(
      LudoToken token, int steps, LudoColor color) {
    switch (token.position.zone) {
      case LudoZone.home:
        if (steps != 6) return null;
        return LudoPosition.main(LudoPosition.startPosition(color));

      case LudoZone.main:
        final current = token.position.index;
        final start = LudoPosition.startPosition(color);
        final entry = LudoPosition.homeStretchEntry(color);
        // Use distance-from-start to reliably detect passing the home stretch
        // entry (handles the case where token starts exactly at the entry).
        final distFromStart =
            _distanceTo(start, current, LudoPosition.mainTrackLength);
        final entryDist =
            _distanceTo(start, entry, LudoPosition.mainTrackLength);
        final totalDist = distFromStart + steps;

        if (totalDist > entryDist) {
          final stepsAfterEntry = totalDist - entryDist;
          if (stepsAfterEntry <= LudoPosition.homeStretchLength) {
            return LudoPosition.homeStretch(color, stepsAfterEntry - 1);
          } else if (stepsAfterEntry == LudoPosition.homeStretchLength + 1) {
            return LudoPosition.finish(color);
          }
          return null; // Overshot
        }
        return LudoPosition.main((current + steps) % LudoPosition.mainTrackLength);

      case LudoZone.homeStretch:
        final newIndex = token.position.index + steps;
        if (newIndex < LudoPosition.homeStretchLength) {
          return LudoPosition.homeStretch(color, newIndex);
        } else if (newIndex == LudoPosition.homeStretchLength) {
          return LudoPosition.finish(color);
        }
        if (_config.requireExactFinish) return null; // Overshot
        return LudoPosition.finish(color); // Lenient variant

      case LudoZone.finish:
        return null; // Already finished
    }
  }

  int _distanceTo(int from, int to, int trackLength) {
    if (to >= from) return to - from;
    return trackLength - from + to;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  LudoToken? _findToken(LudoState state, String tokenId) =>
      state.tokens.where((t) => t.id == tokenId).firstOrNull;

  bool _hasPlayerFinished(LudoState state, String playerId) =>
      state.tokensFor(playerId).every((t) => t.isFinished);

  int _nextActivePlayerIndex(LudoState state, int current) {
    final n = state.playerIds.length;
    var next = (current + 1) % n;
    // Skip players who have finished (but keep cycling until someone active)
    var safety = 0;
    while (state.finishedPlayers.contains(state.playerIds[next]) &&
        safety < n) {
      next = (next + 1) % n;
      safety++;
    }
    return next;
  }

  // ---------------------------------------------------------------------------
  // Game-over queries
  // ---------------------------------------------------------------------------

  @override
  bool isGameOver(LudoState state) => state.isGameOver;

  @override
  List<String> getWinners(LudoState state) {
    if (state.winnerId != null) return [state.winnerId!];
    return [];
  }

  @override
  Map<String, int> calculateScores(LudoState state) {
    return {
      for (final id in state.playerIds)
        id: state.finishedPlayers.contains(id)
            ? state.playerIds.length - state.finishedPlayers.indexOf(id)
            : 0
    };
  }

  @override
  String? getNextPlayer(LudoState state, List<String> playerIds) {
    if (state.isGameOver) return null;
    return state.currentPlayerId;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
