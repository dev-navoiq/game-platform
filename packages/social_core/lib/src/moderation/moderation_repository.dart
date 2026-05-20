import 'mute_vote.dart';

/// Abstract interface for moderation operations.
///
/// Implementations handle the actual storage backend (e.g. Supabase).
abstract class ModerationRepository {
  /// Cast a mute vote against a player in a room.
  Future<void> castMuteVote({
    required String roomId,
    required String voterId,
    required String targetId,
  });

  /// Get all mute votes for a target player in a room.
  Future<List<MuteVote>> getMuteVotes({
    required String roomId,
    required String targetId,
  });

  /// Check if a user is currently muted in a room.
  Future<bool> isUserMuted({
    required String roomId,
    required String userId,
  });

  /// Watch mute votes for a room as a stream.
  Stream<List<MuteVote>> watchMuteVotes({required String roomId});
}
