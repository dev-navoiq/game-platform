import 'package:monetization/monetization.dart';

/// Supabase-backed implementation of [CurrencyRepository].
///
/// Currently a stub — real Supabase queries will be wired in a later session.
class SupabaseCurrencyRepository implements CurrencyRepository {
  @override
  Future<CurrencyBalance> getBalance(String userId) {
    throw UnimplementedError('SupabaseCurrencyRepository.getBalance');
  }

  @override
  Future<CurrencyBalance> addCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) {
    throw UnimplementedError('SupabaseCurrencyRepository.addCurrency');
  }

  @override
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) {
    throw UnimplementedError('SupabaseCurrencyRepository.deductCurrency');
  }

  @override
  Future<List<CurrencyTransaction>> getTransactions(
    String userId, {
    int limit = 50,
  }) {
    throw UnimplementedError('SupabaseCurrencyRepository.getTransactions');
  }
}
