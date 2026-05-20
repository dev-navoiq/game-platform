import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user's favorite games.
class FavoritesRepository {
  final SupabaseClient _supabase;
  final String _userId;

  FavoritesRepository({
    required SupabaseClient supabase,
    required String userId,
  })  : _supabase = supabase,
        _userId = userId;

  Future<List<String>> getFavoriteGames() async {
    final response = await _supabase
        .from('user_favorites')
        .select('game_type')
        .eq('user_id', _userId)
        .order('favorited_at', ascending: false);

    return response.map((r) => r['game_type'] as String).toList();
  }

  Future<bool> isFavorite(String gameType) async {
    final response = await _supabase
        .from('user_favorites')
        .select('id')
        .eq('user_id', _userId)
        .eq('game_type', gameType)
        .maybeSingle();

    return response != null;
  }

  Future<void> addFavorite(String gameType) async {
    await _supabase.from('user_favorites').upsert({
      'user_id': _userId,
      'game_type': gameType,
    });
  }

  Future<void> removeFavorite(String gameType) async {
    await _supabase
        .from('user_favorites')
        .delete()
        .eq('user_id', _userId)
        .eq('game_type', gameType);
  }

  Future<void> toggleFavorite(String gameType) async {
    if (await isFavorite(gameType)) {
      await removeFavorite(gameType);
    } else {
      await addFavorite(gameType);
    }
  }
}
