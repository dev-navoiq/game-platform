import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

/// Base class for all Spades moves.
sealed class SpadesMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const SpadesMove({required this.playerId, this.timestamp});
}

/// Place a bid (number of tricks expected to win; 0 = nil bid).
class SpadesBidMove extends SpadesMove {
  final int bid;

  /// Whether this is a nil bid (bid == 0 with special scoring).
  final bool isNil;

  const SpadesBidMove({
    required super.playerId,
    required this.bid,
    this.isNil = false,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, bid, isNil, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'playerId': playerId,
        'bid': bid,
        'isNil': isNil,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Play a card from hand.
class SpadesPlayCardMove extends SpadesMove {
  final PlayingCard card;

  const SpadesPlayCardMove({
    required super.playerId,
    required this.card,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.playCard;

  @override
  List<Object?> get props => [playerId, card, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'playCard',
        'playerId': playerId,
        'card': card.toJson(),
        'timestamp': timestamp?.toIso8601String(),
      };
}
