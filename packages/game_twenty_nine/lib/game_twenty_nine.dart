/// Twenty-Nine card game implementation.
library game_twenty_nine;

// Re-export collection so tests can use firstWhereOrNull without an extra import.
export 'package:collection/collection.dart';

export 'src/twenty_nine_config.dart';
export 'src/twenty_nine_state.dart';
export 'src/twenty_nine_move.dart';
export 'src/twenty_nine_scoring.dart';
export 'src/twenty_nine_rules.dart';
export 'src/twenty_nine_factory.dart';
