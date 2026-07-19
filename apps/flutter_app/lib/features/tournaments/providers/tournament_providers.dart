import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/tournament_models.dart';
import '../data/tournament_repository.dart';

/// Repository provider — always available (read queries don't require auth).
final tournamentRepositoryProvider = Provider<TournamentRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return TournamentRepository(supabase: supabase);
});

/// Upcoming tournaments (status: registration or starting).
final upcomingTournamentsProvider =
    FutureProvider.family<List<Tournament>, String?>(
        (ref, gameType) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getUpcomingTournaments(gameType: gameType);
});

/// Live tournaments (status: in_progress).
final liveTournamentsProvider =
    FutureProvider.family<List<Tournament>, String?>(
        (ref, gameType) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getLiveTournaments(gameType: gameType);
});

/// Completed tournaments.
final completedTournamentsProvider =
    FutureProvider.family<List<Tournament>, String?>(
        (ref, gameType) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getCompletedTournaments(gameType: gameType);
});

/// Tournaments the current user is registered in.
final myTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];

  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getMyTournaments(userId);
});

/// Single tournament detail.
final tournamentDetailProvider =
    FutureProvider.family<Tournament?, String>((ref, tournamentId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getTournament(tournamentId);
});

/// Participants for a tournament.
final tournamentParticipantsProvider =
    FutureProvider.family<List<TournamentParticipant>, String>(
        (ref, tournamentId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getParticipants(tournamentId);
});

/// Teams (with members, captain first) for 2v2 tournaments.
final tournamentTeamsProvider =
    FutureProvider.family<List<TournamentTeam>, String>(
        (ref, tournamentId) async {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo.getTeams(tournamentId);
});

/// Current user's participation in a tournament (null if not registered).
final myParticipationProvider =
    FutureProvider.family<TournamentParticipant?, String>(
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
