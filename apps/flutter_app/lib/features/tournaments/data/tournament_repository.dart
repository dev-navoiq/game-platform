import 'dart:async';

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

  // Live roster. `.stream()` can't express the profiles join, so a realtime
  // channel on the underlying tables drives full refetches instead. Requires
  // the tables to be in the supabase_realtime publication with replica
  // identity full (20260721000000_tournament_roster_realtime.sql) — without
  // FULL, withdrawal DELETEs don't carry tournament_id and never match the
  // channel filter.
  Stream<List<TournamentParticipant>> watchParticipants(String tournamentId) {
    return _refetchOnChange(
      channelName: 'tournament_participants:$tournamentId',
      tables: ['tournament_participants'],
      tournamentId: tournamentId,
      fetch: () => getParticipants(tournamentId),
    );
  }

  // Team membership is derived from participants, so both tables feed it.
  Stream<List<TournamentTeam>> watchTeams(String tournamentId) {
    return _refetchOnChange(
      channelName: 'tournament_teams:$tournamentId',
      tables: ['tournament_teams', 'tournament_participants'],
      tournamentId: tournamentId,
      fetch: () => getTeams(tournamentId),
    );
  }

  Stream<T> _refetchOnChange<T>({
    required String channelName,
    required List<String> tables,
    required String tournamentId,
    required Future<T> Function() fetch,
  }) {
    final controller = StreamController<T>();
    var fetching = false;
    var dirty = false;

    // Coalesce bursts: one refetch in flight at a time, and events landing
    // mid-fetch trigger exactly one follow-up so the last emit is fresh.
    Future<void> refetch() async {
      if (fetching) {
        dirty = true;
        return;
      }
      fetching = true;
      try {
        final result = await fetch();
        if (!controller.isClosed) controller.add(result);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      } finally {
        fetching = false;
        if (dirty && !controller.isClosed) {
          dirty = false;
          unawaited(refetch());
        }
      }
    }

    var channel = _supabase.channel(channelName);
    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tournament_id',
          value: tournamentId,
        ),
        callback: (_) => refetch(),
      );
    }

    controller
      ..onListen = () {
        channel.subscribe();
        refetch();
      }
      ..onCancel = () async {
        await _supabase.removeChannel(channel);
      };
    return controller.stream;
  }

  // ── Registration ───────────────────────────────────────────────────────────

  // Registration is fully server-authoritative: the `tournament-register`
  // edge function debits the entry fee (coins/gems), enforces tier / gem-gate /
  // capacity, and writes the participant + entry ledger atomically. `userId` is
  // taken from the auth JWT server-side; the param is kept for call-site compat.
  // Team tournaments (team_size = 2): pass `createTeam` to open a new team,
  // `joinTeamId` to fill an open one, or neither for a solo entry (server
  // pairs solos at start when the tournament allows it).
  Future<TournamentRegistrationResult> register(
    String tournamentId,
    String userId, {
    bool createTeam = false,
    String? joinTeamId,
  }) async {
    try {
      await _supabase.functions.invoke(
        'tournament-register',
        body: {
          'tournament_id': tournamentId,
          if (createTeam) 'create_team': true,
          if (joinTeamId != null) 'join_team': joinTeamId,
        },
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
      case 'REGISTERED_REQUIRED':
        return TournamentRegistrationResult.registeredRequired;
      case 'TEAM_REQUIRED':
        return TournamentRegistrationResult.teamRequired;
      case 'TEAM_FULL':
        return TournamentRegistrationResult.teamFull;
      case 'TEAM_NOT_FOUND':
        return TournamentRegistrationResult.teamNotFound;
      default:
        // TOO_MANY_ACTIVE_TOURNAMENTS etc.
        return TournamentRegistrationResult.error;
    }
  }

  // ── Teams (2v2 tournaments) ────────────────────────────────────────────────

  // Teams with members (captain first). Members come from participants so the
  // list reflects live membership, not just team rows.
  Future<List<TournamentTeam>> getTeams(String tournamentId) async {
    final teamRows = await _supabase
        .from('tournament_teams')
        .select()
        .eq('tournament_id', tournamentId)
        .order('created_at', ascending: true);
    if (teamRows.isEmpty) return [];

    final participants = await getParticipants(tournamentId);
    final byTeam = <String, List<TournamentParticipant>>{};
    for (final p in participants) {
      if (p.teamId != null) {
        byTeam.putIfAbsent(p.teamId!, () => []).add(p);
      }
    }

    return teamRows.map((r) {
      final id = r['id'] as String;
      final captainId = r['captain_id'] as String;
      final members = byTeam[id] ?? const <TournamentParticipant>[];
      members.sort((a, b) => a.userId == captainId ? -1 : (b.userId == captainId ? 1 : 0));
      return TournamentTeam.fromJson(r, members: members);
    }).toList();
  }

  // Check in during the pre-start window (tournaments with check_in_minutes
  // > 0). Idempotent server-side.
  Future<bool> checkIn(String tournamentId) async {
    try {
      await _supabase.functions.invoke(
        'tournament-check-in',
        body: {'tournament_id': tournamentId},
      );
      return true;
    } catch (_) {
      return false;
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
