import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

/// Base class for all Twenty-Nine moves.
sealed class TwentyNineMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const TwentyNineMove({required this.playerId, this.timestamp});
}

/// Place a bid.
class BidMove extends TwentyNineMove {
  final int bidValue;

  const BidMove({
    required super.playerId,
    required this.bidValue,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, bidValue, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'playerId': playerId,
        'bidValue': bidValue,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Pass during bidding.
class PassMove extends TwentyNineMove {
  const PassMove({required super.playerId, super.timestamp});

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

/// Declare the trump suit (bid winner's partner).
class DeclareTrumpMove extends TwentyNineMove {
  final Suit suit;

  const DeclareTrumpMove({
    required super.playerId,
    required this.suit,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.declareTrump;

  @override
  List<Object?> get props => [playerId, suit, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'declareTrump',
        'playerId': playerId,
        'suit': suit.name,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Play a card from hand into the current trick.
class PlayCardMove extends TwentyNineMove {
  final PlayingCard card;

  const PlayCardMove({
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

/// Double the current contract (declared by defending team).
class DoubleMove extends TwentyNineMove {
  const DoubleMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, 'double', timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'double',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Redouble after the contract has been doubled (declared by bidding team).
class RedoubleMove extends TwentyNineMove {
  const RedoubleMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.bid;

  @override
  List<Object?> get props => [playerId, 'redouble', timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'redouble',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Publicly reveal the hidden trump suit.
class RevealTrumpMove extends TwentyNineMove {
  const RevealTrumpMove({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.revealTrump;

  @override
  List<Object?> get props => [playerId, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'revealTrump',
        'playerId': playerId,
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Parse a move from its JSON representation.
TwentyNineMove parseTwentyNineMove(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final playerId = json['playerId'] as String;
  final timestamp = json['timestamp'] != null
      ? DateTime.parse(json['timestamp'] as String)
      : null;

  switch (type) {
    case 'bid':
      return BidMove(
        playerId: playerId,
        bidValue: json['bidValue'] as int,
        timestamp: timestamp,
      );
    case 'pass':
      return PassMove(playerId: playerId, timestamp: timestamp);
    case 'double':
      return DoubleMove(playerId: playerId, timestamp: timestamp);
    case 'redouble':
      return RedoubleMove(playerId: playerId, timestamp: timestamp);
    case 'declareTrump':
      return DeclareTrumpMove(
        playerId: playerId,
        suit: Suit.values.byName(json['suit'] as String),
        timestamp: timestamp,
      );
    case 'playCard':
      return PlayCardMove(
        playerId: playerId,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
        timestamp: timestamp,
      );
    case 'revealTrump':
      return RevealTrumpMove(playerId: playerId, timestamp: timestamp);
    default:
      throw ArgumentError('Unknown TwentyNineMove type: $type');
  }
}
