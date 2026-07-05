import 'package:monetization/monetization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [SeasonRepository].
///
/// Reads seasons / progress / rewards from the DB. Level rewards are claimed
/// server-side via the `grant-season-reward` edge function. Season XP itself is
/// granted server-side (game-end, challenges), so [saveProgress] is a light
/// upsert used for local optimistic updates only.
class SupabaseSeasonRepository implements SeasonRepository {
  final SupabaseClient _client;

  SupabaseSeasonRepository(this._client);

  static const int _xpPerLevel = 1000; // matches the server flat curve

  @override
  Future<Season?> getCurrentSeason() async {
    final row = await _client
        .from('seasons')
        .select('id, name, start_date, end_date, max_level')
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Season(
      id: row['id'] as String,
      name: row['name'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      totalLevels: (row['max_level'] as int?) ?? 30,
    );
  }

  @override
  Future<UserSeasonProgress> getProgress(String userId, String seasonId) async {
    final row = await _client
        .from('user_season_progress')
        .select('xp, level, premium_purchased_at')
        .eq('user_id', userId)
        .eq('season_id', seasonId)
        .maybeSingle();
    if (row == null) {
      return UserSeasonProgress(
        userId: userId,
        seasonId: seasonId,
        currentLevel: 0,
        currentXp: 0,
        xpToNextLevel: _xpPerLevel,
      );
    }
    return UserSeasonProgress(
      userId: userId,
      seasonId: seasonId,
      currentLevel: (row['level'] as int?) ?? 0,
      currentXp: (row['xp'] as int?) ?? 0,
      xpToNextLevel: _xpPerLevel,
      hasPremiumPass: row['premium_purchased_at'] != null,
    );
  }

  @override
  Future<UserSeasonProgress> saveProgress(UserSeasonProgress progress) async {
    await _client.from('user_season_progress').upsert({
      'user_id': progress.userId,
      'season_id': progress.seasonId,
      'xp': progress.currentXp,
      'level': progress.currentLevel,
    }, onConflict: 'user_id,season_id');
    return progress;
  }

  @override
  Future<List<SeasonReward>> getRewards(String seasonId) async {
    final row = await _client
        .from('seasons')
        .select('metadata')
        .eq('id', seasonId)
        .maybeSingle();
    final metadata = (row?['metadata'] as Map<String, dynamic>?) ?? const {};
    final rewards = (metadata['rewards'] as List?) ?? const [];

    final result = <SeasonReward>[];
    for (final r in rewards) {
      final map = r as Map<String, dynamic>;
      final level = (map['level'] as int?) ?? 0;
      final free = (map['free'] as Map<String, dynamic>?) ?? const {};
      final premium = (map['premium'] as Map<String, dynamic>?) ?? const {};
      result.add(_reward(level, free, isPremiumOnly: false));
      if (premium.isNotEmpty) {
        result.add(_reward(level, premium, isPremiumOnly: true));
      }
    }
    return result;
  }

  SeasonReward _reward(
    int level,
    Map<String, dynamic> track, {
    required bool isPremiumOnly,
  }) {
    final coins = (track['coins'] as int?) ?? 0;
    final gems = (track['gems'] as int?) ?? 0;
    final skinId = track['skin_id'] as String?;
    final parts = <String>[
      if (coins > 0) '$coins coins',
      if (gems > 0) '$gems gems',
      if (skinId != null) 'skin',
    ];
    return SeasonReward(
      level: level,
      description: parts.isEmpty ? 'Reward' : parts.join(' + '),
      coinReward: coins,
      gemReward: gems,
      skinId: skinId,
      isPremiumOnly: isPremiumOnly,
    );
  }

  @override
  Future<SeasonReward> claimReward(
    String userId,
    String seasonId,
    int level,
  ) async {
    final res = await _client.functions.invoke(
      'grant-season-reward',
      body: {'season_id': seasonId, 'level': level},
    );
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    return SeasonReward(
      level: level,
      description: 'Level $level reward',
      coinReward: (data['coins_awarded'] as int?) ?? 0,
      gemReward: (data['gems_awarded'] as int?) ?? 0,
      skinId: data['skin_id'] as String?,
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
  Future<CurrencyBalance> deductGems(String userId, int amount) async {
    final current = await getBalance(userId);
    if (current.gems < amount) {
      throw StateError('Insufficient gems: have ${current.gems}, need $amount');
    }
    final newGems = current.gems - amount;
    await _client.from('profiles').update({'gems': newGems}).eq('id', userId);
    await _client.from('currency_transactions').insert({
      'user_id': userId,
      'currency': 'gems',
      'amount': -amount,
      'balance_after': newGems,
      'reason': 'season_pass_purchase',
    });
    return current.copyWith(gems: newGems);
  }
}
