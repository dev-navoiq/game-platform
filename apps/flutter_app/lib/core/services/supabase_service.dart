import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

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

  Future<void> leaveRoom({required String roomId}) async {
    await _client.from('room_players').delete().match({
      'room_id': roomId,
      'user_id': _client.auth.currentUser!.id,
    });
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

  // ── Game ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startGame({required String roomId}) async {
    final response = await _client.functions.invoke(
      'start-game',
      body: {'room_id': roomId},
    );
    return response.data as Map<String, dynamic>;
  }

  void subscribeToGameState({
    required String roomId,
    required Function onUpdate,
  }) {
    _client
        .from('game_states')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .listen((data) {
          if (data.isNotEmpty) {
            onUpdate(data.first);
          }
        });
  }

  Future<Map<String, dynamic>> sendMove({
    required String roomId,
    required dynamic move,
  }) async {
    final response = await _client.functions.invoke(
      'validate-move',
      body: {
        'room_id': roomId,
        'move': move is Map ? move : (move as dynamic).toJson(),
      },
    );
    return response.data as Map<String, dynamic>;
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
