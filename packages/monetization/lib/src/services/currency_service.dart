import '../models/currency.dart';

/// Abstract interface for currency persistence.
abstract class CurrencyRepository {
  Future<CurrencyBalance> getBalance(String userId);
  Future<CurrencyBalance> addCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  );
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  );
  Future<List<CurrencyTransaction>> getTransactions(
    String userId, {
    int limit = 50,
  });
}

/// Service layer for the coin/gem economy.
class CurrencyService {
  final CurrencyRepository _repository;

  CurrencyService(this._repository);

  /// Earn currency of the given [type]. Returns updated balance.
  ///
  /// Throws [ArgumentError] if [amount] is not positive.
  Future<CurrencyBalance> earn(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) {
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive, got $amount');
    }
    return _repository.addCurrency(userId, type, amount, reason);
  }

  /// Spend currency of the given [type]. Returns updated balance.
  ///
  /// Throws [ArgumentError] if [amount] is not positive.
  /// Throws [InsufficientFundsException] if the user lacks sufficient balance.
  Future<CurrencyBalance> spend(
    String userId,
    CurrencyType type,
    int amount,
    String reason,
  ) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive, got $amount');
    }
    final balance = await _repository.getBalance(userId);
    final available =
        type == CurrencyType.coins ? balance.coins : balance.gems;
    if (available < amount) {
      throw InsufficientFundsException(
        currency: type,
        required: amount,
        available: available,
      );
    }
    return _repository.deductCurrency(userId, type, amount, reason);
  }

  /// Retrieve the user's current balance.
  Future<CurrencyBalance> getBalance(String userId) =>
      _repository.getBalance(userId);

  /// Retrieve recent transactions, newest first.
  Future<List<CurrencyTransaction>> getTransactions(
    String userId, {
    int limit = 50,
  }) =>
      _repository.getTransactions(userId, limit: limit);
}

/// Thrown when a spend operation exceeds the user's available balance.
class InsufficientFundsException implements Exception {
  final CurrencyType currency;
  final int required;
  final int available;

  const InsufficientFundsException({
    required this.currency,
    required this.required,
    required this.available,
  });

  @override
  String toString() =>
      'InsufficientFundsException: Need $required ${currency.name}, have $available';
}
