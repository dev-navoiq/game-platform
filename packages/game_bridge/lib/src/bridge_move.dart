import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

import 'bridge_config.dart';

/// Base class for all Bridge moves (auction calls + card play).
sealed class BridgeMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const BridgeMove({required this.playerId, this.timestamp});
}

/// A bid during the auction (level + denomination).
class BridgeBidMove extends BridgeMove {
  /// 1..7
  final int level;
  final BridgeDenomination denomination;

  const BridgeBidMove({
    required super.playerId,
    required this.level,
    required this.denomination,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, level, denomination, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'playerId': playerId,
        'level': level,
        'denomination': denomination.name,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Pass during the auction.
class BridgePassMove extends BridgeMove {
  const BridgePassMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.pass;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pass',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Double the opponents' current bid.
class BridgeDoubleMove extends BridgeMove {
  const BridgeDoubleMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'double',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Redouble after the opponents have doubled our side's bid.
class BridgeRedoubleMove extends BridgeMove {
  const BridgeRedoubleMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'redouble',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Play a card from hand. When dummy is to play, the declarer submits the move
/// on dummy's behalf (validator allows declarer.playerId for dummy's turn).
class BridgePlayCardMove extends BridgeMove {
  final PlayingCard card;

  const BridgePlayCardMove({
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

/// Advance to the next deal after the round-end overlay is dismissed.
class BridgeNewDealMove extends BridgeMove {
  const BridgeNewDealMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'newDeal',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}
