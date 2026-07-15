import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/config/env_config.dart';
import 'package:flutter_app/core/services/ad_mode.dart';

void main() {
  group('resolveDefaultAdMode', () {
    test('flutter test always gets mock, regardless of environment', () {
      for (final env in Environment.values) {
        expect(
          resolveDefaultAdMode(isTest: true, environment: () => env),
          AdMode.mock,
          reason: env.name,
        );
      }
    });

    test('production defaults to google', () {
      expect(
        resolveDefaultAdMode(
          isTest: false,
          environment: () => Environment.production,
        ),
        AdMode.google,
      );
    });

    test('development and staging default to house', () {
      for (final env in [Environment.development, Environment.staging]) {
        expect(
          resolveDefaultAdMode(isTest: false, environment: () => env),
          AdMode.house,
          reason: env.name,
        );
      }
    });

    test('falls back to house (never the real SDK) when the environment '
        'is unreadable (EnvConfig not initialized)', () {
      expect(
        resolveDefaultAdMode(
          isTest: false,
          environment: () => throw StateError('EnvConfig not initialized'),
        ),
        AdMode.house,
      );
    });
  });
}
