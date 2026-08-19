import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../data/tournament_models.dart';
import '../data/tournament_repository.dart';

/// Emits a new version whenever any `tournaments` row changes. Shared change
/// signal: the list/detail providers watch this so new tournaments and status
/// transitions (registration → in_progress) show up without a manual refresh.
/// Debounced because current_participants updates once per registration, so
/// bursts are common.
final _tournamentsChangesProvider = StreamProvider<int>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final controller = StreamController<int>();
  var version = 0;
  Timer? debounce;

  final channel = supabase.channel('public:tournaments:changes')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tournaments',
      callback: (_) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 300), () {
          if (!controller.isClosed) controller.add(++version);
        });
      },
    )
    ..subscribe();

  // Watchdog bump: if the socket dies silently (iOS lock/suspend — #280) the
  // channel never fires again and every watcher of this signal freezes. A
  // slow unconditional bump keeps list/detail refetching regardless of
  // channel health; the reads it triggers are the same cheap REST queries.
  final backstop = Timer.periodic(const Duration(seconds: 20), (_) {
    if (!controller.isClosed) controller.add(++version);
  });

  ref.onDispose(() {
    debounce?.cancel();
    backstop.cancel();
    supabase.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

/// Repository provider — always available (read queries don't require auth).
final tournamentRepositoryProvider = Provider<TournamentRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return TournamentRepository(supabase: supabase);
});

/// Upcoming tournaments (status: registration or starting). Refetches on any
/// tournaments-table change via [_tournamentsChangesProvider].
final upcomingTournamentsProvider =
    FutureProvider.autoDispose.family<List<Tournament>, String?>(
        (ref, gameType) async {
  ref.watch(_tournamentsChangesProvider);
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getUpcomingTournaments(gameType: gameType);
});

/// Live tournaments (status: in_progress). Live like
/// [upcomingTournamentsProvider].
final liveTournamentsProvider =
    FutureProvider.autoDispose.family<List<Tournament>, String?>(
        (ref, gameType) async {
  ref.watch(_tournamentsChangesProvider);
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getLiveTournaments(gameType: gameType);
});

/// Completed tournaments. Live like [upcomingTournamentsProvider].
final completedTournamentsProvider =
    FutureProvider.autoDispose.family<List<Tournament>, String?>(
        (ref, gameType) async {
  ref.watch(_tournamentsChangesProvider);
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getCompletedTournaments(gameType: gameType);
});

/// Tournaments the current user is registered in.
final myTournamentsProvider = FutureProvider.autoDispose<List<Tournament>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];

  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getMyTournaments(userId);
});

/// Single tournament detail. Watches the change signal so status transitions
/// (e.g. auto-start via tournament-tick) and the participant counter reach an
/// open detail screen.
final tournamentDetailProvider =
    FutureProvider.autoDispose.family<Tournament?, String>((ref, tournamentId) async {
  ref.watch(_tournamentsChangesProvider);
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getTournament(tournamentId);
});

/// Participants for a tournament (live — refetches on realtime changes so
/// other users' registrations/withdrawals show up without a manual refresh).
final tournamentParticipantsProvider =
    StreamProvider.autoDispose.family<List<TournamentParticipant>, String>(
        (ref, tournamentId) {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.watchParticipants(tournamentId);
});

/// Teams (with members, captain first) for 2v2 tournaments. Live like
/// [tournamentParticipantsProvider].
final tournamentTeamsProvider =
    StreamProvider.autoDispose.family<List<TournamentTeam>, String>(
        (ref, tournamentId) {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.watchTeams(tournamentId);
});

/// Current user's participation in a tournament (null if not registered).
final myParticipationProvider =
    FutureProvider.autoDispose.family<TournamentParticipant?, String>(
        (ref, tournamentId) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;

  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getParticipation(tournamentId, userId);
});

/// Bracket matches for a tournament.
final tournamentBracketProvider =
    FutureProvider.family<List<TournamentMatch>, String>(
        (ref, tournamentId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getBracket(tournamentId);
});

/// Live bracket stream.
final tournamentBracketStreamProvider =
    StreamProvider.family<List<TournamentMatch>, String>(
        (ref, tournamentId) {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.watchBracket(tournamentId);
});

/// Tournament chat messages.
final tournamentChatProvider =
    FutureProvider.family<List<TournamentChatMessage>, String>(
        (ref, tournamentId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getChatMessages(tournamentId);
});

/// Live chat stream.
final tournamentChatStreamProvider =
    StreamProvider.family<List<TournamentChatMessage>, String>(
        (ref, tournamentId) {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.watchChat(tournamentId);
});
