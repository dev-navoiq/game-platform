import 'dart:async';
import 'dart:math';

import 'package:bot_strategies/bot_strategies.dart';
import 'package:flutter/foundation.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ludo/game_ludo.dart';

import 'local_game_session.dart';

/// Converts a snake_case wire move (what the game screens send to
/// `sendMove`) into a typed engine move, or null if it can't be decoded.
/// Gets the current state because some wire formats are contextual — e.g.
/// Ludo's `{'type': 'move', 'token_id': …}` carries no step count; the
/// steps come from `state.lastRoll`.
typedef WireMoveDecoder<TState extends GameState, TMove extends GameMove>
    = TMove? Function(TState state, Map<String, dynamic> wire);

/// Hosts a game engine fully on-device for "Practice vs Bots" sessions:
/// exactly one human plus 1..N bots, no server round-trips.
///
/// - The human's moves arrive through [handleWireMove] (routed from
///   `GameNotifier.sendMove`, so the existing game screens work unmodified),
///   are validated + applied by the pure Dart rules engine, and the
///   resulting state is pushed back through [_publish] — the same
///   `gameStateProvider` pipeline a server game uses.
/// - Bot moves are computed with `bot_strategies` and applied after a small
///   natural "think" delay so turns stay followable.
///
/// This class deliberately has no Supabase/Riverpod imports — the unit test
/// drives a whole game through it with zero network access.
class LocalGameCoordinator<TState extends GameState, TMove extends GameMove>
    implements LocalGameSession {
  @override
  final String roomId;

  /// Game type key ('ludo', …) — informational/logging only.
  final String gameType;

  final GameRules<TState, TMove> _rules;
  final List<String> _playerIds;
  final Map<String, BotPlayer<TState, TMove>> _bots;
  final WireMoveDecoder<TState, TMove> _decodeWireMove;
  final void Function(GameState state) _publish;
  final Random _random;

  /// Test hook: when set, bots use exactly this delay instead of the
  /// randomized natural one. Pass [Duration.zero] to run games instantly.
  final Duration? _botThinkDelayOverride;

  TState? _state;
  Timer? _botTimer;
  bool _disposed = false;
  bool _completionHookFired = false;

  LocalGameCoordinator({
    required this.roomId,
    required this.gameType,
    required GameRules<TState, TMove> rules,
    required List<String> playerIds,
    required Map<String, BotPlayer<TState, TMove>> bots,
    required WireMoveDecoder<TState, TMove> decodeWireMove,
    required void Function(GameState state) publish,
    Random? random,
    Duration? botThinkDelayOverride,
  })  : _rules = rules,
        _playerIds = playerIds,
        _bots = bots,
        _decodeWireMove = decodeWireMove,
        _publish = publish,
        _random = random ?? Random(),
        _botThinkDelayOverride = botThinkDelayOverride,
        assert(bots.isNotEmpty, 'a practice session needs at least one bot'),
        // 1 human = practice; 0 humans = autopilot (every seat bot-driven),
        // used to soak-test full games through the real UI without input.
        assert(playerIds.length - bots.length <= 1,
            'local sessions support at most one human');

  /// Display names of the bot seats, keyed by player id — used to build the
  /// room roster so the UI shows "Alex" instead of a raw id.
  Map<String, String> get botNamesById =>
      {for (final e in _bots.entries) e.key: e.value.name};

  /// The current engine state (null before [start]).
  TState? get state => _state;

  /// Create the initial state and publish it. If a bot is first to act,
  /// its turn is scheduled immediately.
  void start() {
    final initial = _rules.createInitialState(
      playerIds: _playerIds,
      dealerIndex: 0, // human first — they launched the practice game
    );
    _publishAndContinue(initial);
  }

  @override
  Future<void> handleWireMove(Map<String, dynamic> move) async {
    if (_disposed) return;
    final state = _state;
    if (state == null) return;

    final decoded = _decodeWireMove(state, move);
    if (decoded == null) {
      debugPrint(
          '[LocalGameCoordinator] undecodable $gameType wire move: $move');
      return;
    }
    final result = _rules.applyMove(state, decoded);
    if (!result.isValid) {
      // The screens only offer engine-valid moves, so this is a benign race
      // (double-tap / stale frame) in practice. Server games behave the same
      // way for Ludo: the rejection is swallowed and the next state wins.
      debugPrint(
          '[LocalGameCoordinator] $gameType move rejected: ${result.error}');
      return;
    }
    _publishAndContinue(result.newState);
  }

  // ── Internal loop ─────────────────────────────────────────────────────────

  void _publishAndContinue(TState next) {
    if (_disposed) return;
    _state = next;
    _publish(next);

    if (next.isGameOver || _rules.isGameOver(next)) {
      _botTimer?.cancel();
      _botTimer = null;
      if (!_completionHookFired) {
        _completionHookFired = true;
        // TODO(record_game_completion): report this finished practice game to
        // the server so coin/XP rewards can be granted — winners from
        // _rules.getWinners(next), placements from _rules.calculateScores(next).
        // The record_game_completion edge function doesn't exist yet; until it
        // does, practice results are local-only and the GameOverDialog's
        // coin/XP numbers are cosmetic.
        debugPrint('[LocalGameCoordinator] $gameType game over — '
            'winners=${_rules.getWinners(next)} '
            'scores=${_rules.calculateScores(next)}');
      }
      return;
    }

    final current = next.currentPlayerId;
    if (current != null && _bots.containsKey(current)) {
      _scheduleBotMove();
    }
    // Human's turn: nothing to do — the screen will call handleWireMove.
  }

  void _scheduleBotMove() {
    _botTimer?.cancel();
    // ~600-900ms so bot turns are followable but not sluggish. Ludo bot
    // turns take two steps (roll, then token move) and each gets its own
    // delay, which reads naturally on the board.
    final delay = _botThinkDelayOverride ??
        Duration(milliseconds: 600 + _random.nextInt(301));
    _botTimer = Timer(delay, _playBotMove);
  }

  void _playBotMove() {
    if (_disposed) return;
    final state = _state;
    if (state == null) return;
    final playerId = state.currentPlayerId;
    final bot = _bots[playerId];
    if (bot == null) return; // turn moved to the human meanwhile

    final validMoves = _rules.getValidMoves(state, playerId!);
    if (validMoves.isEmpty) {
      // Engines always offer at least a pass/roll on your turn; treat this
      // as a bug signal rather than spinning.
      debugPrint(
          '[LocalGameCoordinator] $gameType bot $playerId has no valid moves');
      return;
    }
    final move = bot.selectMove(state, validMoves) ?? validMoves.first;
    final result = _rules.applyMove(state, move);
    if (!result.isValid) {
      debugPrint('[LocalGameCoordinator] $gameType bot move rejected '
          '(${result.error}) — falling back to first valid move');
      final fallback = _rules.applyMove(state, validMoves.first);
      if (!fallback.isValid) return;
      _publishAndContinue(fallback.newState);
      return;
    }
    _publishAndContinue(result.newState);
  }

  @override
  void dispose() {
    _disposed = true;
    _botTimer?.cancel();
    _botTimer = null;
  }

  // ── Ludo factory ──────────────────────────────────────────────────────────

  static const List<String> _ludoBotNames = ['Alex', 'Jordan', 'Casey'];

  /// Build a Ludo practice session: [humanPlayerId] vs [botCount] bots (1-3).
  ///
  /// NOTE(dice): multiplayer Ludo uses *server-authoritative* dice. That is
  /// impossible offline, so practice games roll from a locally seeded
  /// [Random] instead ([random] can pin the seed for deterministic tests).
  /// Practice results must therefore never feed ranked/economy systems
  /// without server-side verification.
  static LocalGameCoordinator<LudoState, LudoMove> ludo({
    required String roomId,
    required String humanPlayerId,
    required int botCount,
    required void Function(GameState state) publish,
    BotDifficulty botDifficulty = BotDifficulty.medium,
    Random? random,
    Duration? botThinkDelayOverride,
    bool autoPilot = false,
  }) {
    assert(botCount >= 1 && botCount <= 3, 'Ludo supports 1-3 bots');
    final rng = random ?? Random();

    final bots = <String, BotPlayer<LudoState, LudoMove>>{};
    for (var i = 0; i < botCount; i++) {
      final id = 'local-bot-${i + 1}';
      bots[id] = LudoBot(
        playerId: id,
        name: _ludoBotNames[i],
        difficulty: botDifficulty,
        random: Random(rng.nextInt(1 << 31)),
      );
    }
    if (autoPilot) {
      // Dev soak-test mode: the human's seat is bot-driven too, so a full
      // game plays itself through the real UI with zero interaction.
      bots[humanPlayerId] = LudoBot(
        playerId: humanPlayerId,
        name: 'You (auto)',
        difficulty: botDifficulty,
        random: Random(rng.nextInt(1 << 31)),
      );
    }

    return LocalGameCoordinator<LudoState, LudoMove>(
      roomId: roomId,
      gameType: 'ludo',
      rules: LudoRules(null, Random(rng.nextInt(1 << 31))),
      playerIds: [humanPlayerId, ...bots.keys],
      bots: bots,
      decodeWireMove: decodeLudoWireMove,
      publish: publish,
      random: rng,
      botThinkDelayOverride: botThinkDelayOverride,
    );
  }

  /// Decode the exact wire payloads LudoGameScreen / BotMoveController emit:
  /// `{'type': 'roll'|'move'|'pass', 'player_id': …, 'token_id': …}`.
  /// Exposed for tests.
  static LudoMove? decodeLudoWireMove(
      LudoState state, Map<String, dynamic> wire) {
    final playerId = wire['player_id'] as String?;
    if (playerId == null) return null;
    switch (wire['type'] as String?) {
      case 'roll':
        return LudoRollDice(playerId: playerId);
      case 'move':
        final roll = state.lastRoll;
        final tokenId = wire['token_id'] as String?;
        if (roll == null || tokenId == null) return null;
        return LudoMoveToken(playerId: playerId, tokenId: tokenId, steps: roll);
      case 'pass':
        return LudoPass(playerId: playerId);
      default:
        return null;
    }
  }
}
