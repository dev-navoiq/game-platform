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

  Future<TournamentRegistrationResult> register(
    String tournamentId,
    String userId,
  ) async {
    try {
      final tournament = await getTournament(tournamentId);
      if (tournament == null) {
        return TournamentRegistrationResult.tournamentNotFound;
      }

      if (!tournament.isRegistrationOpen) {
        if (tournament.isFull) {
          return TournamentRegistrationResult.tournamentFull;
        }
        return TournamentRegistrationResult.registrationClosed;
      }

      // Deduct entry fee via edge function (handles coin/gem validation)
      if (!tournament.isFree) {
        final canAfford = await _checkBalance(
          userId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
        if (!canAfford) {
          return TournamentRegistrationResult.insufficientFunds;
        }

        await _deductEntryFee(
          userId,
          tournamentId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
      }

      await _supabase.from('tournament_participants').insert({
        'tournament_id': tournamentId,
        'user_id': userId,
      });

      return TournamentRegistrationResult.success;
    } catch (e) {
      if (e.toString().contains('duplicate')) {
        return TournamentRegistrationResult.alreadyRegistered;
      }
      return TournamentRegistrationResult.error;
    }
  }

  Future<bool> unregister(String tournamentId, String userId) async {
    try {
      final tournament = await getTournament(tournamentId);
      if (tournament == null ||
          tournament.status != TournamentStatus.registration) {
        return false;
      }

      // Refund entry fee
      if (!tournament.isFree) {
        await _refundEntryFee(
          userId,
          tournamentId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
      }

      await _supabase
          .from('tournament_participants')
          .delete()
          .eq('tournament_id', tournamentId)
          .eq('user_id', userId);

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

  // ── Currency helpers ───────────────────────────────────────────────────────

  Future<bool> _checkBalance(String userId, int coins, int gems) async {
    final response = await _supabase
        .from('profiles')
        .select('coins, gems')
        .eq('id', userId)
        .single();

    return (response['coins'] as int) >= coins &&
        (response['gems'] as int) >= gems;
  }

  Future<void> _deductEntryFee(
    String userId,
    String tournamentId,
    int coins,
    int gems,
  ) async {
    // Direct SQL update for now; in production use an RPC for atomicity
    if (coins > 0) {
      await _supabase.rpc('spend_currency', params: {
        'p_user_id': userId,
        'p_amount': coins,
        'p_currency': 'coins',
        'p_reason': 'Tournament entry fee',
        'p_reference_id': tournamentId,
      });
    }
    if (gems > 0) {
      await _supabase.rpc('spend_currency', params: {
        'p_user_id': userId,
        'p_amount': gems,
        'p_currency': 'gems',
        'p_reason': 'Tournament entry fee',
        'p_reference_id': tournamentId,
      });
    }
  }

  Future<void> _refundEntryFee(
    String userId,
    String tournamentId,
    int coins,
    int gems,
  ) async {
    if (coins > 0) {
      await _supabase.rpc('earn_currency', params: {
        'p_user_id': userId,
        'p_amount': coins,
        'p_currency': 'coins',
        'p_reason': 'Tournament entry fee refund',
        'p_reference_id': tournamentId,
      });
    }
    if (gems > 0) {
      await _supabase.rpc('earn_currency', params: {
        'p_user_id': userId,
        'p_amount': gems,
        'p_currency': 'gems',
        'p_reason': 'Tournament entry fee refund',
        'p_reference_id': tournamentId,
      });
    }
  }
}
