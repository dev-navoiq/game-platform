import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [ReactionRepository].
class SupabaseReactionRepository implements ReactionRepository {
  final SupabaseClient _client;

  SupabaseReactionRepository(this._client);

  @override
  Future<void> sendReaction({
    required String roomId,
    required String userId,
    required String reaction,
  }) async {
    await _client.from('quick_reactions').insert({
      'room_id': roomId,
      'user_id': userId,
      'reaction': reaction,
    });
  }

  @override
  Stream<List<Reaction>> watchReactions({required String roomId}) {
    return _client
        .from('quick_reactions')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((rows) {
      final reactions = rows.map((r) => Reaction.fromJson(r)).toList();
      reactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return reactions;
    });
  }
}
