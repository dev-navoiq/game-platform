import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

import 'sequence_board.dart';

class SequenceMove extends GameMove with EquatableMixin {
  @override
  final String playerId;
  @override
  final DateTime? timestamp;

  final PlayingCard card; // Card played from hand
  final int row;
  final int col;
  final bool isRemoval; // True for one-eyed jack (removes opponent chip)

  const SequenceMove({
    required this.playerId,
    required this.card,
    required this.row,
    required this.col,
    this.isRemoval = false,
    this.timestamp,
  });

  @override
  MoveType get type => MoveType.placePiece;

  @override
  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'card': card.toJson(),
        'row': row,
        'col': col,
        'isRemoval': isRemoval,
      };

  factory SequenceMove.fromJson(Map<String, dynamic> json) => SequenceMove(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
        row: json['row'] as int,
        col: json['col'] as int,
        isRemoval: json['isRemoval'] ?? false,
      );

  @override
  List<Object?> get props => [playerId, card, row, col, isRemoval];
}
