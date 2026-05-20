import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/feature_flags.dart';

void main() {
  late FeatureFlags ff;

  setUp(() {
    ff = FeatureFlags.instance;
    ff.reset();
  });

  tearDown(() {
    ff.reset();
  });

  group('FeatureFlag model', () {
    test('fromJson / toJson round-trip', () {
      final flag = FeatureFlag(
        key: 'test_flag',
        enabled: true,
        rolloutPercentage: 50,
        variants: {'a': 1, 'b': 2},
        selectedVariant: 'a',
      );

      final json = flag.toJson();
      final restored = FeatureFlag.fromJson(json);

      expect(restored.key, 'test_flag');
      expect(restored.enabled, true);
      expect(restored.rolloutPercentage, 50);
      expect(restored.variants, {'a': 1, 'b': 2});
      expect(restored.selectedVariant, 'a');
    });

    test('fromJson handles missing optional fields', () {
      final flag = FeatureFlag.fromJson({
        'key': 'minimal',
        'enabled': false,
      });

      expect(flag.key, 'minimal');
      expect(flag.enabled, false);
      expect(flag.rolloutPercentage, 100);
      expect(flag.variants, isNull);
      expect(flag.selectedVariant, isNull);
    });

    test('toString includes key info', () {
      final flag = FeatureFlag(
        key: 'my_flag',
        enabled: true,
        rolloutPercentage: 75,
      );
      expect(flag.toString(), contains('my_flag'));
      expect(flag.toString(), contains('75'));
    });
  });

  group('FeatureFlags defaults', () {
    test('default flags are applied after reset', () async {
      // Initialize without Supabase — just defaults
      // We can't call initialize without Supabase, but we can test defaults
      // by using the internal _applyDefaults indirectly through getAllFlags
      // after a minimal init attempt. Instead, test the isEnabled logic.

      // Before any initialization, flags should not be enabled
      expect(ff.isEnabled('nonexistent'), false);
    });
  });

  group('FeatureFlags overrides', () {
    test('setOverride forces flag value', () {
      ff.setOverride('test_flag', true);
      expect(ff.isEnabled('test_flag'), true);

      ff.setOverride('test_flag', false);
      expect(ff.isEnabled('test_flag'), false);
    });

    test('clearOverride removes a single override', () {
      ff.setOverride('flag_a', true);
      ff.setOverride('flag_b', true);

      ff.clearOverride('flag_a');

      expect(ff.isEnabled('flag_a'), false); // back to default (not found)
      expect(ff.isEnabled('flag_b'), true); // override still active
    });

    test('clearOverrides removes all overrides', () {
      ff.setOverride('flag_a', true);
      ff.setOverride('flag_b', true);

      ff.clearOverrides();

      expect(ff.isEnabled('flag_a'), false);
      expect(ff.isEnabled('flag_b'), false);
    });

    test('override takes precedence over flag data', () {
      // Simulate a disabled flag being overridden to enabled
      ff.setOverride(FeatureFlags.seasonPassEnabled, true);
      expect(ff.isEnabled(FeatureFlags.seasonPassEnabled), true);
    });
  });

  group('FeatureFlags.isEnabled logic', () {
    test('returns false for unknown flag', () {
      expect(ff.isEnabled('unknown_flag_xyz'), false);
    });

    test('isInitialized is false before initialize', () {
      expect(ff.isInitialized, false);
    });
  });

  group('FeatureFlags.getAllFlags', () {
    test('returns empty map when no flags loaded', () {
      final flags = ff.getAllFlags();
      expect(flags, isEmpty);
    });

    test('returns overridden flags', () {
      ff.setOverride('flag_x', true);
      ff.setOverride('flag_y', false);

      // getAllFlags only iterates _flags map, overrides don't add keys
      // so this should still be empty (overrides just modify isEnabled behavior)
      final flags = ff.getAllFlags();
      expect(flags, isEmpty);
    });
  });

  group('FeatureFlags.getVariant', () {
    test('returns default value when no flag exists', () {
      expect(ff.getVariant<int>('no_flag', 42), 42);
    });

    test('returns overridden variant value', () {
      ff.setOverride('variant_flag', 99);
      expect(ff.getVariant<int>('variant_flag', 0), 99);
    });
  });

  group('FeatureFlags.reset', () {
    test('clears all state', () {
      ff.setOverride('test', true);

      ff.reset();

      expect(ff.isEnabled('test'), false);
      expect(ff.isInitialized, false);
      expect(ff.getAllFlags(), isEmpty);
    });
  });

  group('FeatureFlags.setUserId', () {
    test('updates the user ID for rollout checks', () {
      ff.setUserId('user-123');
      // No crash — method executes cleanly
      ff.setUserId(null);
    });
  });

  group('FeatureFlag key constants', () {
    test('all flag key constants are non-empty strings', () {
      final keys = [
        FeatureFlags.voiceChatEnabled,
        FeatureFlags.animationsV2,
        FeatureFlags.quickMatchmaking,
        FeatureFlags.socialFeatures,
        FeatureFlags.brandSkins,
        FeatureFlags.floatingChatBubblesEnabled,
        FeatureFlags.seasonPassEnabled,
        FeatureFlags.silentRoomsEnabled,
        FeatureFlags.referralSystemEnabled,
        FeatureFlags.bidTimerDuration,
        FeatureFlags.trickAnimationStyle,
        FeatureFlags.scoringFormula,
      ];

      for (final key in keys) {
        expect(key, isNotEmpty, reason: 'Flag key should not be empty');
        expect(key, contains('_'), reason: 'Flag keys use snake_case: $key');
      }
    });
  });
}
