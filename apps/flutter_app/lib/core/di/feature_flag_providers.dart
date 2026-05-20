import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/config_sync_service.dart';
import '../services/feature_flags.dart';
import '../services/update_service.dart';

// ── Feature Flags ─────────────────────────────────────────────────────────

final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags.instance;
});

/// Check a single flag by key.
/// Usage: `ref.watch(isFeatureEnabledProvider('season_pass_enabled'))`
final isFeatureEnabledProvider = Provider.family<bool, String>((ref, flagKey) {
  final ff = ref.watch(featureFlagsProvider);
  return ff.isEnabled(flagKey);
});

// ── Config Sync ───────────────────────────────────────────────────────────

final configSyncProvider = Provider<ConfigSyncService>((ref) {
  return ConfigSyncService.instance;
});

// ── Update Service ────────────────────────────────────────────────────────

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService.instance;
});

final updateStatusProvider = StreamProvider<UpdateStatus>((ref) {
  return UpdateService.instance.statusStream;
});
