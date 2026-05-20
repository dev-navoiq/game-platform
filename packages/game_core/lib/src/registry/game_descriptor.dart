import 'package:equatable/equatable.dart';

import 'game_category.dart';

/// Lightweight metadata describing a game available on the platform.
/// Used by [GameRegistry] for discovery and lobby filtering.
class GameDescriptor extends Equatable {
  final String id;
  final String name;
  final int minPlayers;
  final int maxPlayers;
  final GameCategory category;

  const GameDescriptor({
    required this.id,
    required this.name,
    required this.minPlayers,
    required this.maxPlayers,
    required this.category,
  });

  @override
  List<Object?> get props => [id, name, minPlayers, maxPlayers, category];

  @override
  String toString() => 'GameDescriptor($id, $name)';
}
