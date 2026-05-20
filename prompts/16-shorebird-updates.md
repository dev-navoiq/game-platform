# 15 - Shorebird OTA Updates & Feature Flags

> Configure Shorebird for hot-patching game rules and implement feature flags for gradual rollouts.

## Task

Set up Shorebird for:
- OTA code patches without app store updates
- Hot-fix deployment for game rule bugs
- Feature flags for gradual rollouts
- A/B testing for rule variants
- Server-side configuration sync

---

## Shorebird Configuration

### Setup

```yaml
# apps/flutter_app/shorebird.yaml

app_id: your_app_id_here

# Environment-specific app IDs
flavors:
  development:
    app_id: dev_app_id
  staging:
    app_id: staging_app_id
  production:
    app_id: prod_app_id

# Auto-update configuration (handled in code)
```

### Update Service

```dart
// lib/core/services/update_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

enum UpdateStatus {
  unknown,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  error,
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  static UpdateService get instance => _instance;

  UpdateService._internal();

  final _statusController = StreamController<UpdateStatus>.broadcast();
  UpdateStatus _currentStatus = UpdateStatus.unknown;

  Stream<UpdateStatus> get statusStream => _statusController.stream;
  UpdateStatus get currentStatus => _currentStatus;

  String? _currentPatchNumber;
  String? _availablePatchNumber;
  String? _errorMessage;

  String? get currentPatchNumber => _currentPatchNumber;
  String? get availablePatchNumber => _availablePatchNumber;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    // Only check for updates in release builds
    if (kDebugMode) {
      _setStatus(UpdateStatus.upToDate);
      return;
    }

    // In actual implementation, this would use Shorebird's API
    // For now, simulate the check
    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    _setStatus(UpdateStatus.checking);

    try {
      // Shorebird integration point
      // final updater = ShorebirdUpdater();
      // final status = await updater.checkForUpdate();

      // Simulated response
      final hasUpdate = false; // Replace with actual check

      if (hasUpdate) {
        _setStatus(UpdateStatus.updateAvailable);
      } else {
        _setStatus(UpdateStatus.upToDate);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(UpdateStatus.error);
    }
  }

  Future<void> checkForUpdate() async {
    if (_currentStatus == UpdateStatus.checking ||
        _currentStatus == UpdateStatus.downloading) {
      return;
    }
    await _checkForUpdate();
  }

  Future<bool> downloadAndInstall() async {
    if (_currentStatus != UpdateStatus.updateAvailable) {
      return false;
    }

    _setStatus(UpdateStatus.downloading);

    try {
      // Shorebird download
      // await ShorebirdUpdater().downloadUpdate();

      // Simulated delay
      await Future.delayed(const Duration(seconds: 2));

      _setStatus(UpdateStatus.readyToInstall);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(UpdateStatus.error);
      return false;
    }
  }

  void _setStatus(UpdateStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  String get statusMessage {
    switch (_currentStatus) {
      case UpdateStatus.unknown:
        return 'Checking for updates...';
      case UpdateStatus.checking:
        return 'Checking for updates...';
      case UpdateStatus.upToDate:
        return 'App is up to date';
      case UpdateStatus.updateAvailable:
        return 'Update available';
      case UpdateStatus.downloading:
        return 'Downloading update...';
      case UpdateStatus.readyToInstall:
        return 'Restart to apply update';
      case UpdateStatus.error:
        return 'Update check failed';
    }
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}
```

---

## Feature Flags System

### Feature Flag Service

