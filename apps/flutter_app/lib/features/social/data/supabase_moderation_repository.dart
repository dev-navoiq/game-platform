import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [ModerationRepository].
class SupabaseModerationRepository implements ModerationRepository {
  final SupabaseClient _client;

  SupabaseModerationRepository(this._client);

  @override
  Future<void> castMuteVote({
    required String roomId,
    required String voterId,
    required String targetId,
  }) async {
    await _client.from('mute_votes').insert({
      'room_id': roomId,
      'voter_id': voterId,
      'target_id': targetId,
    });
  }

  @override
  Future<List<MuteVote>> getMuteVotes({
    required String roomId,
    required String targetId,
  }) async {
    final response = await _client
        .from('mute_votes')
        .select()
        .eq('room_id', roomId)
        .eq('target_id', targetId);

    return response.map((row) => MuteVote.fromJson(row)).toList();
  }

  @override
  Future<bool> isUserMuted({
    required String roomId,
    required String userId,
  }) async {
    final response = await _client
        .from('moderation_log')
        .select('id')
        .eq('room_id', roomId)
        .eq('target_id', userId)
        .eq('action', 'mute')
        .limit(1);

    return response.isNotEmpty;
  }

  @override
  Stream<List<MuteVote>> watchMuteVotes({required String roomId}) {
    return _client
        .from('mute_votes')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((rows) => rows.map((r) => MuteVote.fromJson(r)).toList());
  }
}
