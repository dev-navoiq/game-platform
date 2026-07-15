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
    // Credits are server-authoritative: game-end rewards, tournament prizes,
    // subscription grants, referrals and daily bonuses are written by edge
    // functions. profiles.coins/gems are locked to service-role writes, so a
    // client can no longer credit its own balance. Callers should trigger the
    // relevant server flow and re-read via getBalance().
    throw UnsupportedError(
      'Currency credits are server-authoritative; use the relevant edge '
      'function (rewards/tournament/subscription) — clients cannot self-credit.',
    );
  }

  @override
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) async {
    // Spends route through the server-authoritative spend-currency function,
    // which enforces sufficient balance and writes the ledger atomically.
    final res = await _client.functions.invoke('spend-currency', body: {
      'currency': type == CurrencyType.gems ? 'gems' : 'coins',
      'amount': amount,
      'reason': reason,
    });
    if (res.status >= 400) {
      final data = (res.data as Map<String, dynamic>?) ?? const {};
      throw StateError(
        (data['error'] as String?) ?? 'Spend failed (${res.status})',
      );
    }
    return getBalance(userId);
  }
}