```dart
// lib/core/services/feature_flags.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  static FeatureFlags get instance => _instance;

  FeatureFlags._internal();

  final Map<String, FeatureFlag> _flags = {};
  final Map<String, dynamic> _overrides = {};
  late SharedPreferences _prefs;
  late SupabaseClient _supabase;
  String? _userId;

  // Standard feature flags
  static const String voiceChatEnabled = 'voice_chat_enabled';
  static const String newGameUI = 'new_game_ui';
  static const String animationsV2 = 'animations_v2';
  static const String quickMatchmaking = 'quick_matchmaking';
  static const String socialFeatures = 'social_features';
  static const String brandSkins = 'brand_skins';
  static const String debugMode = 'debug_mode';

  // A/B test flags
  static const String bidTimerDuration = 'bid_timer_duration';
  static const String trickAnimationStyle = 'trick_animation_style';
  static const String scoringFormula = 'scoring_formula';

  Future<void> initialize({
    required SupabaseClient supabase,
    String? userId,
  }) async {
    _supabase = supabase;
    _userId = userId;
    _prefs = await SharedPreferences.getInstance();

    // Load cached flags first for instant availability
    _loadCachedFlags();

    // Then fetch fresh flags from server
    await _fetchFlagsFromServer();

    // Subscribe to real-time updates
    _subscribeToFlagUpdates();
  }

  void _loadCachedFlags() {
    final cachedJson = _prefs.getString('feature_flags');
    if (cachedJson != null) {
      try {
        final cached = Map<String, dynamic>.from(
          json.decode(cachedJson) as Map,
        );
        for (final entry in cached.entries) {
          _flags[entry.key] = FeatureFlag.fromJson(entry.value);
        }
      } catch (e) {
        // Ignore cache errors
      }
    }

    // Apply default flags
    _applyDefaults();
  }

  void _applyDefaults() {
    final defaults = {
      voiceChatEnabled: FeatureFlag(
        key: voiceChatEnabled,
        enabled: true,
        rolloutPercentage: 100,
      ),
      newGameUI: FeatureFlag(
        key: newGameUI,
        enabled: false,
        rolloutPercentage: 0,
      ),
      animationsV2: FeatureFlag(
        key: animationsV2,
        enabled: true,
        rolloutPercentage: 100,
      ),
      quickMatchmaking: FeatureFlag(
        key: quickMatchmaking,
        enabled: true,
        rolloutPercentage: 100,
      ),
      socialFeatures: FeatureFlag(
        key: socialFeatures,
        enabled: true,
        rolloutPercentage: 100,
      ),
      brandSkins: FeatureFlag(
        key: brandSkins,
        enabled: true,
        rolloutPercentage: 100,
      ),
      bidTimerDuration: FeatureFlag(
        key: bidTimerDuration,
        enabled: true,
        rolloutPercentage: 100,
        variants: {'default': 30, 'short': 20, 'long': 45},
        selectedVariant: 'default',
      ),
    };

    for (final entry in defaults.entries) {
      _flags.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Future<void> _fetchFlagsFromServer() async {
    try {
      final response = await _supabase
          .from('feature_flags')
          .select()
          .eq('is_active', true);

      for (final row in response) {
        final flag = FeatureFlag(
          key: row['flag_key'] as String,
          enabled: row['enabled'] as bool,
          rolloutPercentage: row['rollout_percentage'] as int? ?? 100,
          variants: row['variants'] as Map<String, dynamic>?,
          selectedVariant: row['default_variant'] as String?,
          targetUserIds: (row['target_user_ids'] as List?)?.cast<String>(),
          excludeUserIds: (row['exclude_user_ids'] as List?)?.cast<String>(),
        );
        _flags[flag.key] = flag;
      }

      // Cache flags
      await _cacheFlags();
    } catch (e) {
      // Use cached/default flags on error
    }
  }

  Future<void> _cacheFlags() async {
    final json = _flags.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString('feature_flags', jsonEncode(json));
  }

  void _subscribeToFlagUpdates() {
    _supabase
        .channel('feature_flags')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feature_flags',
          callback: (payload) {
            _handleFlagUpdate(payload);
          },
        )
        .subscribe();
  }

  void _handleFlagUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      _flags.remove(payload.oldRecord['flag_key']);
    } else {
      final row = payload.newRecord;
      _flags[row['flag_key']] = FeatureFlag(
        key: row['flag_key'] as String,
        enabled: row['enabled'] as bool,
        rolloutPercentage: row['rollout_percentage'] as int? ?? 100,
        variants: row['variants'] as Map<String, dynamic>?,
        selectedVariant: row['default_variant'] as String?,
      );
    }
    _cacheFlags();
  }

  /// Check if a feature is enabled
  bool isEnabled(String flagKey) {
    // Check overrides first (for testing)
    if (_overrides.containsKey(flagKey)) {
      return _overrides[flagKey] as bool;
    }

    final flag = _flags[flagKey];
    if (flag == null) return false;

    // Check if user is specifically targeted
    if (flag.targetUserIds != null &&
        _userId != null &&
        flag.targetUserIds!.contains(_userId)) {
      return true;
    }

    // Check if user is excluded
    if (flag.excludeUserIds != null &&
        _userId != null &&
        flag.excludeUserIds!.contains(_userId)) {
      return false;
    }

    // Check rollout percentage
    if (!flag.enabled) return false;
    if (flag.rolloutPercentage >= 100) return true;
    if (flag.rolloutPercentage <= 0) return false;

    // Deterministic rollout based on user ID
    if (_userId != null) {
      final hash = _userId.hashCode.abs();
      return (hash % 100) < flag.rolloutPercentage;
    }

    return flag.enabled;
  }

  /// Get variant value for A/B test
  T getVariant<T>(String flagKey, T defaultValue) {
    if (_overrides.containsKey(flagKey)) {
      return _overrides[flagKey] as T;
    }

    final flag = _flags[flagKey];
    if (flag == null || flag.variants == null) return defaultValue;

    // Determine variant for user
    final variantKey = _getVariantForUser(flagKey, flag.variants!.keys.toList());
    return flag.variants![variantKey] as T? ?? defaultValue;
  }

  String _getVariantForUser(String flagKey, List<String> variants) {
    if (variants.isEmpty) return '';
    if (_userId == null) return variants.first;

    // Deterministic variant assignment
    final hash = ('$_userId:$flagKey').hashCode.abs();
    return variants[hash % variants.length];
  }

  /// Set override (for testing/debugging)
  void setOverride(String flagKey, dynamic value) {
    _overrides[flagKey] = value;
  }

  /// Clear overrides
  void clearOverrides() {
    _overrides.clear();
  }

  /// Get all enabled flags (for debugging)
  Map<String, bool> getAllFlags() {
    return _flags.map((k, v) => MapEntry(k, isEnabled(k)));
  }
}

class FeatureFlag {
  final String key;
  final bool enabled;
  final int rolloutPercentage;
  final Map<String, dynamic>? variants;
  final String? selectedVariant;
  final List<String>? targetUserIds;
  final List<String>? excludeUserIds;

  FeatureFlag({
    required this.key,
    required this.enabled,
    this.rolloutPercentage = 100,
    this.variants,
    this.selectedVariant,
    this.targetUserIds,
    this.excludeUserIds,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      key: json['key'] as String,
      enabled: json['enabled'] as bool,
      rolloutPercentage: json['rolloutPercentage'] as int? ?? 100,
      variants: json['variants'] as Map<String, dynamic>?,
      selectedVariant: json['selectedVariant'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'enabled': enabled,
    'rolloutPercentage': rolloutPercentage,
    'variants': variants,
    'selectedVariant': selectedVariant,
  };
}
```

