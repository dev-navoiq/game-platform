import 'game_category.dart';
import 'game_descriptor.dart';

/// Instance-based registry of all games available on the platform.
///
/// Each game package registers a [GameDescriptor] at app startup.
/// Throws [ArgumentError] if the same game id is registered twice.
class GameRegistry {
  final Map<String, GameDescriptor> _games = {};

  /// Register [descriptor]. Throws [ArgumentError] on duplicate id.
  void register(GameDescriptor descriptor) {
    if (_games.containsKey(descriptor.id)) {
      throw ArgumentError(
        'A game with id "${descriptor.id}" is already registered.',
      );
    }
    _games[descriptor.id] = descriptor;
  }

  /// Look up a game by [id]. Returns null if not registered.
  GameDescriptor? lookup(String id) => _games[id];

  /// IDs of all currently registered games.
  Iterable<String> get registeredGameIds => _games.keys;

  /// All registered games that belong to [category].
  List<GameDescriptor> gamesByCategory(GameCategory category) =>
      _games.values.where((d) => d.category == category).toList();
}
