import 'package:game_core/game_core.dart';

void registerSequence(GameRegistry registry) {
  registry.register(const GameDescriptor(
    id: 'sequence',
    name: 'Sequence',
    minPlayers: 2,
    maxPlayers: 4,
    category: GameCategory.boardGame,
  ));
}
