import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/favorites_repository.dart';

/// Repository provider — requires an authenticated user.
final favoritesRepositoryProvider = Provider<FavoritesRepository?>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;

  final supabase = ref.watch(supabaseProvider);
  return FavoritesRepository(supabase: supabase, userId: userId);
});

/// Current user's favorite game types, kept in sync via [FavoritesNotifier].
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return FavoritesNotifier(repo);
});

/// Quick check: is [gameType] in the user's favorites?
final isFavoriteProvider = Provider.family<bool, String>((ref, gameType) {
  final favorites = ref.watch(favoritesProvider);
  return favorites.contains(gameType);
});

// ── Notifier ──────────────────────────────────────────────────────────────

class FavoritesNotifier extends StateNotifier<List<String>> {
  final FavoritesRepository? _repo;

  FavoritesNotifier(this._repo) : super([]) {
    _load();
  }

  Future<void> _load() async {
    if (_repo == null) return;
    try {
      state = await _repo!.getFavoriteGames();
    } catch (_) {
      // Keep empty list on failure
    }
  }

  Future<void> toggle(String gameType) async {
    // Optimistic update
    if (state.contains(gameType)) {
      state = state.where((g) => g != gameType).toList();
    } else {
      state = [...state, gameType];
    }

    if (_repo == null) return;
    try {
      await _repo!.toggleFavorite(gameType);
    } catch (_) {
      // Revert on error
      await _load();
    }
  }

  Future<void> add(String gameType) async {
    if (state.contains(gameType)) return;
    state = [...state, gameType];

    if (_repo == null) return;
    try {
      await _repo!.addFavorite(gameType);
    } catch (_) {
      await _load();
    }
  }

  Future<void> remove(String gameType) async {
    state = state.where((g) => g != gameType).toList();

    if (_repo == null) return;
    try {
      await _repo!.removeFavorite(gameType);
    } catch (_) {
      await _load();
    }
  }

  Future<void> refresh() => _load();
}
