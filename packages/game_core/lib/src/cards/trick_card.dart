import 'package:equatable/equatable.dart';

import 'playing_card.dart';

/// A card played in a trick, along with the player who played it.
class TrickCard extends Equatable {
  final String playerId;
  final PlayingCard card;
  final int seatIndex;

  const TrickCard({
    required this.playerId,
    required this.card,
    required this.seatIndex,
  });

  /// Convenience accessor for the card's suit (used in lead-suit detection).
  Suit get suit => card.suit;

  @override
  List<Object?> get props => [playerId, card, seatIndex];

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'card': card.toJson(),
        'seatIndex': seatIndex,
      };

  factory TrickCard.fromJson(Map<String, dynamic> json) => TrickCard(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
        seatIndex: json['seatIndex'] as int,
      );
}
