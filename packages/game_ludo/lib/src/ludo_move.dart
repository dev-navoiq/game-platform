import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

sealed class LudoMove extends GameMove with EquatableMixin {
  @override
  final String playerId;
  @override
  final DateTime? timestamp;

  const LudoMove({required this.playerId, this.timestamp});
}

/// Player rolls the dice.
class LudoRollDice extends LudoMove {
  const LudoRollDice({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.rollDice;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'rollDice', 'playerId': playerId};

  @override
  List<Object?> get props => [playerId];
}

/// Player moves a specific token [steps] squares.
class LudoMoveToken extends LudoMove {
  final String tokenId;
  final int steps;

  const LudoMoveToken({
    required super.playerId,
    required this.tokenId,
    required this.steps,
    super.timestamp,
  });

  @override
  MoveType get type => MoveType.movePiece;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'moveToken',
        'playerId': playerId,
        'tokenId': tokenId,
        'steps': steps,
      };

  @override
  List<Object?> get props => [playerId, tokenId, steps];
}

/// Player has no valid token moves and passes their turn.
class LudoPass extends LudoMove {
  const LudoPass({required super.playerId, super.timestamp});

  @override
  MoveType get type => MoveType.pass;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'pass', 'playerId': playerId};

  @override
  List<Object?> get props => [playerId];
}

LudoMove parseLudoMove(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final playerId = json['playerId'] as String;
  switch (type) {
    case 'rollDice':
      return LudoRollDice(playerId: playerId);
    case 'moveToken':
      return LudoMoveToken(
        playerId: playerId,
        tokenId: json['tokenId'] as String,
        steps: json['steps'] as int,
      );
    case 'pass':
      return LudoPass(playerId: playerId);
    default:
      throw ArgumentError('Unknown ludo move type: $type');
  }
}
