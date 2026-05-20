import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Syncs server-side game configuration from the `game_configs` table.
///
/// Config values are tunable at runtime without an app update — for example
/// turn timeouts, bid limits, and dice counts.
class ConfigSyncService {
  static final ConfigSyncService _instance = ConfigSyncService._internal();
  static ConfigSyncService get instance => _instance;

  ConfigSyncService._internal();

  SupabaseClient? _supabase;
  final Map<String, Map<String, dynamic>> _gameConfigs = {};
  final _configController = StreamController<String>.broadcast();

  /// Emits the game type whose config just changed.
  Stream<String> get configUpdates => _configController.stream;

  Future<void> initialize(SupabaseClient supabase) async {
    _supabase = supabase;
    await _loadAllConfigs();
    _subscribeToUpdates();
  }

  // ── Queries ─────────────────────────────────────────────────────────────

  /// Get a single config value for [gameType].
  T? getConfig<T>(String gameType, String key, [T? defaultValue]) {
    final value = _gameConfigs[gameType]?[key];
    if (value == null) return defaultValue;

    // JSONB values come as various Dart types — try to cast.
    if (value is T) return value;

    // Handle common JSONB→Dart conversions
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;
    if (T == bool && value is String) {
      return (value.toLowerCase() == 'true') as T;
    }

    return defaultValue;
  }

  /// Get all config key-values for [gameType].
  Map<String, dynamic> getConfigsForGame(String gameType) {
    return Map.unmodifiable(_gameConfigs[gameType] ?? {});
  }

  /// Check if a config key exists for [gameType].
  bool hasConfig(String gameType, String key) {
    return _gameConfigs[gameType]?.containsKey(key) ?? false;
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<void> _loadAllConfigs() async {
    if (_supabase == null) return;

    try {
      final response = await _supabase!.from('game_configs').select();

      for (final row in response) {
        final gameType = row['game_type'] as String;
        final key = row['config_key'] as String;
        final value = row['config_value'];

        _gameConfigs.putIfAbsent(gameType, () => {});
        _gameConfigs[gameType]![key] = value;
      }
    } catch (_) {
      // Non-critical — features will use hard-coded defaults
    }
  }

  void _subscribeToUpdates() {
    if (_supabase == null) return;

    _supabase!
        .channel('game_configs_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_configs',
          callback: (payload) {
            final gameType = payload.newRecord['game_type'] as String?;
            if (gameType != null) {
              _loadConfigsForGame(gameType);
              _configController.add(gameType);
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadConfigsForGame(String gameType) async {
    if (_supabase == null) return;

    try {
      final response = await _supabase!
          .from('game_configs')
          .select()
          .eq('game_type', gameType);

      _gameConfigs[gameType] = {};
      for (final row in response) {
        _gameConfigs[gameType]![row['config_key'] as String] =
            row['config_value'];
      }
    } catch (_) {
      // Keep stale values on error
    }
  }

  Future<void> dispose() async {
    await _configController.close();
  }

  /// Reset for testing purposes.
  void reset() {
    _gameConfigs.clear();
    _supabase = null;
  }
}
