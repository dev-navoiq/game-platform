import 'package:game_core/game_core.dart';

void registerLudo(GameRegistry registry) {
  registry.register(const GameDescriptor(
    id: 'ludo',
    name: 'Ludo',
    minPlayers: 2,
    maxPlayers: 4,
    category: GameCategory.boardGame,
  ));
}