---

## Feature Flags Database Table

```sql
-- Add to migrations
CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flag_key TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  description TEXT,

  -- Status
  enabled BOOLEAN DEFAULT FALSE,
  rollout_percentage INT DEFAULT 0 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),

  -- A/B Testing
  variants JSONB,
  default_variant TEXT,

  -- Targeting
  target_user_ids TEXT[],
  exclude_user_ids TEXT[],
  target_subscription_tiers TEXT[],
  target_platforms TEXT[],  -- 'ios', 'android', 'web'

  -- Scheduling
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,

  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id)
);

-- RLS
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Feature flags readable by all" ON feature_flags
  FOR SELECT USING (is_active = TRUE);

-- Seed default flags
INSERT INTO feature_flags (flag_key, display_name, description, enabled, rollout_percentage) VALUES
  ('voice_chat_enabled', 'Voice Chat', 'Enable voice chat feature', TRUE, 100),
  ('new_game_ui', 'New Game UI', 'New glass morphism UI', FALSE, 0),
  ('animations_v2', 'Animations V2', 'Enhanced animations', TRUE, 100),
  ('quick_matchmaking', 'Quick Matchmaking', 'Fast matchmaking queue', TRUE, 100),
  ('social_features', 'Social Features', 'Chat, friends, reactions', TRUE, 100),
  ('brand_skins', 'Brand Skins', 'Show sponsored skins', TRUE, 100);
  ('floating_chat_bubbles_enabled', 'Floating Chat Bubbles', 'Enable floating chat bubbles above avatars', TRUE, 100),
  ('season_pass_enabled', 'Season Pass', 'Enable season pass feature for gradual rollout', FALSE, 0),
  ('silent_rooms_enabled', 'Silent Rooms', 'Enable silent room mode for gradual rollout', FALSE, 0),
  ('referral_system_enabled', 'Referral System', 'Enable referral system for viral loop', TRUE, 100);

-- A/B test flag
INSERT INTO feature_flags (flag_key, display_name, description, enabled, rollout_percentage, variants, default_variant) VALUES
  ('bid_timer_duration', 'Bid Timer Duration', 'A/B test for bid timer', TRUE, 100,
   '{"short": 20, "default": 30, "long": 45}', 'default');
```

