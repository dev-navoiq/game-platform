import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int level;
  final int score;
  final int games;
  final int wins;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.level,
    required this.score,
    required this.games,
    required this.wins,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: json['user_id'] as String,
      username: (json['username'] as String?) ?? 'Player',
      avatarUrl: json['avatar_url'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      score: (json['score'] as num?)?.toInt() ?? 0,
      games: (json['games'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Top-50 board. `period` is 'week' (XP earned last 7 days) or 'all'
/// (lifetime XP). Backed by the get_leaderboard RPC — see
/// 20260820000000_leaderboard_rpc.sql.
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, period) async {
  final supabase = ref.watch(supabaseProvider);
  final rows = await supabase
      .rpc('get_leaderboard', params: {'p_period': period});
  return (rows as List)
      .map((r) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
});
