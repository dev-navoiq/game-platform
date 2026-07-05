import 'package:monetization/monetization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [ChallengeRepository].
///
/// Reads active challenges + the user's progress; rewards are claimed
/// server-side via the `claim-challenge-reward` edge function (which credits
/// coins/gems + XP and advances the season). Progress is normally advanced
/// server-side by gameplay events; [updateProgress] is a light client path.
class SupabaseChallengeRepository implements ChallengeRepository {
  final SupabaseClient _client;

  SupabaseChallengeRepository(this._client);

  @override
  Future<List<UserChallenge>> getActiveChallenges(String userId) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final challenges = await _client
        .from('challenges')
        .select(
          'id, title, description, challenge_type, target_value, reward_coins, reward_gems, created_at',
        )
        .eq('is_active', true)
        .gt('expires_at', nowIso);

    final userRows = await _client
        .from('user_challenges')
        .select('challenge_id, progress, completed_at, reward_claimed')
        .eq('user_id', userId);
    final byId = {
      for (final u in (userRows as List)) u['challenge_id'] as String: u,
    };

    return (challenges as List).map((c) {
      final id = c['id'] as String;
      final u = byId[id];
      return UserChallenge(
        challengeId: id,
        userId: userId,
        current: (u?['progress'] as int?) ?? 0,
        isCompleted: u?['completed_at'] != null,
        canReroll: !((u?['reward_claimed'] as bool?) ?? false),
        challenge: Challenge(
          id: id,
          title: c['title'] as String,
          description: c['description'] as String,
          type: (c['challenge_type'] as String) == 'weekly'
              ? ChallengeType.weekly
              : ChallengeType.daily,
          target: (c['target_value'] as int?) ?? 1,
          rewardCoins: (c['reward_coins'] as int?) ?? 0,
          rewardGems: (c['reward_gems'] as int?) ?? 0,
          createdAt: DateTime.parse(c['created_at'] as String),
        ),
      );
    }).toList();
  }

  @override
  Future<UserChallenge> updateProgress(
    String userId,
    String challengeId,
    int incrementBy,
  ) async {
    final existing = await _client
        .from('user_challenges')
        .select('progress, completed_at')
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    final challenge = await _client
        .from('challenges')
        .select('target_value')
        .eq('id', challengeId)
        .single();

    final target = (challenge['target_value'] as int?) ?? 1;
    final newProgress = ((existing?['progress'] as int?) ?? 0) + incrementBy;
    final completed = newProgress >= target;
    final alreadyCompleted = existing?['completed_at'] != null;

    await _client.from('user_challenges').upsert({
      'user_id': userId,
      'challenge_id': challengeId,
      'progress': newProgress,
      if (completed && !alreadyCompleted)
        'completed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,challenge_id');

    return UserChallenge(
      challengeId: challengeId,
      userId: userId,
      current: newProgress,
      isCompleted: completed,
    );
  }

  @override
  Future<CurrencyBalance> claimReward(String userId, String challengeId) async {
    await _client.functions.invoke(
      'claim-challenge-reward',
      body: {'challenge_id': challengeId},
    );
    // Re-read the authoritative balance (the function's response only carries
    // the currencies it actually awarded).
    return getBalance(userId);
  }

  @override
  Future<UserChallenge> rerollChallenge(
    String userId,
    String challengeId,
  ) async {
    // Reroll (swap for a fresh challenge) needs a server function to pick a new
    // template; pending that, this resets progress on the current challenge.
    // TODO: replace with a `reroll-challenge` edge function.
    await _client
        .from('user_challenges')
        .update({'progress': 0, 'completed_at': null})
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);
    return UserChallenge(
      challengeId: challengeId,
      userId: userId,
      current: 0,
    );
  }

  @override
  Future<CurrencyBalance> getBalance(String userId) async {
    final row = await _client
        .from('profiles')
        .select('coins, gems')
        .eq('id', userId)
        .single();
    return CurrencyBalance(
      coins: (row['coins'] as int?) ?? 0,
      gems: (row['gems'] as int?) ?? 0,
    );
  }

  @override
  Future<CurrencyBalance> deductCoins(String userId, int amount) async {
    final current = await getBalance(userId);
    if (current.coins < amount) {
      throw StateError(
          'Insufficient coins: have ${current.coins}, need $amount');
    }
    final newCoins = current.coins - amount;
    await _client.from('profiles').update({'coins': newCoins}).eq('id', userId);
    await _client.from('currency_transactions').insert({
      'user_id': userId,
      'currency': 'coins',
      'amount': -amount,
      'balance_after': newCoins,
      'reason': 'challenge_reroll',
    });
    return current.copyWith(coins: newCoins);
  }
}
