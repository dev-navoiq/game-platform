import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

/// Base class for all Hearts moves.
sealed class HeartsMove extends GameMove with EquatableMixin {
  @override
  final String playerId;

  @override
  final DateTime? timestamp;

  const HeartsMove({required this.playerId, this.timestamp});
}

/// Select 3 cards to pass to another player.
class HeartsSelectPassMove extends HeartsMove {
  /// Exactly 3 cards to pass.
  final List<PlayingCard> cards;

  const HeartsSelectPassMove({
    required super.playerId,
    required this.cards,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.discard; // Reusing discard as "pass selection"

  @override
  List<Object?> get props => [playerId, cards, timestamp];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'selectPass',
        'playerId': playerId,
        'cards': cards.map((c) => c.toJson()).toList(),
        'timestamp': timestamp?.toIso8601String(),
      };
}

/// Play a card from hand into the current trick.
class HeartsPlayCardMove extends HeartsMove {
  final PlayingCard card;

  const HeartsPlayCardMove({
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
