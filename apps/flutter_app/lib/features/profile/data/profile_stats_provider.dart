import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

class ProfileStats {
  final int games;
  final int wins;
  final int coinsEarned;

  const ProfileStats({
    required this.games,
    required this.wins,
    required this.coinsEarned,
  });

  int get winRatePercent => games == 0 ? 0 : ((wins * 100) / games).round();
}

/// Lifetime stats for the signed-in player, aggregated from their own
/// recent_games rows (RLS scopes the select to the caller, so this stays a
/// plain client-side query — no RPC needed at profile-history sizes).
final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) {
    return const ProfileStats(games: 0, wins: 0, coinsEarned: 0);
  }
  final rows = await supabase
      .from('recent_games')
      .select('result, coins_earned')
      .eq('user_id', userId);
  var games = 0;
  var wins = 0;
  var coins = 0;
  for (final r in rows) {
    games++;
    if (r['result'] == 'win') wins++;
    coins += (r['coins_earned'] as num?)?.toInt() ?? 0;
  }
  return ProfileStats(games: games, wins: wins, coinsEarned: coins);
});
