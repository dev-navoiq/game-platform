import 'package:supabase_flutter/supabase_flutter.dart';

import 'tournament_models.dart';

class TournamentRepository {
  final SupabaseClient _supabase;

  TournamentRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<List<Tournament>> getUpcomingTournaments({
    String? gameType,
    int limit = 20,
  }) async {
    var query = _supabase
        .from('tournaments')
        .select()
        .inFilter('status', ['registration', 'starting']);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query
        .order('start_time', ascending: true)
        .limit(limit);
    return response.map((r) => Tournament.fromJson(r)).toList();
  }

  Future<List<Tournament>> getLiveTournaments({String? gameType}) async {
    var query = _supabase
        .from('tournaments')
        .select()
        .eq('status', 'in_progress');

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query
        .order('start_time', ascending: true);
    return response.map((r) => Tournament.fromJson(r)).toList();
  }

  Future<List<Tournament>> getCompletedTournaments({
    String? gameType,
    int limit = 20,
  }) async {
    var query = _supabase
        .from('tournaments')
        .select()
        .eq('status', 'completed');

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query
        .order('end_time', ascending: false)
        .limit(limit);
    return response.map((r) => Tournament.fromJson(r)).toList();
  }

  Future<List<Tournament>> getMyTournaments(String userId) async {
    final response = await _supabase
        .from('tournament_participants')
        .select('tournament:tournaments(*)')
        .eq('user_id', userId)
        .order('registered_at', ascending: false);

    return response
        .map((r) => Tournament.fromJson(r['tournament'] as Map<String, dynamic>))
        .toList();
  }

  Future<Tournament?> getTournament(String id) async {
    final response = await _supabase
        .from('tournaments')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? Tournament.fromJson(response) : null;
  }

  // ── Participants ───────────────────────────────────────────────────────────

  Future<List<TournamentParticipant>> getParticipants(
    String tournamentId,
  ) async {
    final response = await _supabase
        .from('tournament_participants')
        .select('*, profile:profiles!user_id(username, avatar_url)')
        .eq('tournament_id', tournamentId)
        .order('seed', ascending: true, nullsFirst: false);

    return response
        .map((r) => TournamentParticipant.fromJson(r))
        .toList();
  }

  Future<TournamentParticipant?> getParticipation(
    String tournamentId,
    String userId,
  ) async {
    final response = await _supabase
        .from('tournament_participants')
        .select('*, profile:profiles!user_id(username, avatar_url)')
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null
        ? TournamentParticipant.fromJson(response)
        : null;
  }

  // ── Registration ───────────────────────────────────────────────────────────

  // Registration is fully server-authoritative: the `tournament-register`
  // edge function debits the entry fee (coins/gems), enforces tier / gem-gate /
  // capacity, and writes the participant + entry ledger atomically. `userId` is
  // taken from the auth JWT server-side; the param is kept for call-site compat.
  Future<TournamentRegistrationResult> register(
    String tournamentId,
    String userId,
  ) async {
    try {
      await _supabase.functions.invoke(
        'tournament-register',
        body: {'tournament_id': tournamentId},
      );
      return TournamentRegistrationResult.success;
    } on FunctionException catch (e) {
      return _mapRegisterError(e);
    } catch (_) {
      return TournamentRegistrationResult.error;
    }
  }

  TournamentRegistrationResult _mapRegisterError(FunctionException e) {
    final details = e.details;
    final code = details is Map ? details['code'] as String? : null;
    switch (code) {
      case 'REGISTRATION_CLOSED':
        return TournamentRegistrationResult.registrationClosed;
      case 'TOURNAMENT_FULL':
        return TournamentRegistrationResult.tournamentFull;
      case 'ALREADY_REGISTERED':
        return TournamentRegistrationResult.alreadyRegistered;
      case 'INSUFFICIENT_FUNDS':
        return TournamentRegistrationResult.insufficientFunds;
      case 'NOT_FOUND':
        return TournamentRegistrationResult.tournamentNotFound;
      case 'TIER_REQUIRED':
        return TournamentRegistrationResult.tierRequired;
      default:
        // REGISTERED_REQUIRED / TOO_MANY_ACTIVE_TOURNAMENTS
        return TournamentRegistrationResult.error;
    }
  }

  // Unregister + refund is handled server-side by `tournament-unregister`.
  Future<bool> unregister(String tournamentId, String userId) async {
    try {
      await _supabase.functions.invoke(
        'tournament-unregister',
        body: {'tournament_id': tournamentId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Bracket / Matches ──────────────────────────────────────────────────────

  Future<List<TournamentMatch>> getBracket(String tournamentId) async {
    final response = await _supabase
        .from('tournament_matches')
        .select('''
          *,
          player1:profiles!player1_id(username, avatar_url),
          player2:profiles!player2_id(username, avatar_url)
        ''')
        .eq('tournament_id', tournamentId)
        .order('round', ascending: true)
        .order('match_number', ascending: true);

    return response.map((r) => TournamentMatch.fromJson(r)).toList();
  }

  Stream<List<TournamentMatch>> watchBracket(String tournamentId) {
    return _supabase
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .map((data) => data.map((r) => TournamentMatch.fromJson(r)).toList());
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<List<TournamentChatMessage>> getChatMessages(
    String tournamentId, {
    int limit = 50,
  }) async {
    final response = await _supabase
        .from('tournament_chat')
        .select('*, sender:profiles!sender_id(username, avatar_url)')
        .eq('tournament_id', tournamentId)
        .order('created_at', ascending: false)
        .limit(limit);

    return response
        .map((r) => TournamentChatMessage.fromJson(r))
        .toList()
        .reversed
        .toList();
  }

  Future<void> sendChatMessage(
    String tournamentId,
    String senderId,
    String content, {
    bool isAnnouncement = false,
  }) async {
    await _supabase.from('tournament_chat').insert({
      'tournament_id': tournamentId,
      'sender_id': senderId,
      'content': content,
      'is_announcement': isAnnouncement,
    });
  }

  Stream<List<TournamentChatMessage>> watchChat(String tournamentId) {
    return _supabase
        .from('tournament_chat')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .order('created_at', ascending: true)
        .map((data) =>
            data.map((r) => TournamentChatMessage.fromJson(r)).toList());
  }

}
