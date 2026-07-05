import 'package:monetization/monetization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [CurrencyRepository].
///
/// Reads the authoritative balance from `profiles` and history from
/// `currency_transactions`. Server-authoritative earns (game-end rewards,
/// tournament prizes, subscription grants, referrals) are written by edge
/// functions; the direct add/deduct path here backs the few client-initiated
/// spends (challenge reroll, season pass) and always re-reads the balance after.
class SupabaseCurrencyRepository implements CurrencyRepository {
  final SupabaseClient _client;

  SupabaseCurrencyRepository(this._client);

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
  Future<List<CurrencyTransaction>> getTransactions(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('currency_transactions')
        .select('id, user_id, currency, amount, reason, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map(
          (r) => CurrencyTransaction(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            type: (r['currency'] as String) == 'gems'
                ? CurrencyType.gems
                : CurrencyType.coins,
            amount: (r['amount'] as int?) ?? 0,
            reason: (r['reason'] as String?) ?? '',
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<CurrencyBalance> addCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) {
    return _mutate(userId, type, amount, reason);
  }

  @override
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) {
    return _mutate(userId, type, -amount, reason);
  }

  Future<CurrencyBalance> _mutate(
    String userId,
    CurrencyType type,
    int delta,
    String reason,
  ) async {
    final column = type == CurrencyType.gems ? 'gems' : 'coins';
    final current = await getBalance(userId);
    final currentVal = type == CurrencyType.gems ? current.gems : current.coins;
    final newVal = currentVal + delta;
    if (newVal < 0) {
      throw StateError('Insufficient $column: have $currentVal, need ${-delta}');
    }

    await _client.from('profiles').update({column: newVal}).eq('id', userId);
    await _client.from('currency_transactions').insert({
      'user_id': userId,
      'currency': column,
      'amount': delta,
      'balance_after': newVal,
      'reason': reason,
    });

    return current.copyWith(
      coins: type == CurrencyType.coins ? newVal : current.coins,
      gems: type == CurrencyType.gems ? newVal : current.gems,
    );
  }
}
