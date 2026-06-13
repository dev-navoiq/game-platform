#!/usr/bin/env bash
# Build a release-signed iOS IPA for TestFlight / App Store.
# Mirrors scripts/build-android-release.sh so the env-dart-define can't be
# forgotten the way it was on v0.1.0+6 (TestFlight build defaulted to
# Environment.development → hardcoded Mac LAN IP → broken testers).
#
# Usage:
#   scripts/build-ios-release.sh                # env=staging
#   ENV=production scripts/build-ios-release.sh # env=production
#
# After this completes, run `fastlane beta` from apps/flutter_app/ios to
# upload to TestFlight.

set -euo pipefail

if [ "$#" -gt 0 ]; then
  echo "✗ This script takes no positional args. Use the ENV environment variable:"
  echo "  scripts/build-ios-release.sh                # env=staging (default)"
  echo "  ENV=production scripts/build-ios-release.sh # env=production"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/flutter_app"

env_name="${ENV:-staging}"
if [ "$env_name" != "staging" ] && [ "$env_name" != "production" ]; then
  echo "✗ ENV must be 'staging' or 'production' for release builds (got: $env_name)."
  echo "  Refusing to ship a build pointed at the dev LAN IP."
  exit 1
fi

# Local dev pins Flutter via FVM; CI puts plain `flutter` on PATH. Honour an
# explicit FLUTTER_CMD override, otherwise pick whatever is available.
if [ -n "${FLUTTER_CMD:-}" ]; then
  : # honour the override
elif command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD="fvm flutter"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER_CMD="flutter"
else
  echo "✗ Neither fvm nor flutter found on PATH."
  exit 1
fi

cd "$APP_DIR"
$FLUTTER_CMD build ipa --release --dart-define=ENV="$env_name"

IPA_PATH="$(ls -t "$APP_DIR/build/ios/ipa/"*.ipa 2>/dev/null | head -1 || true)"
if [ -z "$IPA_PATH" ]; then
  echo "✗ Build reported success but no .ipa under $APP_DIR/build/ios/ipa/"
  exit 1
fi

echo
echo "✓ Built IPA (env=$env_name)"
echo "  → $IPA_PATH"
echo
echo "Next: cd apps/flutter_app/ios && fastlane beta"
