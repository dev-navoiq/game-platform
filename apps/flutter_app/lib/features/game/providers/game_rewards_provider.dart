import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../local/local_game_session.dart';

/// What the server actually granted this player for a finished game (#54).
/// Fetched from the player's own `recent_games` row (RLS: owner-only), which
/// `record_game_completion` writes at game end.
class GameRewardReceipt {
  final int coins;
  final int xp;
  final int gems;
  final bool firstWinBonus;
  final bool dailyCapHit;

  const GameRewardReceipt({
    required this.coins,
    required this.xp,
    required this.gems,
    required this.firstWinBonus,
    required this.dailyCapHit,
  });
}

/// One-liner for the game-over dialogs' rewardNote slot. Null when there's
/// nothing noteworthy (or no receipt yet).
String? rewardNoteFor(GameRewardReceipt? r) {
  if (r == null) return null;
  if (r.firstWinBonus) return 'Includes first win of the day 🌟';
  if (r.dailyCapHit) {
    return r.coins == 0
        ? 'Daily earn limit reached'
        : 'Trimmed — daily earn limit reached';
  }
  return null;
}

/// Only receipts younger than this belong to the game that just ended.
/// Play Again reuses the room, and the restart clears the reward guard, so
/// EVERY completed game writes a receipt for the same room_id. Without this
/// gate the first fetch returns the PREVIOUS game's receipt while the server
/// is still writing this one (~4-5s lag observed on staging: guard row at
/// game end, receipt row seconds later). 90s is far shorter than any real
/// game and generous to client/server clock skew.
const _receiptFreshness = Duration(seconds: 90);

/// Fetches the local player's reward receipt for [roomId].
///
/// Returns null for local practice rooms (no server, no rewards) and when no
/// fresh receipt appears (e.g. spectator). The grant lags the final state
/// broadcast by a few seconds, so a stale-or-missing row is retried before
/// giving up. Dialogs pass 0 while null, which hides the reward chips.
final gameRewardReceiptProvider = FutureProvider.autoDispose
    .family<GameRewardReceipt?, String>((ref, roomId) async {
  if (LocalGameSession.isLocalRoomId(roomId)) return null;

  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  for (var attempt = 0; attempt < 8; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    final row = await supabase
        .from('recent_games')
        .select(
            'coins_earned, xp_earned, gems_earned, first_win_bonus, daily_cap_hit, played_at')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .order('played_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) continue;
    final playedAt = DateTime.tryParse(row['played_at'] as String? ?? '');
    final isFresh = playedAt != null &&
        DateTime.now().toUtc().difference(playedAt.toUtc()) <
            _receiptFreshness;
    if (!isFresh) continue; // previous game's receipt — keep waiting
    return GameRewardReceipt(
      coins: (row['coins_earned'] as int?) ?? 0,
      xp: (row['xp_earned'] as int?) ?? 0,
      gems: (row['gems_earned'] as int?) ?? 0,
      firstWinBonus: (row['first_win_bonus'] as bool?) ?? false,
      dailyCapHit: (row['daily_cap_hit'] as bool?) ?? false,
    );
  }
  return null;
});
