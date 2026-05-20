import 'package:equatable/equatable.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

class PlayingCard extends Equatable {
  final Suit suit;
  final Rank rank;

  const PlayingCard(this.suit, this.rank);

  @override
  List<Object?> get props => [suit, rank];

  @override
  String toString() {
    final rankName = rank.name[0].toUpperCase() + rank.name.substring(1);
    final suitName = suit.name[0].toUpperCase() + suit.name.substring(1);
    return '$rankName of $suitName';
  }

  Map<String, dynamic> toJson() => {
        'suit': suit.name,
        'rank': rank.name,
      };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
        Suit.values.byName(json['suit'] as String),
        Rank.values.byName(json['rank'] as String),
      );
}
