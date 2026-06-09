import 'dart:async';
import 'dart:developer' as developer;

import 'package:bot_strategies/bot_strategies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import 'game_provider.dart';
import 'game_session_providers.dart';

/// Info about bots in the current room.
class BotInfo {
  final String id;
  final String difficulty;

  const BotInfo({required this.id, required this.difficulty});
}

/// Provider that holds the list of bot player IDs for the current room.
final roomBotsProvider = StateProvider<List<BotInfo>>((ref) => []);

/// Provider for the bot move controller.
final botMoveControllerProvider = Provider<BotMoveController>((ref) {
  final controller = BotMoveController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Watches game state and auto-plays bot moves when it's a bot's turn.
class BotMoveController {
  final Ref _ref;
  Timer? _moveTimer;
  bool _disposed = false;

  // Cache bot instances by player ID.
  final Map<String, Object> _bots = {};

  // ID of the player whose move is currently pending in [_moveTimer]. Used to
  // ignore duplicate state events that don't actually change whose turn it is
  // (Supabase Realtime occasionally re-delivers the same row). Without this
  // guard, every redelivery cancels the in-flight timer and the bot's move
  // never fires.
  String? _pendingMovePlayerId;

  // Rules engine for generating valid moves.
  final TwentyNineRules _twentyNineRules = TwentyNineRules();
  final BridgeRules _bridgeRules = BridgeRules();
  final OhHellRules _ohHellRules = OhHellRules();

  BotMoveController(this._ref);

  /// Start watching for bot turns. Call once when game screen loads.
  void startWatching({required String roomId}) {
    _ref.listen<GameState?>(gameStateProvider, (prev, next) {
      if (_disposed || next == null) return;
      _onStateChanged(next, roomId);
    });
    // Race fix: the room-status realtime subscription can navigate to the
    // game screen BEFORE the host's _startGame finishes populating
    // roomBotsProvider. Without this listener, the controller processes the
    // initial state with an empty bots list, silently bails, and never
    // rechecks — leaving the first bot's turn permanently stuck. Re-run
    // _onStateChanged whenever the bot list transitions to non-empty.
    _ref.listen<List<BotInfo>>(roomBotsProvider, (prev, next) {
      if (_disposed) return;
      if ((prev?.isEmpty ?? true) && next.isNotEmpty) {
        final current = _ref.read(gameStateProvider);
        if (current != null) _onStateChanged(current, roomId);
      }
    });
    // The Riverpod listener only fires on FUTURE changes. The host's
    // `_startGame()` already pushed the initial state into the provider
    // before this controller existed, so if a bot is in the first seat
    // up to bid we'd otherwise sit forever waiting for a "change" that
    // never comes. Process the current state immediately to cover that.
    final current = _ref.read(gameStateProvider);
    if (current != null) {
      _onStateChanged(current, roomId);
    }
  }

  void _onStateChanged(GameState state, String roomId) {
    final bots = _ref.read(roomBotsProvider);
    developer.log(
      'state changed: phase=${(state as dynamic).phase} '
      'current=${state.currentPlayerId} '
      'bots=${bots.length} pending=$_pendingMovePlayerId',
      name: 'BotMoveController',
    );

    // Don't auto-trigger newRound — human confirms via RoundEndOverlay.
    if (state is TwentyNineState &&
        (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd)) {
      _cancelPending();
      return;
    }
    if (state is BridgeState &&
        (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd)) {
      _cancelPending();
      return;
    }
    if (state is OhHellState &&
        (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd)) {
      _cancelPending();
      return;
    }

    final currentPlayer = state.currentPlayerId;
    if (currentPlayer == null) {
      _cancelPending();
      return;
    }

    // If the timer is already armed for this same player (duplicate realtime
    // delivery, no real turn change) leave it running.
    if (_pendingMovePlayerId == currentPlayer && _moveTimer?.isActive == true) {
      return;
    }

    // Turn actually moved — cancel any stale pending move.
    _cancelPending();

    if (bots.isEmpty) {
      developer.log('roomBotsProvider empty — waiting for population',
          name: 'BotMoveController');
      return;
    }

    final botInfo = bots.cast<BotInfo?>().firstWhere(
          (b) => b!.id == currentPlayer,
          orElse: () => null,
        );

    if (botInfo == null) return; // Not a bot's turn — it's a human's.

    _pendingMovePlayerId = currentPlayer;
    // Brief delay so moves don't feel instant. Kept short because cloud-staging
    // round-trips already add ~500ms — a longer think delay stacks badly.
    _moveTimer = Timer(const Duration(milliseconds: 200), () {
      _pendingMovePlayerId = null;
      if (_disposed) return;
      _playBotMove(state, botInfo, roomId);
    });
  }

  void _playBotMove(GameState state, BotInfo botInfo, String roomId) {
    if (state is TwentyNineState) {
      _playTwentyNineBotMove(state, botInfo, roomId);
    } else if (state is BridgeState) {
      _playBridgeBotMove(state, botInfo, roomId);
    } else if (state is OhHellState) {
      _playOhHellBotMove(state, botInfo, roomId);
    }
    // TODO: Add other game types as needed.
  }

  void _playOhHellBotMove(
    OhHellState state,
    BotInfo botInfo,
    String roomId,
  ) {
    final bot = _getOrCreateBot('oh_hell', botInfo);
    if (bot is! OhHellBot) return;

    final validMoves = _ohHellRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    final movePayload = _convertOhHellMoveToPayload(selectedMove);
    if (movePayload == null) return;

    developer.log('[BotMoveController] Oh Hell bot ${botInfo.id.substring(0, 8)} playing: ${movePayload['type']}');

    _ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: movePayload,
    );
  }

  Map<String, dynamic>? _convertOhHellMoveToPayload(OhHellMove move) {
    return switch (move) {
      OhHellBidMove() => {
          'type': 'bid',
          'player_id': move.playerId,
          'bid_value': move.bid,
        },
      OhHellPlayCardMove() => {
          'type': 'playCard',
          'player_id': move.playerId,
          'card': move.card.toJson(),
        },
    };
  }

  void _playTwentyNineBotMove(
    TwentyNineState state,
    BotInfo botInfo,
    String roomId,
  ) {
    final bot = _getOrCreateBot('twenty_nine', botInfo);
    if (bot is! TwentyNineBot) return;

    final validMoves = _twentyNineRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    // Convert the Dart move to the edge function's snake_case format.
    final movePayload = _convertMoveToPayload(selectedMove);
    if (movePayload == null) return;

    developer.log('[BotMoveController] Bot ${botInfo.id.substring(0, 8)} playing: ${movePayload['type']}');

    _ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: movePayload,
    );
  }

  void _playBridgeBotMove(
    BridgeState state,
    BotInfo botInfo,
    String roomId,
  ) {
    final bot = _getOrCreateBot('bridge', botInfo);
    if (bot is! BridgeBot) return;

    // When dummy is on lead, the declarer (possibly a bot) submits the move
    // on dummy's behalf. The rules engine returns moves authored by
    // botInfo.id when querying by that player ID.
    final validMoves = _bridgeRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    final movePayload = _convertBridgeMoveToPayload(selectedMove);
    if (movePayload == null) return;

    developer.log('[BotMoveController] Bridge bot ${botInfo.id.substring(0, 8)} playing: ${movePayload['type']}');

    _ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: movePayload,
    );
  }

  /// Convert a Dart [BridgeMove] to the snake_case JSON payload the edge
  /// function expects. The validate-move endpoint normalises flat payloads
  /// into a nested `data` sub-object server-side, so flat keys are fine.
  Map<String, dynamic>? _convertBridgeMoveToPayload(BridgeMove move) {
    return switch (move) {
      BridgeBidMove() => {
          'type': 'bid',
          'player_id': move.playerId,
          'level': move.level,
          'denomination': move.denomination.name,
        },
      BridgePassMove() => {
          'type': 'pass',
          'player_id': move.playerId,
        },
      BridgeDoubleMove() => {
          'type': 'double',
          'player_id': move.playerId,
        },
      BridgeRedoubleMove() => {
          'type': 'redouble',
          'player_id': move.playerId,
        },
      BridgePlayCardMove() => {
          'type': 'playCard',
          'player_id': move.playerId,
          'card': move.card.toJson(),
        },
      BridgeNewDealMove() => {
          'type': 'newDeal',
          'player_id': move.playerId,
        },
    };
  }

  Object _getOrCreateBot(String gameType, BotInfo info) {
    return _bots.putIfAbsent(info.id, () {
      final difficulty = _parseDifficulty(info.difficulty);
      return BotFactory.createBot(
        gameType: gameType,
        playerId: info.id,
        difficulty: difficulty,
      );
    });
  }

  BotDifficulty _parseDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return BotDifficulty.easy;
      case 'hard':
        return BotDifficulty.hard;
      case 'expert':
        return BotDifficulty.expert;
      default:
        return BotDifficulty.medium;
    }
  }

  /// Convert a Dart game move to the snake_case JSON the edge function expects.
  Map<String, dynamic>? _convertMoveToPayload(TwentyNineMove move) {
    return switch (move) {
      BidMove() => {
          'type': 'bid',
          'player_id': move.playerId,
          'bid_value': move.bidValue,
        },
      PassMove() => {
          'type': 'pass',
          'player_id': move.playerId,
        },
      DeclareTrumpMove() => {
          'type': 'declareTrump',
          'player_id': move.playerId,
          'suit': move.suit.name,
        },
      PlayCardMove() => {
          'type': 'playCard',
          'player_id': move.playerId,
          'card': move.card.toJson(),
        },
      RevealTrumpMove() => {
          'type': 'revealTrump',
          'player_id': move.playerId,
        },
      DoubleMove() => {
          'type': 'double',
          'player_id': move.playerId,
        },
      RedoubleMove() => {
          'type': 'redouble',
          'player_id': move.playerId,
        },
    };
  }

  void _cancelPending() {
    _moveTimer?.cancel();
    _moveTimer = null;
    _pendingMovePlayerId = null;
  }

  void dispose() {
    _disposed = true;
    _moveTimer?.cancel();
  }
}
