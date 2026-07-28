import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/lobby/models/room_member.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

/// Handle for a self-healing game-state subscription (see
/// [SupabaseService.subscribeToGameState]). Cancel to stop the stream,
/// reconnect attempts, and the staleness watchdog together.
class GameStateSubscription {
  GameStateSubscription._();

  /// Inert handle for tests/mocks — carries no stream, timers, or watchdog.
  GameStateSubscription.inert() : _disposed = true;
  bool _disposed = false;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _watchdog;

  void cancel() {
    _disposed = true;
    _sub?.cancel();
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
  }
}

/// Server-side rejection of a move (validate-move 4xx). Carries the
/// structured `code` (e.g. NOT_YOUR_TURN, WRONG_PHASE, VERSION_CONFLICT,
/// FORBIDDEN_BID) so the bot move controller can decide whether to retry
/// vs. log-and-skip, and so the UI can show actionable text.
class MoveRejection implements Exception {
  final String code;
  final String message;
  const MoveRejection({required this.code, required this.message});

  @override
  String toString() => 'MoveRejection($code): $message';
}

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  // ── Auth ──────────────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;

  Future<String> signInAsGuest() async {
    final response = await _client.auth.signInAnonymously();
    return response.user!.id;
  }

  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user!.id;
  }

  Future<Map<String, dynamic>> getProfile({String? userId}) async {
    final uid = userId ?? _client.auth.currentUser!.id;
    final response =
        await _client.from('profiles').select().eq('id', uid).single();
    return response;
  }

  // ── Rooms (via edge functions) ────────────────────────────────────────────

  Future<Map<String, dynamic>> createRoom({
    required String gameType,
    required String socialMode,
    int maxPlayers = 4,
    bool isPrivate = false,
    String? password,
    Map<String, dynamic>? config,
  }) async {
    final response = await _client.functions.invoke(
      'create-room',
      body: {
        'game_type': gameType,
        'social_mode': socialMode,
        'max_players': maxPlayers,
        'is_private': isPrivate,
        if (password != null) 'password': password,
        if (config != null) 'config': config,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinRoom({
    String? roomId,
    String? roomCode,
    String? password,
    bool asSpectator = false,
  }) async {
    final response = await _client.functions.invoke(
      'join-room',
      body: {
        if (roomId != null) 'room_id': roomId,
        if (roomCode != null) 'room_code': roomCode,
        if (password != null) 'password': password,
        'as_spectator': asSpectator,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Leave a room via the `leave-room` edge function.
  ///
  /// The edge function handles the lifecycle correctly: in a lobby room it
  /// removes the row; in a 'playing' room it parks the slot (sets
  /// `disconnected_at`) and appends a substitute bot inheriting the user's
  /// ID so the table keeps moving. It also transfers host if needed and
  /// abandons the room when no live humans remain.
  ///
  /// [reason] is forwarded as analytics + future UX hint. Default `'left'`
  /// covers voluntary lobby exits; the Forfeit button passes `'forfeited'`.
  Future<void> leaveRoom({
    required String roomId,
    String reason = 'left',
  }) async {
    await _client.functions.invoke(
      'leave-room',
      body: {
        'room_id': roomId,
        'reason': reason,
      },
    );
  }

  /// Fetch the shareable 6-character room code for a given room UUID.
  /// Used after create-room (where the code is in the response anyway, but
  /// we may not have plumbed it through) and after join-by-code where we
  /// only know the code, not the UUID.
  Future<String> getRoomCode({required String roomId}) async {
    final row = await _client
        .from('game_rooms')
        .select('code')
        .eq('id', roomId)
        .single();
    return row['code'] as String;
  }

  /// Add a bot player to the room via server-side RPC.
  /// Inserts into room_players so the bot counts toward the player total.
  /// Returns the generated bot UUID.
  Future<String> addBot({
    required String roomId,
    required String difficulty,
  }) async {
    final botId = await _client.rpc('add_bot_to_room', params: {
      'p_room_id': roomId,
      'p_difficulty': difficulty,
    });
    return botId as String;
  }

  Future<void> updateRoomSocialMode({
    required String roomId,
    required String mode,
  }) async {
    await _client.from('game_rooms').update({
      'social_mode': mode,
    }).eq('id', roomId);
  }

  void subscribeToRoom({
    required String roomId,
    required Function onUpdate,
  }) {
    _client
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((data) {
          if (data.isNotEmpty) {
            onUpdate(data.first);
          }
        });
  }

  /// One-shot reconciliation: pulls room metadata + roster and stitches
  /// humans (room_players) + bots (game_rooms.config.bots) into a single
  /// ordered member list.
  Future<RoomSnapshot> fetchRoomSnapshot({required String roomId}) async {
    final room = await _client
        .from('game_rooms')
        .select(
            'code, social_mode, status, created_by, config, game_type, max_players')
        .eq('id', roomId)
        .single();

    // Disambiguate the embedded join: as of the 2026-06-09 migration,
    // room_players has TWO foreign keys to profiles — user_id (the seat
    // owner) and original_user_id (set when a bot subs in). PostgREST
    // returns PGRST201 if we ask for `profiles(...)` without naming which
    // relationship to follow. Force the user_id FK.
    final players = await _client
        .from('room_players')
        .select(
          'user_id, seat_index, is_ready, is_spectator, '
          'profiles!room_players_user_id_fkey(display_name, username)',
        )
        .eq('room_id', roomId)
        .order('seat_index');

    final hostId = room['created_by'] as String;
    final currentUserId = _client.auth.currentUser?.id;
    final config = room['config'] as Map<String, dynamic>?;
    final bots = (config?['bots'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    final members = <RoomMember>[];

    for (final p in players as List) {
      final row = p as Map<String, dynamic>;
      final userId = row['user_id'] as String;
      final profile = row['profiles'] as Map<String, dynamic>?;
      final name = (profile?['display_name'] as String?) ??
          (profile?['username'] as String?) ??
          'Player';
      members.add(RoomMember(
        id: userId,
        displayName: name,
        seatIndex: row['seat_index'] as int,
        isHost: userId == hostId,
        isBot: false,
        isReady: (row['is_ready'] as bool?) ?? false,
        isCurrentUser: userId == currentUserId,
        isSpectator: (row['is_spectator'] as bool?) ?? false,
      ));
    }

    for (final b in bots) {
      members.add(RoomMember(
        id: b['id'] as String,
        displayName: 'Bot',
        seatIndex: (b['seat_index'] as int?) ?? members.length,
        isHost: false,
        isBot: true,
        isReady: true,
        isCurrentUser: false,
        botDifficulty: b['difficulty'] as String?,
      ));
    }

    members.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

    return RoomSnapshot(
      roomCode: room['code'] as String,
      socialMode: room['social_mode'] as String,
      status: room['status'] as String,
      gameType: room['game_type'] as String,
      maxPlayers: (room['max_players'] as int?) ?? 4,
      members: members,
      tournamentId: config?['tournament_id'] as String?,
    );
  }

  /// Streams realtime changes affecting the room roster. Fires the callback
  /// whenever either `room_players` (humans joining/leaving/readying) or
  /// `game_rooms` (host changing social mode, bot list updating, status
  /// transitioning) changes for this room. The caller reloads the snapshot
  /// inside the callback.
  ///
  /// Returns a dispose function that tears down both underlying subscriptions.
  /// Must be invoked from the screen's `dispose()`.
  void Function() subscribeToRoomMembership({
    required String roomId,
    required void Function() onChanged,
  }) {
    final playersSub = _client
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .listen((_) => onChanged());

    final roomSub = _client
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((_) => onChanged());

    return () {
      playersSub.cancel();
      roomSub.cancel();
    };
  }

  // ── Game ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startGame({required String roomId}) async {
    final response = await _client.functions.invoke(
      'start-game',
      body: {'room_id': roomId},
    );
    return response.data as Map<String, dynamic>;
  }

  GameStateSubscription subscribeToGameState({
    required String roomId,
    required Function onUpdate,
  }) {
    final handle = GameStateSubscription._();
    var attempt = 0;

    // One-shot catch-up read. Run on every (re)connect and by the watchdog:
    // realtime rows missed while the socket was down are unrecoverable from
    // the stream itself, so the current row is the source of truth.
    Future<void> fetchCurrent() async {
      try {
        final rows = await _client
            .from('game_states')
            .select()
            .eq('room_id', roomId)
            .limit(1);
        if (!handle._disposed && rows.isNotEmpty) onUpdate(rows.first);
      } catch (_) {
        // Transient REST failure — the watchdog will try again.
      }
    }

    late void Function() connect;
    void scheduleReconnect() {
      if (handle._disposed || handle._reconnectTimer != null) return;
      attempt++;
      final delay = Duration(seconds: attempt < 5 ? 1 << attempt : 30);
      handle._reconnectTimer = Timer(delay, () {
        handle._reconnectTimer = null;
        connect();
        fetchCurrent();
      });
    }

    connect = () {
      if (handle._disposed) return;
      handle._sub?.cancel();
      handle._sub = _client
          .from('game_states')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .listen(
            (data) {
              attempt = 0;
              if (data.isNotEmpty) onUpdate(data.first);
            },
            // A dead channel used to end the stream silently and the table
            // froze until re-login (#180). Any error/close now reconnects
            // with backoff and catches up via REST.
            onError: (_) => scheduleReconnect(),
            onDone: scheduleReconnect,
            cancelOnError: false,
          );
    };

    connect();
    // Watchdog: some socket deaths emit neither error nor done — the stream
    // just goes quiet. A slow poll guarantees the table can never stay stale
    // for more than ~25s no matter how the channel died.
    handle._watchdog = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!handle._disposed) fetchCurrent();
    });
    return handle;
  }

  Future<Map<String, dynamic>> sendMove({
    required String roomId,
    required dynamic move,
  }) async {
    final body = {
      'room_id': roomId,
      'move': move is Map ? move : (move as dynamic).toJson(),
    };
    try {
      final response = await _client.functions.invoke(
        'validate-move',
        body: body,
      );
      final data = (response.data as Map<String, dynamic>?) ?? const {};
      // Rule-level validation rejections (validate-move returns 400 with
      // jsonResponse(validationResult)) carry `error_code` rather than
      // `code`. Detect & raise so the bot path retries / logs / surfaces.
      if (data['valid'] == false ||
          data['error_code'] is String ||
          data['code'] is String) {
        throw MoveRejection(
          code: (data['error_code'] as String?) ??
              (data['code'] as String?) ??
              'UNKNOWN',
          message: (data['error'] as String?) ?? 'Move rejected',
        );
      }
      return data;
    } on FunctionException catch (e) {
      // supabase_flutter throws FunctionException for non-2xx responses
      // from edge functions. The body is in e.details. Normalize to
      // MoveRejection so callers don't have to special-case the transport.
      final details = e.details;
      if (details is Map) {
        throw MoveRejection(
          code: (details['error_code'] as String?) ??
              (details['code'] as String?) ??
              'HTTP_${e.status}',
          message:
              (details['error'] as String?) ?? e.reasonPhrase ?? 'Move rejected',
        );
      }
      throw MoveRejection(
        code: 'HTTP_${e.status}',
        message: e.reasonPhrase ?? 'Move rejected',
      );
    }
  }

  Future<Map<String, dynamic>> reconcileState({
    required String roomId,
  }) async {
    final response = await _client.functions.invoke(
      'reconcile-state',
      body: {'room_id': roomId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Matchmaking ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> findMatch({
    required String gameType,
    int? playerCount,
  }) async {
    final response = await _client.functions.invoke(
      'matchmaking',
      body: {
        'game_type': gameType,
        if (playerCount != null) 'player_count': playerCount,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestVoiceToken({
    required String roomId,
  }) async {
    final response = await _client.functions.invoke(
      'voice-token',
      body: {'room_id': roomId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Economy ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> claimDailyBonus() async {
    final response = await _client.functions.invoke(
      'claim-daily-bonus',
      body: {},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimChallengeReward({
    required String challengeId,
  }) async {
    final response = await _client.functions.invoke(
      'claim-challenge-reward',
      body: {'challenge_id': challengeId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordReferral({
    required String referralCode,
  }) async {
    final response = await _client.functions.invoke(
      'record-referral',
      body: {'referral_code': referralCode},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimSeasonReward({
    required String seasonId,
    required int level,
  }) async {
    final response = await _client.functions.invoke(
      'grant-season-reward',
      body: {'season_id': seasonId, 'level': level},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> insertChatMessage({
    required String roomId,
    required String message,
    required String senderId,
  }) async {
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'content': message,
      'user_id': senderId,
    });
  }

  void subscribeToRoomMessages({
    required String roomId,
    required Function onMessage,
  }) {
    _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .listen((data) {
          for (final msg in data) {
            onMessage(msg);
          }
        });
  }
}
