#!/usr/bin/env bash
# Build a release-signed Android artifact.
# Pulls the keystore password from the macOS keychain and exposes it as
# ANDROID_KEYSTORE_PASSWORD so android/app/build.gradle.kts can apply the
# release signing config.
#
# Usage:
#   scripts/build-android-release.sh apk        # release APK (for Firebase App Distribution)
#   scripts/build-android-release.sh appbundle  # release AAB (for Google Play)

set -euo pipefail

ARTIFACT="${1:-apk}"
if [ "$ARTIFACT" != "apk" ] && [ "$ARTIFACT" != "appbundle" ]; then
  echo "Usage: $0 [apk|appbundle]"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/flutter_app"

# Source the keystore password: env var wins (so CI can inject it), otherwise
# fall back to macOS keychain (local dev convenience).
if [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  pwd_value="$ANDROID_KEYSTORE_PASSWORD"
elif [ "$(uname)" = "Darwin" ]; then
  pwd_value="$(security find-generic-password -s "android-keystore-password" -w 2>/dev/null || true)"
fi
if [ -z "${pwd_value:-}" ]; then
  echo "✗ Keystore password not found. Either:"
  echo "  - Set the ANDROID_KEYSTORE_PASSWORD env var (CI), or"
  echo "  - On macOS, add it to the keychain: security add-generic-password -a \"\$USER\" -s \"android-keystore-password\" -w"
  exit 1
fi

env_name="${ENV:-staging}"

# Local dev pins Flutter via FVM; CI (subosito/flutter-action) puts plain
# `flutter` on PATH. Use whichever is available so the same script powers
# both. Explicit override via FLUTTER_CMD if needed.
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
ANDROID_KEYSTORE_PASSWORD="$pwd_value" \
  $FLUTTER_CMD build "$ARTIFACT" --release --dart-define=ENV="$env_name"

echo
echo "✓ Built $ARTIFACT (env=$env_name)"
case "$ARTIFACT" in
  apk)         echo "  → $APP_DIR/build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle)   echo "  → $APP_DIR/build/app/outputs/bundle/release/app-release.aab" ;;
esac
