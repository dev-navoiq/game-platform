import 'package:equatable/equatable.dart';

import 'ludo_board.dart';

class LudoToken extends Equatable {
  final String id; // e.g. "p1_0"
  final LudoColor color;
  final LudoPosition position;

  const LudoToken({
    required this.id,
    required this.color,
    required this.position,
  });

  bool get isAtHome => position.zone == LudoZone.home;
  bool get isInPlay =>
      position.zone == LudoZone.main ||
      position.zone == LudoZone.homeStretch;
  bool get isFinished => position.zone == LudoZone.finish;

  LudoToken moveTo(LudoPosition newPosition) =>
      LudoToken(id: id, color: color, position: newPosition);

  LudoToken sendHome() {
    final slot = int.parse(id.split('_').last);
    return LudoToken(
        id: id, color: color, position: LudoPosition.home(color, slot));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.name,
        'position': {
          'zone': position.zone.name,
          'index': position.index,
          'color': position.color.name,
        },
      };

  factory LudoToken.fromJson(Map<String, dynamic> json) {
    final color = LudoColor.values.byName(json['color'] as String);
    final position =
        LudoPosition.fromJson(json['position'] as Map<String, dynamic>);
    return LudoToken(
      id: json['id'] as String,
      color: color,
      position: position,
    );
  }

  @override
  List<Object?> get props =>
      [id, color, position.zone, position.index, position.color];
}
