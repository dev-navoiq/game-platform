#!/usr/bin/env bash
# Build a release-signed Android artifact.
# Pulls the keystore password from the macOS keychain and exposes it as
# ANDROID_KEYSTORE_PASSWORD so android/app/build.gradle.kts can apply the
# release signing config.
#
# Usage:
#   scripts/build-android-release.sh apk        # release APK (for Firebase App Distribution)
#   scripts/build-android-release.sh appbundle  # release AAB (for Google Play)

set -uo pipefail

ARTIFACT="${1:-apk}"
if [ "$ARTIFACT" != "apk" ] && [ "$ARTIFACT" != "appbundle" ]; then
  echo "Usage: $0 [apk|appbundle]"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/flutter_app"

pwd_value="$(security find-generic-password -s "android-keystore-password" -w 2>/dev/null || true)"
if [ -z "$pwd_value" ]; then
  echo "✗ android-keystore-password not found in macOS keychain."
  echo "  Add it with: security add-generic-password -a \"\$USER\" -s \"android-keystore-password\" -w"
  exit 1
fi

env_name="${ENV:-staging}"

cd "$APP_DIR"
ANDROID_KEYSTORE_PASSWORD="$pwd_value" \
  fvm flutter build "$ARTIFACT" --release --dart-define=ENV="$env_name"

echo
echo "✓ Built $ARTIFACT (env=$env_name)"
case "$ARTIFACT" in
  apk)         echo "  → $APP_DIR/build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle)   echo "  → $APP_DIR/build/app/outputs/bundle/release/app-release.aab" ;;
esac
