#!/usr/bin/env bash
# Build a release APK and push it to Firebase App Distribution.
# Wraps scripts/build-android-release.sh + `firebase appdistribution:distribute`
# so beta shipping is one command both locally and in CI.
#
# Usage:
#   scripts/distribute-android.sh                              # env=staging, notes=last commit
#   scripts/distribute-android.sh staging                      # explicit env
#   scripts/distribute-android.sh staging "Multiplayer fix"    # custom notes
#
# Env knobs:
#   FIREBASE_TESTERS  comma-separated emails to notify (default: ambartyagi@gmail.com)
#   FIREBASE_TOKEN    Firebase CI token from `firebase login:ci`. Used by CI.
#                     When unset locally, the `firebase` CLI falls back to
#                     whatever account `firebase login` left signed in.
#
# Prereqs:
#   - Keystore + ANDROID_KEYSTORE_PASSWORD (see build-android-release.sh)
#   - `firebase` CLI installed (`brew install firebase-cli` or `npm i -g firebase-tools`)

set -euo pipefail

ENV_NAME="${1:-staging}"
shift || true
NOTES="${*:-$(git log -1 --pretty=%s)}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/flutter_app"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"

# Map env → Firebase app + project. Add production once it's provisioned.
case "$ENV_NAME" in
  staging)
    APP_ID="1:552391106337:android:caa57fba15b4709798e860"
    FIREBASE_PROJECT="game-platform-staging"
    ;;
  production)
    echo "✗ production Firebase target not configured yet."
    echo "  Create the prod project, register the Android app, and add the"
    echo "  app id + project id to this script before retrying."
    exit 1
    ;;
  *)
    echo "✗ unknown env: $ENV_NAME (expected: staging|production)"
    exit 1
    ;;
esac

TESTERS="${FIREBASE_TESTERS:-ambartyagi@gmail.com}"

echo "→ Building release APK (env=$ENV_NAME)"
ENV="$ENV_NAME" bash "$PROJECT_ROOT/scripts/build-android-release.sh" apk

if [ ! -f "$APK_PATH" ]; then
  echo "✗ Expected APK not found at $APK_PATH"
  exit 1
fi

echo
echo "→ Uploading to Firebase App Distribution"
echo "  app:      $APP_ID"
echo "  project:  $FIREBASE_PROJECT"
echo "  testers:  $TESTERS"
echo "  notes:    $NOTES"
echo

firebase appdistribution:distribute "$APK_PATH" \
  --app "$APP_ID" \
  --project "$FIREBASE_PROJECT" \
  --release-notes "$NOTES" \
  --testers "$TESTERS"

echo
echo "✓ Done."
