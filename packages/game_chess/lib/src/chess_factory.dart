import 'package:game_core/game_core.dart';

void registerChess(GameRegistry registry) {
  registry.register(const GameDescriptor(
    id: 'chess',
    name: 'Chess',
    minPlayers: 2,
    maxPlayers: 2,
    category: GameCategory.boardGame,
  ));
}
