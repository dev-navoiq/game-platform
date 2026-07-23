import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../../../core/services/supabase_service.dart';
import '../local/local_game_session.dart';

final gameStateProvider =
    StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier(ref.watch(supabaseServiceProvider));
});

/// Active room id while the GameScreen is mounted. Set in
/// [GameScreen.initState] and cleared in dispose. Used by GameActions
/// (and any other game-screen-scoped widget) to forfeit/leave without
/// having to thread the room id through every widget constructor.
final currentRoomIdProvider = StateProvider<String?>((ref) => null);

class GameNotifier extends StateNotifier<GameState?> {
  final SupabaseService _supabase;
  String? _gameType;

  /// Monotonic version of the last state we accepted. Incoming states (from
  /// the realtime backstop or a slow validate-move response) that are *older*
  /// than this are dropped so they can't clobber a newer optimistic / server
  /// state. See [_versionOf]. Starts at -1 so the very first state always wins.
  int _appliedVersion = -1;

  /// Pure rules engine used to predict the result of a deterministic move
  /// locally, before the server confirms it (optimistic UI).
  final _twentyNineRules = TwentyNineRules();

  GameNotifier(this._supabase) : super(null);

  /// On-device practice session ("Practice vs Bots"). While attached, moves
  /// whose roomId matches the session are applied by the local engine and no
  /// realtime subscription is opened — zero server round-trips.
  LocalGameSession? _localSession;

  /// Self-healing realtime subscription for the active room (reconnect +
  /// catch-up + watchdog live in SupabaseService). Cancelled on re-subscribe
  /// and dispose.
  GameStateSubscription? _gameStateSub;

  /// Attach a local practice session. Any previous session is disposed so a
  /// stale coordinator can't keep publishing into this notifier.
  void attachLocalSession(LocalGameSession session) {
    if (identical(_localSession, session)) return;
    _localSession?.dispose();
    _localSession = session;
  }

  /// Set the active game type for state deserialization.
  void setGameType(String gameType) {
    _gameType = gameType;
  }

  /// Subscribe to real-time game state updates for a room.
  Future<void> subscribeToGame({required String roomId}) async {
    // Local practice sessions have no server row to subscribe to — the
    // attached LocalGameSession publishes states via updateState directly.
    if (_localSession != null && LocalGameSession.isLocalRoomId(roomId)) {
      return;
    }
    print('[GameNotifier] subscribeToGame roomId=$roomId gameType=$_gameType');
    // Replace any previous room's subscription — its reconnect timers and
    // watchdog must not keep feeding a screen we've left.
    _gameStateSub?.cancel();
    _gameStateSub = _supabase.subscribeToGameState(
      roomId: roomId,
      onUpdate: (data) {
        print('[GameNotifier] onUpdate received: gameType=$_gameType, dataKeys=${(data as Map).keys.toList()}');
        if (_gameType == null) return;
        final stateData = data['state_data'] as Map<String, dynamic>?;
        if (stateData == null) {
          print('[GameNotifier] state_data is null');
          return;
        }
        final newState = deserializeGameState(_gameType!, stateData);
        print('[GameNotifier] deserialized state: ${newState != null ? 'OK' : 'NULL'}');
        if (newState != null) {
          _applyAuthoritative(newState);
        }
      },
    );
  }

  /// Send a move to the server and apply the authoritative result it returns.
  /// Used for moves we don't predict locally (e.g. declareTrump) and for the
  /// host-driven bot path.
  Future<void> sendMove({
    required String roomId,
    required dynamic move,
  }) async {
    if (_routeToLocalSession(roomId)) {
      await _localSession!.handleWireMove(_asWireMap(move));
      return;
    }
    final response = await _supabase.sendMove(roomId: roomId, move: move);
    _applyServerResponse(response);
  }

  /// True when [roomId] belongs to the attached on-device practice session,
  /// meaning the move must be applied locally instead of sent to the server.
  bool _routeToLocalSession(String roomId) =>
      _localSession != null && _localSession!.roomId == roomId;

  static Map<String, dynamic> _asWireMap(dynamic move) => move is Map
      ? Map<String, dynamic>.from(move)
      : (move as dynamic).toJson() as Map<String, dynamic>;

  /// Send a move with an optimistic local prediction.
  ///
  /// [localMove] is the typed move fed to the local rules engine to update the
  /// UI *immediately*; [wireMove] is the JSON payload sent to validate-move
  /// (kept separate because the server expects snake_case fields). The server
  /// remains authoritative: its response (or the realtime backstop) overwrites
  /// the prediction, and a [MoveRejection] rolls it back.
  Future<void> sendMoveOptimistic({
    required String roomId,
    required GameMove localMove,
    required dynamic wireMove,
  }) async {
    // Local practice session: the on-device engine IS authoritative — no
    // optimistic prediction needed, the applied state comes back instantly.
    if (_routeToLocalSession(roomId)) {
      await _localSession!.handleWireMove(_asWireMap(wireMove));
      return;
    }

    final before = state;
    final gameType = _gameType;

    // 1. Predict the result locally and show it now — but only for
    //    deterministic moves (no shuffle / hidden-card deal).
    if (before != null && gameType != null) {
      final predicted = _predictOptimisticState(gameType, before, localMove);
      if (predicted != null) _applyAuthoritative(predicted);
    }

    // 2. Confirm with the server and reconcile.
    try {
      final response = await _supabase.sendMove(roomId: roomId, move: wireMove);
      _applyServerResponse(response);
    } on MoveRejection {
      // The server refused the move — undo the optimistic prediction. The
      // realtime backstop will re-sync if state moved on meanwhile.
      if (before != null) {
        _appliedVersion = _versionOf(before);
        state = before;
      }
      rethrow; // let the UI surface a message
    }
  }

