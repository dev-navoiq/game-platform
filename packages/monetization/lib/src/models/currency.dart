import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// The two virtual currencies in the game economy.
enum CurrencyType { coins, gems }

/// Represents a user's current balance of coins and gems.
@immutable
class CurrencyBalance extends Equatable {
  final int coins;
  final int gems;

  const CurrencyBalance({required this.coins, required this.gems});

  const CurrencyBalance.zero() : coins = 0, gems = 0;

  CurrencyBalance copyWith({int? coins, int? gems}) =>
      CurrencyBalance(coins: coins ?? this.coins, gems: gems ?? this.gems);

  @override
  List<Object?> get props => [coins, gems];
}

/// A record of a currency earn or spend event.
@immutable
class CurrencyTransaction extends Equatable {
  final String id;
  final String userId;
  final CurrencyType type;
  final int amount;
  final String reason;
  final DateTime createdAt;

  const CurrencyTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, type, amount, reason, createdAt];
}
