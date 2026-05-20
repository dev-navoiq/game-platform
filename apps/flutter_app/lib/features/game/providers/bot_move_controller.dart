import 'dart:async';

import 'package:bot_strategies/bot_strategies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
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

  // Rules engine for generating valid moves.
  final TwentyNineRules _twentyNineRules = TwentyNineRules();

  BotMoveController(this._ref);

  /// Start watching for bot turns. Call once when game screen loads.
  void startWatching({required String roomId}) {
    _ref.listen<GameState?>(gameStateProvider, (prev, next) {
      if (_disposed || next == null) return;
      _onStateChanged(next, roomId);
    });
  }

  void _onStateChanged(GameState state, String roomId) {
    final bots = _ref.read(roomBotsProvider);
    if (bots.isEmpty) return;

    // Cancel any pending bot move (in case state changed rapidly).
    _moveTimer?.cancel();

    // Don't auto-trigger newRound — human confirms via RoundEndOverlay.
    if (state is TwentyNineState &&
        (state.phase == GamePhase.roundEnd || state.phase == GamePhase.gameEnd)) {
      return;
    }

    final currentPlayer = state.currentPlayerId;
    if (currentPlayer == null) return;

    final botInfo = bots.cast<BotInfo?>().firstWhere(
          (b) => b!.id == currentPlayer,
          orElse: () => null,
        );

    if (botInfo == null) return; // Not a bot's turn.

    // Small delay to simulate thinking and avoid rapid-fire moves.
    _moveTimer = Timer(const Duration(milliseconds: 800), () {
      if (_disposed) return;
      _playBotMove(state, botInfo, roomId);
    });
  }

  void _playBotMove(GameState state, BotInfo botInfo, String roomId) {
    if (state is TwentyNineState) {
      _playTwentyNineBotMove(state, botInfo, roomId);
    }
    // TODO: Add other game types as needed.
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

    print('[BotMoveController] Bot ${botInfo.id.substring(0, 8)} playing: ${movePayload['type']}');

    _ref.read(gameStateProvider.notifier).sendMove(
      roomId: roomId,
      move: movePayload,
    );
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

  void dispose() {
    _disposed = true;
    _moveTimer?.cancel();
  }
}
