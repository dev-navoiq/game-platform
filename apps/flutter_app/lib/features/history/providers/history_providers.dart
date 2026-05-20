import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/history_repository.dart';

/// Repository provider — requires an authenticated user.
final historyRepositoryProvider = Provider<HistoryRepository?>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;

  final supabase = ref.watch(supabaseProvider);
  return HistoryRepository(supabase: supabase, userId: userId);
});

/// Paginated recent games, optionally filtered by game type.
final recentGamesProvider =
    FutureProvider.family<List<RecentGame>, String?>((ref, gameType) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo == null) return [];
  return repo.getRecentGames(gameType: gameType);
});

/// Distinct game types recently played (for "Recently Played" section).
final recentGameTypesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo == null) return [];
  return repo.getRecentlyPlayedGameTypes();
});

/// Aggregate stats, optionally filtered by game type.
final gameStatsProvider =
    FutureProvider.family<GameStats, String?>((ref, gameType) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo == null) return GameStats.empty;
  return repo.getStats(gameType: gameType);
});
