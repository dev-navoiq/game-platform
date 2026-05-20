import 'reaction.dart';

/// Abstract interface for emoji reaction persistence.
///
/// Implementations handle the actual storage backend (e.g. Supabase).
abstract class ReactionRepository {
  /// Send an emoji reaction in a room.
  Future<void> sendReaction({
    required String roomId,
    required String userId,
    required String reaction,
  });

  /// Watch reactions in a room as a stream.
  Stream<List<Reaction>> watchReactions({required String roomId});
}