  void _applyServerResponse(Map<String, dynamic> response) {
    final gameType = _gameType;
    if (gameType == null) return;
    final newStateData = response['new_state'] as Map<String, dynamic>?;
    if (newStateData == null) return;
    final newState = deserializeGameState(gameType, newStateData);
    if (newState != null) _applyAuthoritative(newState);
  }

  /// Adopt [newState] unless it is older than what we've already shown.
  ///
  /// The staleness guard exists to stop a late realtime echo (or a slow
  /// validate-move response) from clobbering a newer *optimistic* state. Only
  /// Twenty-Nine predicts moves locally today, and only its turnNumber is
  /// verified monotonic across every server transition — so the guard is
  /// scoped to it. Other games keep plain last-write-wins (their prior
  /// behaviour), which is correct because they never apply state ahead of the
  /// server.
  void _applyAuthoritative(GameState newState) {
    if (_gameType == 'twenty_nine' && _versionOf(newState) < _appliedVersion) {
      return; // stale — ignore
    }
    _appliedVersion = _versionOf(newState);
    state = newState;
  }

  /// Monotonically-increasing version. Every state transition (including the
  /// 4-pass re-deal and new-round/session-restart) increments turnNumber and
  /// never resets it for the lifetime of a game_states row, so it never goes
  /// backwards for a legitimate forward transition. (roundNumber can't be used
  /// — a session restart resets it to 1 while turnNumber keeps climbing.)
  int _versionOf(GameState s) => s.turnNumber;

  /// Predict the next state for [move] applied to [before], or null if the move
  /// is not safe to apply before the server confirms — i.e. it is
  /// non-deterministic (shuffles / deals hidden cards) or unsupported here.
  GameState? _predictOptimisticState(
      String gameType, GameState before, GameMove move) {
    if (gameType != 'twenty_nine') return null;
    if (before is! TwentyNineState || move is! TwentyNineMove) return null;

    final eligible = switch (move) {
      PlayCardMove() => true,
      BidMove() => true,
      DoubleMove() => true,
      RedoubleMove() => true,
      RevealTrumpMove() => true,
      ClaimRoyalWeddingMove() => true,
      // A pass is deterministic unless it is the dissolving 4th pass, which
      // shuffles and re-deals — let the server be the source of truth there.
      PassMove() => !(before.passCount + 1 >= 4 && before.bidderId == null),
      // declareTrump deals the second batch of (hidden) cards — don't predict.
      DeclareTrumpMove() => false,
    };
    if (!eligible) return null;

    final result = _twentyNineRules.applyMove(before, move);
    return result.isValid ? result.newState : null;
  }

  /// Directly update the game state (used by tests and local state injection).
  void updateState(GameState newState) {
    _appliedVersion = _versionOf(newState);
    state = newState;
  }

  /// Clear the game state (e.g., on game exit).
  void clearState() {
    _localSession?.dispose();
    _localSession = null;
    state = null;
    _gameType = null;
    _appliedVersion = -1;
  }

  @override
  void dispose() {
    // GameScreen.dispose invalidates gameStateProvider, which lands here —
    // tear the practice session down with the notifier so no bot timer keeps
    // firing into a disposed StateNotifier.
    _gameStateSub?.cancel();
    _gameStateSub = null;
    _localSession?.dispose();
    _localSession = null;
    super.dispose();
  }
}

/// Deserialize raw JSON state_data into the appropriate typed GameState.
GameState? deserializeGameState(String gameType, Map<String, dynamic> json) {
  try {
    switch (gameType) {
      case 'twenty_nine':
        return TwentyNineState.fromJson(json);
      case 'oh_hell':
        return OhHellState.fromJson(json);
      case 'bridge':
        return BridgeState.fromJson(json);
      case 'ludo':
        return LudoState.fromJson(json);
      // TODO: Add fromJson for other game types as they are implemented
      default:
        return null;
    }
  } catch (e, st) {
    // Log deserialization errors for debugging
    print('[deserializeGameState] ERROR for $gameType: $e');
    print('[deserializeGameState] Stack: $st');
    return null;
  }
}

class BidMoveDto {
  final String playerId;
  final int bidValue;

  const BidMoveDto({required this.playerId, required this.bidValue});

  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'player_id': playerId,
        'bid_value': bidValue,
      };
}
