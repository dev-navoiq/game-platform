import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

/// Base class for all Oh Hell moves.
sealed class OhHellMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const OhHellMove({required this.playerId, this.timestamp});
}

/// Place a bid (exact number of tricks predicted).
class OhHellBidMove extends OhHellMove {
  final int bid;

  const OhHellBidMove({
    required super.playerId,
    required this.bid,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, bid, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'playerId': playerId,
        'bid': bid,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Play a card from hand into the current trick.
class OhHellPlayCardMove extends OhHellMove {
  final PlayingCard card;

  const OhHellPlayCardMove({
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
