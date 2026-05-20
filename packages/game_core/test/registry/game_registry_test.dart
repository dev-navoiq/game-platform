import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  group('GameRegistry', () {
    late GameRegistry registry;

    setUp(() {
      registry = GameRegistry();
    });

    test('starts empty', () {
      expect(registry.registeredGameIds, isEmpty);
    });

    test('register adds a game', () {
      final descriptor = GameDescriptor(
        id: 'twenty_nine',
        name: 'Twenty-Nine',
        minPlayers: 4,
        maxPlayers: 4,
        category: GameCategory.cardGame,
      );
      registry.register(descriptor);
      expect(registry.registeredGameIds, contains('twenty_nine'));
    });

    test('lookup returns registered descriptor', () {
      final descriptor = GameDescriptor(
        id: 'chess',
        name: 'Chess',
        minPlayers: 2,
        maxPlayers: 2,
        category: GameCategory.boardGame,
      );
      registry.register(descriptor);
      expect(registry.lookup('chess'), equals(descriptor));
    });

    test('lookup returns null for unknown id', () {
      expect(registry.lookup('nonexistent'), isNull);
    });

    test('registering same id twice throws', () {
      final descriptor = GameDescriptor(
        id: 'ludo',
        name: 'Ludo',
        minPlayers: 2,
        maxPlayers: 4,
        category: GameCategory.boardGame,
      );
      registry.register(descriptor);
      expect(() => registry.register(descriptor), throwsArgumentError);
    });

    test('gamesByCategory returns only matching games', () {
      registry.register(GameDescriptor(
        id: 'twenty_nine',
        name: 'Twenty-Nine',
        minPlayers: 4,
        maxPlayers: 4,
        category: GameCategory.cardGame,
      ));
      registry.register(GameDescriptor(
        id: 'chess',
        name: 'Chess',
        minPlayers: 2,
        maxPlayers: 2,
        category: GameCategory.boardGame,
      ));

      final cardGames = registry.gamesByCategory(GameCategory.cardGame);
      expect(cardGames.length, 1);
      expect(cardGames.first.id, 'twenty_nine');
    });
  });
}