---

## Server-Side Config Sync

```dart
// lib/core/services/config_sync_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfigSyncService {
  static final ConfigSyncService _instance = ConfigSyncService._internal();
  static ConfigSyncService get instance => _instance;

  ConfigSyncService._internal();

  late SupabaseClient _supabase;
  final Map<String, Map<String, dynamic>> _gameConfigs = {};
  final _configController = StreamController<String>.broadcast();

  Stream<String> get configUpdates => _configController.stream;

  Future<void> initialize(SupabaseClient supabase) async {
    _supabase = supabase;
    await _loadAllConfigs();
    _subscribeToUpdates();
  }

  Future<void> _loadAllConfigs() async {
    final response = await _supabase
        .from('game_configs')
        .select()
        .eq('is_active', true);

    for (final row in response) {
      final gameType = row['game_type'] as String;
      final key = row['config_key'] as String;
      final value = row['config_value'];

      _gameConfigs.putIfAbsent(gameType, () => {});
      _gameConfigs[gameType]![key] = value;
    }
  }

  void _subscribeToUpdates() {
    _supabase
        .channel('game_configs')
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
    final response = await _supabase
        .from('game_configs')
        .select()
        .eq('game_type', gameType)
        .eq('is_active', true);

    _gameConfigs[gameType] = {};
    for (final row in response) {
      _gameConfigs[gameType]![row['config_key']] = row['config_value'];
    }
  }

  /// Get config value for a game
  T? getConfig<T>(String gameType, String key, [T? defaultValue]) {
    return _gameConfigs[gameType]?[key] as T? ?? defaultValue;
  }

  /// Get all configs for a game
  Map<String, dynamic> getConfigsForGame(String gameType) {
    return Map.from(_gameConfigs[gameType] ?? {});
  }

  /// Check if config exists
  bool hasConfig(String gameType, String key) {
    return _gameConfigs[gameType]?.containsKey(key) ?? false;
  }
}
```

---

## Usage in Game Rules

```dart
// Example: Using server configs in game rules

class TwentyNineRules {
  late int _turnTimeout;
  late int _minBid;
  late int _maxBid;

  void applyServerConfig(Map<String, dynamic> config) {
    _turnTimeout = config['turn_timeout'] as int? ?? 30;
    _minBid = config['min_bid'] as int? ?? 15;
    _maxBid = config['max_bid'] as int? ?? 28;
  }

  // Use feature flags for rule variants
  bool get useNewScoringSystem =>
      FeatureFlags.instance.isEnabled('new_scoring_v2');

  int get bidTimerDuration =>
      FeatureFlags.instance.getVariant('bid_timer_duration', 30);
}
```

---

## Update Prompt Widget

```dart
// lib/shared/widgets/update_prompt.dart

import 'package:flutter/material.dart';
import '../../core/services/update_service.dart';

class UpdatePrompt extends StatelessWidget {
  const UpdatePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UpdateStatus>(
      stream: UpdateService.instance.statusStream,
      initialData: UpdateService.instance.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data!;

        if (status != UpdateStatus.updateAvailable &&
            status != UpdateStatus.readyToInstall) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade700),
          ),
          child: Row(
            children: [
              Icon(
                status == UpdateStatus.readyToInstall
                    ? Icons.restart_alt
                    : Icons.system_update,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status == UpdateStatus.readyToInstall
                          ? 'Update Ready'
                          : 'Update Available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      status == UpdateStatus.readyToInstall
                          ? 'Restart the app to apply'
                          : 'A new version is available',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == UpdateStatus.updateAvailable)
                ElevatedButton(
                  onPressed: () async {
                    await UpdateService.instance.downloadAndInstall();
                  },
                  child: const Text('Update'),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    // Trigger app restart
                    // This would typically use a package like restart_app
                  },
                  child: const Text('Restart'),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Shorebird CLI Commands

```bash
# Initialize Shorebird in project
shorebird init

# Create a release
shorebird release android
shorebird release ios

# Create a patch (OTA update)
shorebird patch android
shorebird patch ios

# View release/patch info
shorebird releases list
shorebird patches list

# Rollback a patch
shorebird patches delete --patch-number=1
```

---

## Expected Output

- Shorebird configuration for OTA updates
- Update service with status tracking
- Feature flags system with real-time sync
- A/B testing support with deterministic assignment
- Server-side config sync
- Database schema for feature flags
- Update prompt UI component
- Rollout percentage support
- User targeting for beta features
