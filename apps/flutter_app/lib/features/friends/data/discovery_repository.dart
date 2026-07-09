import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A player surfaced by discovery (username/friend-code search or the
/// recent-players suggestions). Rows come from the `search_profiles` /
/// `get_recent_players` RPCs, which pre-filter to registered, non-blocked
/// profiles and annotate friendship state.
class DiscoveredPlayer {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final bool isFriend;
  final bool requestPending;
  final DateTime? lastPlayedAt;
  final int gamesTogether;

  const DiscoveredPlayer({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.isFriend = false,
    this.requestPending = false,
    this.lastPlayedAt,
    this.gamesTogether = 0,
  });

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  factory DiscoveredPlayer.fromJson(Map<String, dynamic> json) {
    return DiscoveredPlayer(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int? ?? 1,
      isFriend: json['is_friend'] as bool? ?? false,
      requestPending: json['request_pending'] as bool? ?? false,
      lastPlayedAt: json['last_played_at'] != null
          ? DateTime.parse(json['last_played_at'] as String)
          : null,
      gamesTogether: (json['games_together'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiscoveryRepository {
  final SupabaseClient _client;

  DiscoveryRepository(this._client);

  /// Prefix search on usernames + exact friend-code lookup. Server enforces
  /// registered-caller, min 3 chars, discoverable, and block exclusion.
  Future<List<DiscoveredPlayer>> search(String query) async {
    final rows = await _client
        .rpc('search_profiles', params: {'p_query': query.trim()});
    return (rows as List)
        .map((r) => DiscoveredPlayer.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Registered co-players from recent game history, most recent first.
  Future<List<DiscoveredPlayer>> recentPlayers({int limit = 20}) async {
    final rows =
        await _client.rpc('get_recent_players', params: {'p_limit': limit});
    return (rows as List)
        .map((r) => DiscoveredPlayer.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Claim or change the username. Server trigger enforces registered-only,
  /// format, reserved words, uniqueness and the 30-day rename cooldown —
  /// failures surface as [PostgrestException] with a user-readable message.
  Future<void> claimUsername(String username) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({'username': username.trim().toLowerCase()}).eq('id', userId);
  }

  Future<void> setDiscoverable(bool discoverable) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({'discoverable': discoverable}).eq('id', userId);
  }

  Future<void> reportUser({
    required String targetId,
    required String context,
    String? contextId,
    required String reason,
    String? detail,
  }) async {
    await _client.from('user_reports').insert({
      'reporter_id': _client.auth.currentUser!.id,
      'target_id': targetId,
      'context': context,
      'context_id': contextId,
      'reason': reason,
      'detail': (detail == null || detail.trim().isEmpty) ? null : detail.trim(),
    });
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(Supabase.instance.client);
});

/// Search results for the Add Friends screen. Family key is the query;
/// autoDispose so stale queries don't pile up.
final playerSearchProvider = FutureProvider.autoDispose
    .family<List<DiscoveredPlayer>, String>((ref, query) {
  if (query.trim().length < 3) return Future.value(const []);
  return ref.watch(discoveryRepositoryProvider).search(query);
});

final recentPlayersProvider =
    FutureProvider.autoDispose<List<DiscoveredPlayer>>((ref) {
  return ref.watch(discoveryRepositoryProvider).recentPlayers();
});
