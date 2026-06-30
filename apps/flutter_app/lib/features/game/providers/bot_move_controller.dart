import 'dart:async';

import 'package:bot_strategies/bot_strategies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/supabase_service.dart';
import 'game_provider.dart';

/// Info about bots in the current room.
class BotInfo {
  final String id;
  final String difficulty;

  const BotInfo({required this.id, required this.difficulty});
}

/// Provider that holds the list of bot player IDs for the current room.
final roomBotsProvider = StateProvider<List<BotInfo>>((ref) => []);

/// Last bot-move rejection the controller couldn't recover from. Watched by
/// the game screen so the user gets a snackbar instead of an opaque stuck
/// table. Cleared by the watcher after it surfaces the message.
final botMoveErrorProvider = StateProvider<String?>((ref) => null);

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
  StreamSubscription<dynamic>? _roomSubscription;
  // Provider subscriptions registered via _ref.listen, plus the room id they
  // captured. The controller is a global Provider (not autoDispose) so the
  // same instance is reused across game-screen mounts — without cleaning
  // these up, every navigation stacks one more listener on top, and an
  // OLD listener (still holding the OLD roomId in its closure) ends up
  // dispatching the NEW game's bot move to the OLD room. The server then
  // looks up that OLD room's config.bots — which is empty (post-forfeit
  // cleanup) — and rejects the move with PLAYER_MISMATCH. The table sits.
  final List<ProviderSubscription<dynamic>> _providerSubscriptions = [];

  // Cache bot instances by player ID.
  final Map<String, Object> _bots = {};

  // ID of the player whose move is currently pending in [_moveTimer]. Used to
  // ignore duplicate state events that don't actually change whose turn it is
  // (Supabase Realtime occasionally re-delivers the same row). Without this
  // guard, every redelivery cancels the in-flight timer and the bot's move
  // never fires.
  String? _pendingMovePlayerId;

  // Trick-completion detector: when state.currentTrick goes from >0 to 0,
  // the trick just completed and the UI is showing the hold + collect
  // animation (~3s). We stretch the next bot's "think" delay to ~3000ms
  // so the bot's next move doesn't dispatch before the user sees the
  // previous trick get collected.
  int _prevTrickSize = 0;
  bool _justCompletedTrick = false;

  // Rules engine for generating valid moves.
  final TwentyNineRules _twentyNineRules = TwentyNineRules();
  final BridgeRules _bridgeRules = BridgeRules();
  final OhHellRules _ohHellRules = OhHellRules();
  final LudoRules _ludoRules = LudoRules();

  BotMoveController(this._ref);

  /// Start watching for bot turns. Call once when game screen loads.
  ///
  /// Safe to call multiple times: any prior listeners / subscriptions are
  /// closed before new ones register so we never end up with two listeners
  /// holding different roomIds in their closures (which previously caused
  /// the new game's bot move to be dispatched to the old, abandoned room
  /// → PLAYER_MISMATCH).
  void startWatching({required String roomId}) {
    _closeSubscriptions();

    _providerSubscriptions.add(
      _ref.listen<GameState?>(gameStateProvider, (prev, next) {
        if (_disposed || next == null) return;
        _onStateChanged(next, roomId);
      }),
    );
    // Race fix: the room-status realtime subscription can navigate to the
    // game screen BEFORE the host's _startGame finishes populating
    // roomBotsProvider. Without this listener, the controller processes the
    // initial state with an empty bots list, silently bails, and never
    // rechecks — leaving the first bot's turn permanently stuck. Re-run
    // _onStateChanged whenever the bot list transitions to non-empty.
    _providerSubscriptions.add(
      _ref.listen<List<BotInfo>>(roomBotsProvider, (prev, next) {
        if (_disposed) return;
        if ((prev?.isEmpty ?? true) && next.isNotEmpty) {
          final current = _ref.read(gameStateProvider);
          if (current != null) _onStateChanged(current, roomId);
        }
      }),
    );
    // Subscribe to game_rooms so mid-game changes to config.bots (a human
    // forfeits → server appends a substitute bot inheriting their user_id)
    // and host transfers (current_host_id flips) propagate to this client.
    // Without this, the host who started the game keeps the bot list from
    // _startGame's snapshot forever, and a forfeited human's turn never
    // gets picked up by the bot subroutine.
    _subscribeToRoomConfig(roomId);
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

  /// Close every active provider listener + realtime subscription. Used by
  /// startWatching (before re-registering) and dispose (final cleanup).
  /// Also clears the bot instance cache and any pending move state so a
  /// fresh game doesn't inherit the previous one's _bots map / timer.
  void _closeSubscriptions() {
    for (final sub in _providerSubscriptions) {
      try {
        sub.close();
      } catch (_) {/* already closed */}
    }
    _providerSubscriptions.clear();
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _moveTimer?.cancel();
    _moveTimer = null;
    _pendingMovePlayerId = null;
    _bots.clear();
    _prevTrickSize = 0;
    _justCompletedTrick = false;
  }

  /// Listen for changes to the room's config.bots and current_host_id so
  /// substitutions made by `leave-room` (forfeits) and host transfers stay
  /// in sync with this client's `roomBotsProvider`.
  ///
  /// Only the live host populates roomBotsProvider — joiner clients keep
  /// it empty so we don't get two devices racing to dispatch the same
  /// bot move. This handler enforces that gate: it clears the provider if
  /// the current client isn't the host, and populates it otherwise.
  void _subscribeToRoomConfig(String roomId) {
    // Wrap the supabase access in a try/catch — in widget tests Supabase
    // is intentionally not initialized, and `_ref.read(supabaseProvider)`
    // throws. The bot move flow has its own _startGame-time pre-load, so
    // the subscription is a nice-to-have for live substitutions, not a
    // hard prerequisite. Skip it silently when Supabase isn't around.
    final SupabaseClient supabase;
    try {
      supabase = _ref.read(supabaseProvider);
    } catch (_) {
      return;
    }
    _roomSubscription = supabase
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((rows) {
      if (_disposed || rows.isEmpty) return;
      final row = rows.first;
      final config = row['config'] as Map<String, dynamic>?;
      final currentHostId = (row['current_host_id'] as String?) ??
          (row['created_by'] as String?);
      final myId = _ref.read(currentUserProvider)?.id;

      if (currentHostId == null || myId == null || currentHostId != myId) {
        // Not the host — never populate bots. If a previous read had put
        // bots here (e.g. host transferred away from us), clear them so
        // we stop dispatching moves we're no longer responsible for.
        final existing = _ref.read(roomBotsProvider);
        if (existing.isNotEmpty) {
          _ref.read(roomBotsProvider.notifier).state = const [];
        }
        return;
      }

      final botsList = (config?['bots'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final next = botsList
          .map((b) => BotInfo(
                id: b['id'] as String,
                difficulty: (b['difficulty'] as String?) ?? 'medium',
              ))
          .toList();
      // Avoid emitting equal lists — saves a redundant _onStateChanged
      // re-entry via the roomBotsProvider listener above.
      final current = _ref.read(roomBotsProvider);
      if (!_botListsEqual(current, next)) {
        _ref.read(roomBotsProvider.notifier).state = next;
      }
    });
  }

  static bool _botListsEqual(List<BotInfo> a, List<BotInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].difficulty != b[i].difficulty) {
        return false;
      }
    }
    return true;
  }

  /// Helper for the trick-completion detector. Returns the size of the
  /// current trick across all supported games (0 if not a trick-taking
  /// state). Looked up dynamically to keep this controller from depending
  /// on a sealed type hierarchy.
  int _currentTrickSize(GameState state) {
    if (state is TwentyNineState) return state.currentTrick.length;
    if (state is BridgeState) return state.currentTrick.length;
    if (state is OhHellState) return state.currentTrick.length;
    return 0;
  }

  void _onStateChanged(GameState state, String roomId) {
    final bots = _ref.read(roomBotsProvider);

    // Trick-completion detector: previous frame had cards on the table,
    // this frame has none. The flag is consumed when the *next* bot move
    // is scheduled — so the bot leading the new trick waits long enough
    // for the user to see the collect animation before its card pops in.
    final currentTrickSize = _currentTrickSize(state);
    if (_prevTrickSize > 0 && currentTrickSize == 0) {
      _justCompletedTrick = true;
    }
    _prevTrickSize = currentTrickSize;

    print(
      '[BotMoveController] state changed: phase=${(state as dynamic).phase} '
      'current=${state.currentPlayerId} '
      'bots=${bots.length} pending=$_pendingMovePlayerId '
      'trick=$currentTrickSize postTrick=$_justCompletedTrick',
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
    if (state is LudoState && state.phase == GamePhase.gameEnd) {
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
      print('[BotMoveController] roomBotsProvider empty — waiting for population');
      return;
    }

    final botInfo = bots.cast<BotInfo?>().firstWhere(
          (b) => b!.id == currentPlayer,
          orElse: () => null,
        );

    if (botInfo == null) return; // Not a bot's turn — it's a human's.

    _pendingMovePlayerId = currentPlayer;
    // When the previous move just completed a trick, the UI is mid-collect
    // (trickHold + collect ≈ 3s). Stretch the bot's delay so its next card
    // doesn't appear before the collect finishes. The flag is consumed
    // here — subsequent state changes inside the same trick use the short
    // delay again.
    final Duration thinkDelay;
    if (_justCompletedTrick) {
      thinkDelay = const Duration(milliseconds: 3000);
      _justCompletedTrick = false;
    } else {
      // Brief delay so moves don't feel instant. Kept short because
      // cloud-staging round-trips already add ~500ms — a longer think
      // delay stacks badly.
      thinkDelay = const Duration(milliseconds: 200);
    }
    _moveTimer = Timer(thinkDelay, () async {
      if (_disposed) {
        _pendingMovePlayerId = null;
        return;
      }
      // Always read the freshest state. The duplicate-delivery guard above
      // intentionally lets the timer run when `currentPlayerId` is unchanged
      // — but the *phase* can still flip under us (29's bidding → trumpSelection
      // when the bidder is the bot, Oh Hell's bidding → playing on the last
      // bid). Without this re-read, the bot computes a move against a stale
      // phase, the server rejects WRONG_PHASE, and the table never moves.
      final fresh = _ref.read(gameStateProvider) ?? state;
      if (fresh.currentPlayerId != botInfo.id) {
        // Turn moved off the bot in the gap — let the next state change
        // schedule the appropriate move for whoever is up.
        _pendingMovePlayerId = null;
        return;
      }
      // Hold `_pendingMovePlayerId` through the ENTIRE async dispatch
      // (network roundtrip included). Without this hold, a Supabase
      // realtime echo or re-entrant _onStateChanged that arrives between
      // dispatch-kicked-off and server-response-arrives would see the
      // guard already cleared and issue a SECOND `sendMove` for the same
      // bid. The first lands and advances state; the second arrives after
      // → server returns 409 VERSION_CONFLICT or 403 NOT_YOUR_TURN; the
      // bot's error path swallows it; the table looks stuck. Confirmed
      // via staging edge-function logs (2026-06-11).
      try {
        await _playBotMove(fresh, botInfo, roomId);
      } finally {
        if (_pendingMovePlayerId == botInfo.id) {
          _pendingMovePlayerId = null;
        }
      }
    });
  }

  Future<void> _playBotMove(GameState state, BotInfo botInfo, String roomId) {
    if (state is TwentyNineState) {
      return _playTwentyNineBotMove(state, botInfo, roomId);
    } else if (state is BridgeState) {
      return _playBridgeBotMove(state, botInfo, roomId);
    } else if (state is OhHellState) {
      return _playOhHellBotMove(state, botInfo, roomId);
    } else if (state is LudoState) {
      return _playLudoBotMove(state, botInfo, roomId);
    }
    return Future<void>.value();
  }

  /// Ludo bot turns take two server round-trips: first a (server-authoritative)
  /// roll, then — once the rolled value broadcasts back — a token move or pass.
  /// Each step is scheduled independently as the new state arrives.
  Future<void> _playLudoBotMove(
    LudoState state,
    BotInfo botInfo,
    String roomId,
  ) async {
    final bot = _getOrCreateBot('ludo', botInfo);
    if (bot is! LudoBot) return;

    final validMoves = _ludoRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    final movePayload = _convertLudoMoveToPayload(selectedMove);
    if (movePayload == null) return;

    print('[BotMoveController] Ludo bot ${botInfo.id.substring(0, 8)} computed: ${movePayload['type']}');

    await _dispatchBotMove(botInfo, roomId, movePayload, 'ludo');
  }

  Map<String, dynamic>? _convertLudoMoveToPayload(LudoMove move) {
    return switch (move) {
      LudoRollDice() => {'type': 'roll', 'player_id': move.playerId},
      LudoMoveToken() => {
          'type': 'move',
          'player_id': move.playerId,
          'token_id': move.tokenId,
        },
      LudoPass() => {'type': 'pass', 'player_id': move.playerId},
    };
  }

  Future<void> _playOhHellBotMove(
    OhHellState state,
    BotInfo botInfo,
    String roomId,
  ) async {
    final bot = _getOrCreateBot('oh_hell', botInfo);
    if (bot is! OhHellBot) return;

    final validMoves = _ohHellRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    final movePayload = _convertOhHellMoveToPayload(selectedMove);
    if (movePayload == null) return;

    print('[BotMoveController] Oh Hell bot ${botInfo.id.substring(0, 8)} computed: ${movePayload['type']}');

    await _dispatchBotMove(botInfo, roomId, movePayload, 'oh_hell');
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

  Future<void> _playTwentyNineBotMove(
    TwentyNineState state,
    BotInfo botInfo,
    String roomId,
  ) async {
    final bot = _getOrCreateBot('twenty_nine', botInfo);
    if (bot is! TwentyNineBot) return;

    final validMoves = _twentyNineRules.getValidMoves(state, botInfo.id);
    if (validMoves.isEmpty) return;

    final selectedMove = bot.selectMove(state, validMoves);
    if (selectedMove == null) return;

    // Convert the Dart move to the edge function's snake_case format.
    final movePayload = _convertMoveToPayload(selectedMove);
    if (movePayload == null) return;

    print('[BotMoveController] 29 bot ${botInfo.id.substring(0, 8)} computed: ${movePayload['type']}');

    await _dispatchBotMove(botInfo, roomId, movePayload, 'twenty_nine');
  }

  Future<void> _playBridgeBotMove(
    BridgeState state,
    BotInfo botInfo,
    String roomId,
  ) async {
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

    print('[BotMoveController] Bridge bot ${botInfo.id.substring(0, 8)} computed: ${movePayload['type']}');

    await _dispatchBotMove(botInfo, roomId, movePayload, 'bridge');
  }

  /// Shared dispatch + error-visibility path for all bot moves.
  ///
  /// sendMove is fire-and-forget at the call site (we don't block the
  /// timer waiting for the network), but the returned Future can still
  /// reject — e.g. server returns 400 NOT_YOUR_TURN/WRONG_PHASE/FORBIDDEN_BID,
  /// 409 VERSION_CONFLICT, or a network error. Before this hook those
  /// rejections propagated as unhandled async exceptions and the bot
  /// silently stayed "stuck" — there was no visible signal anywhere that
  /// the move had failed, the engine state didn't advance, and the bot
  /// never retried. Now the failure is at least logged with the game
  /// type + bot id so the case is debuggable from a device log.
  Future<void> _dispatchBotMove(
    BotInfo botInfo,
    String roomId,
    Map<String, dynamic> movePayload,
    String gameType,
  ) async {
    // `print` (not developer.log) so the dispatch shows up in flutter-run
    // output on release builds — developer.log is silenced without a VM
    // service attached.
    print('[BotMoveController] dispatching $gameType bot ${botInfo.id.substring(0, 8)}: ${movePayload['type']}');
    try {
      await _ref
          .read(gameStateProvider.notifier)
          .sendMove(roomId: roomId, move: movePayload);
    } on MoveRejection catch (rejection) {
      print(
        '[BotMoveController] $gameType bot ${botInfo.id.substring(0, 8)} '
        'rejected: $rejection',
      );
      // VERSION_CONFLICT means our state was stale — re-read fresh state
      // and try once more. Other rejections fall into two buckets:
      //   • benign races (NOT_YOUR_TURN, WRONG_PHASE) — the table has
      //     already moved past where we computed the move, the next state
      //     emission will trigger the right bot, so the user doesn't need
      //     to see a snackbar that yells about a problem they can't act on.
      //   • genuine logic errors (FORBIDDEN_BID, BID_TOO_HIGH, MUST_FOLLOW_SUIT,
      //     PLAYER_MISMATCH) — the bot or config is broken; surface those so
      //     the user knows the table may not advance.
      if (rejection.code == 'VERSION_CONFLICT') {
        await _retryAfterVersionConflict(botInfo, roomId, gameType);
        return;
      }
      const benignRaces = {'NOT_YOUR_TURN', 'WRONG_PHASE'};
      if (benignRaces.contains(rejection.code)) {
        return;
      }
      // Surface to UI so the user sees the failure instead of an opaque
      // stuck table. The game-screen listener clears this after showing.
      _ref.read(botMoveErrorProvider.notifier).state =
          'Bot move rejected (${rejection.code}). The table may not advance.';
    } catch (error) {
      print(
        '[BotMoveController] $gameType bot ${botInfo.id.substring(0, 8)} '
        'sendMove threw non-rejection: $error',
      );
      _ref.read(botMoveErrorProvider.notifier).state =
          'Bot move failed to send. Check connection.';
    }
  }

  /// Re-read the freshest game state and re-schedule the bot turn so it
  /// computes a move against the up-to-date version. Used only for
  /// VERSION_CONFLICT — other rejection codes mean the move was wrong on
  /// the merits and a retry won't change the outcome.
  Future<void> _retryAfterVersionConflict(
    BotInfo botInfo,
    String roomId,
    String gameType,
  ) async {
    if (_disposed) return;
    final fresh = _ref.read(gameStateProvider);
    if (fresh == null || fresh.currentPlayerId != botInfo.id) {
      // Turn moved past this bot during the round-trip — nothing to retry.
      return;
    }
    print('[BotMoveController] $gameType bot ${botInfo.id.substring(0, 8)} '
        'retrying after VERSION_CONFLICT');
    await _playBotMove(fresh, botInfo, roomId);
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
      ClaimRoyalWeddingMove() => {
          'type': 'claimRoyalWedding',
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
    _closeSubscriptions();
  }
}
