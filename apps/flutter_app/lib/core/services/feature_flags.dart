import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dynamic feature flag service with server sync and local caching.
///
/// Initialise once after Supabase is ready:
/// ```dart
/// await FeatureFlags.instance.initialize(
///   supabase: Supabase.instance.client,
///   userId: currentUser?.id,
/// );
/// ```
class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  static FeatureFlags get instance => _instance;

  FeatureFlags._internal();

  // ── Flag key constants ──────────────────────────────────────────────────
  static const String voiceChatEnabled = 'voice_chat_enabled';
  static const String animationsV2 = 'animations_v2';
  static const String quickMatchmaking = 'quick_matchmaking';
  static const String socialFeatures = 'social_features';
  static const String brandSkins = 'brand_skins';
  static const String floatingChatBubblesEnabled =
      'floating_chat_bubbles_enabled';
  static const String seasonPassEnabled = 'season_pass_enabled';
  static const String silentRoomsEnabled = 'silent_rooms_enabled';
  static const String referralSystemEnabled = 'referral_system_enabled';

  // A/B test flags
  static const String bidTimerDuration = 'bid_timer_duration';
  static const String trickAnimationStyle = 'trick_animation_style';
  static const String scoringFormula = 'scoring_formula';

  // ── Internal state ──────────────────────────────────────────────────────
  final Map<String, FeatureFlag> _flags = {};
  final Map<String, dynamic> _overrides = {};
  SupabaseClient? _supabase;
  String? _userId;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // ── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize({
    required SupabaseClient supabase,
    String? userId,
  }) async {
    _supabase = supabase;
    _userId = userId;

    // Load cached flags for instant availability
    await _loadCachedFlags();

    // Apply built-in defaults for any flags not in cache
    _applyDefaults();

    // Fetch fresh flags from server (non-blocking on failure)
    await _fetchFlagsFromServer();

    // Subscribe to real-time updates
    _subscribeToFlagUpdates();

    _initialized = true;
  }

  /// Re-initialise with a new user ID (e.g. after login).
  void setUserId(String? userId) {
    _userId = userId;
  }

  // ── Flag queries ────────────────────────────────────────────────────────

  /// Returns `true` if the flag is enabled for the current user.
  bool isEnabled(String flagKey) {
    // 1. Check dev overrides first
    if (_overrides.containsKey(flagKey)) {
      return _overrides[flagKey] as bool;
    }

    final flag = _flags[flagKey];
    if (flag == null) return false;
    if (!flag.enabled) return false;

    // 2. Check explicit targeting
    if (flag.targetUserIds != null &&
        _userId != null &&
        flag.targetUserIds!.contains(_userId)) {
      return true;
    }

    // 3. Check explicit exclusion
    if (flag.excludeUserIds != null &&
        _userId != null &&
        flag.excludeUserIds!.contains(_userId)) {
      return false;
    }

    // 4. Rollout percentage
    if (flag.rolloutPercentage >= 100) return true;
    if (flag.rolloutPercentage <= 0) return false;

    // Deterministic rollout based on user ID
    if (_userId != null) {
      final hash = _userId.hashCode.abs();
      return (hash % 100) < flag.rolloutPercentage;
    }

    return flag.enabled;
  }

  /// Get the assigned A/B test variant value for the current user.
  T getVariant<T>(String flagKey, T defaultValue) {
    if (_overrides.containsKey(flagKey)) {
      return _overrides[flagKey] as T;
    }

    final flag = _flags[flagKey];
    if (flag == null || flag.variants == null || flag.variants!.isEmpty) {
      return defaultValue;
    }

    final variantKey =
        _getVariantForUser(flagKey, flag.variants!.keys.toList());
    return flag.variants![variantKey] as T? ?? defaultValue;
  }

  // ── Dev overrides ───────────────────────────────────────────────────────

  void setOverride(String flagKey, dynamic value) {
    _overrides[flagKey] = value;
  }

  void clearOverride(String flagKey) {
    _overrides.remove(flagKey);
  }

  void clearOverrides() {
    _overrides.clear();
  }

  /// All flag states (for debug UI).
  Map<String, bool> getAllFlags() {
    return _flags.map((k, v) => MapEntry(k, isEnabled(k)));
  }

  /// All flag metadata (for debug UI).
  Map<String, FeatureFlag> getAllFlagDetails() {
    return Map.unmodifiable(_flags);
  }

  // ── Internals ───────────────────────────────────────────────────────────

  static const _cacheKey = 'feature_flags_cache';

  void _applyDefaults() {
    const defaults = <String, FeatureFlag>{
      voiceChatEnabled: FeatureFlag(
        key: voiceChatEnabled,
        enabled: true,
        rolloutPercentage: 100,
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
      floatingChatBubblesEnabled: FeatureFlag(
        key: floatingChatBubblesEnabled,
        enabled: true,
        rolloutPercentage: 100,
      ),
      seasonPassEnabled: FeatureFlag(
        key: seasonPassEnabled,
        enabled: false,
        rolloutPercentage: 0,
      ),
      silentRoomsEnabled: FeatureFlag(
        key: silentRoomsEnabled,
        enabled: false,
        rolloutPercentage: 0,
      ),
      referralSystemEnabled: FeatureFlag(
        key: referralSystemEnabled,
        enabled: true,
        rolloutPercentage: 100,
      ),
      bidTimerDuration: FeatureFlag(
        key: bidTimerDuration,
        enabled: true,
        rolloutPercentage: 100,
        variants: {'short': 20, 'default': 30, 'long': 45},
        selectedVariant: 'default',
      ),
    };

    for (final entry in defaults.entries) {
      _flags.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Future<void> _loadCachedFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final cached = json.decode(cachedJson) as Map<String, dynamic>;
        for (final entry in cached.entries) {
          _flags[entry.key] =
              FeatureFlag.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (_) {
      // Ignore cache errors — defaults will apply
    }
  }

  Future<void> _fetchFlagsFromServer() async {
    if (_supabase == null) return;

    try {
      final response = await _supabase!
          .from('feature_flags')
          .select()
          .eq('is_active', true);

      for (final row in response) {
        final flag = FeatureFlag(
          key: row['flag_key'] as String,
          enabled: row['enabled'] as bool,
          rolloutPercentage: row['rollout_percentage'] as int? ?? 100,
          variants: row['variants'] != null
              ? Map<String, dynamic>.from(row['variants'] as Map)
              : null,
          selectedVariant: row['default_variant'] as String?,
          targetUserIds:
              (row['target_user_ids'] as List?)?.cast<String>(),
          excludeUserIds:
              (row['exclude_user_ids'] as List?)?.cast<String>(),
        );
        _flags[flag.key] = flag;
      }

      await _cacheFlags();
    } catch (_) {
      // Use cached / default flags on network error
    }
  }

  Future<void> _cacheFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _flags.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_cacheKey, json.encode(data));
    } catch (_) {
      // Non-critical — ignore
    }
  }

  void _subscribeToFlagUpdates() {
    if (_supabase == null) return;

    _supabase!
        .channel('feature_flags_changes')
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
      final key = payload.oldRecord['flag_key'] as String?;
      if (key != null) _flags.remove(key);
    } else {
      final row = payload.newRecord;
      final key = row['flag_key'] as String?;
      if (key != null) {
        _flags[key] = FeatureFlag(
          key: key,
          enabled: row['enabled'] as bool? ?? false,
          rolloutPercentage: row['rollout_percentage'] as int? ?? 100,
          variants: row['variants'] != null
              ? Map<String, dynamic>.from(row['variants'] as Map)
              : null,
          selectedVariant: row['default_variant'] as String?,
        );
      }
    }
    _cacheFlags();
  }

  String _getVariantForUser(String flagKey, List<String> variants) {
    if (variants.isEmpty) return '';
    if (_userId == null) return variants.first;

    // Deterministic variant assignment based on userId + flagKey
    final hash = '$_userId:$flagKey'.hashCode.abs();
    return variants[hash % variants.length];
  }

  /// Reset for testing purposes.
  void reset() {
    _flags.clear();
    _overrides.clear();
    _supabase = null;
    _userId = null;
    _initialized = false;
  }
}

/// A single feature flag definition.
class FeatureFlag {
  final String key;
  final bool enabled;
  final int rolloutPercentage;
  final Map<String, dynamic>? variants;
  final String? selectedVariant;
  final List<String>? targetUserIds;
  final List<String>? excludeUserIds;

  const FeatureFlag({
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
      variants: json['variants'] != null
          ? Map<String, dynamic>.from(json['variants'] as Map)
          : null,
      selectedVariant: json['selectedVariant'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'enabled': enabled,
        'rolloutPercentage': rolloutPercentage,
        if (variants != null) 'variants': variants,
        if (selectedVariant != null) 'selectedVariant': selectedVariant,
      };

  @override
  String toString() =>
      'FeatureFlag($key, enabled=$enabled, rollout=$rolloutPercentage%)';
}
