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
      .select('result')
      .eq('user_id', userId);
  var games = 0;
  var wins = 0;
  for (final r in rows) {
    games++;
    if (r['result'] == 'win') wins++;
  }
  // "Coins earned" comes from the ledger, not per-game receipts: the ledger
  // includes tournament prizes and pre-receipt-era games, and excludes
  // top-ups that never went through the economy.
  final credits = await supabase
      .from('currency_transactions')
      .select('amount')
      .eq('user_id', userId)
      .eq('currency', 'coins')
      .gt('amount', 0);
  var coins = 0;
  for (final c in credits) {
    coins += (c['amount'] as num).toInt();
  }
  return ProfileStats(games: games, wins: wins, coinsEarned: coins);
});
