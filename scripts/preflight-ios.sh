#!/usr/bin/env bash
# Pre-flight checks before `flutter run` on iOS.
# Exits non-zero on first hard failure with an actionable message.
# See memory/build-environment-stability.md for why each check exists.
#
# Usage: scripts/preflight-ios.sh <device|sim> <development|staging|production>
#   Default: device development

set -uo pipefail

TARGET="${1:-device}"
ENV_NAME="${2:-development}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/flutter_app"

DEVICE_ID="00008150-00141D4C0C61401C"   # AMBAR's iPhone 17 Pro
SIM_ID="93B3CE12-584D-4F1D-8C42-C1F94C109893"  # iPhone 17 sim
APPLE_TEAM="GS59945524"

green() { printf "\033[32m✓\033[0m %s\n" "$1"; }
yellow() { printf "\033[33m⚠\033[0m %s\n" "$1"; }
red() { printf "\033[31m✗\033[0m %s\n" "$1"; }
die() { red "$1"; echo "   $2"; exit 1; }

echo "Pre-flight: target=$TARGET env=$ENV_NAME"
echo

# 1. FVM pin matches what `flutter` resolves to.
if [ -f "$PROJECT_ROOT/.fvmrc" ]; then
  pinned="$(grep -oE '"flutter":\s*"[^"]+"' "$PROJECT_ROOT/.fvmrc" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  active="$(fvm flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $2}')"
  if [ "$pinned" = "$active" ]; then
    green "Flutter version: $active (matches .fvmrc pin)"
  else
    yellow "Flutter drift: .fvmrc=$pinned, active=$active. Prefix commands with \`fvm flutter\`."
  fi
fi

# 2. No stale flutter_tools dart processes from prior sessions.
stale_pids="$(pgrep -f "flutter_tools.snapshot run" || true)"
if [ -n "$stale_pids" ]; then
  yellow "Stale flutter_tools processes found: $stale_pids"
  echo "   Killing..."
  echo "$stale_pids" | xargs kill 2>/dev/null || true
  sleep 1
  green "Stale processes killed"
else
  green "No stale flutter_tools processes"
fi

# 3. Zombie Runner.app inside the simulator (only relevant for sim).
if [ "$TARGET" = "sim" ]; then
  zombie_runners="$(pgrep -f "CoreSimulator/Devices.*Runner.app/Runner" || true)"
  if [ -n "$zombie_runners" ]; then
    yellow "Zombie Runner.app in simulator: $zombie_runners — killing"
    echo "$zombie_runners" | xargs kill 2>/dev/null || true
  fi
fi

# 4. Build dir. The project moved out of iCloud (~/Documents → ~/Developer) on
#    2026-06-24, so iCloud no longer injects xattrs and a plain build/ dir is fine.
#    The legacy symlink-to-/tmp workaround is still accepted but no longer required.
if [ -L "$APP_DIR/build" ]; then
  green "build/ symlink (legacy iCloud workaround): $(readlink "$APP_DIR/build")"
else
  green "build/ is a normal directory (project is outside iCloud — symlink not needed)"
fi

# 5. Apple Dev cert in keychain (only needed for device targets).
if [ "$TARGET" = "device" ]; then
  if security find-identity -p codesigning -v 2>/dev/null | grep -q "Apple Development: TUSKI GUPTA"; then
    green "Apple Dev cert in keychain (team $APPLE_TEAM)"
  else
    die "Apple Dev cert missing" "Open Xcode > Settings > Accounts and refresh the cert for tuskigupta@navoiq.com."
  fi
fi

# 6. Dev backend reachable via the URL baked into env_config (development
# only). env_config uses the Mac's mDNS name (<host>.local) so router IP
# reshuffles no longer break device builds; this check curls the actual
# configured URL, which also catches a renamed Mac or stopped Supabase.
if [ "$ENV_NAME" = "development" ]; then
  dev_url="$(grep -oE "defaultValue: 'http://[^']+'" "$APP_DIR/lib/core/config/env_config.dart" | head -1 | sed "s/defaultValue: '//;s/'\$//")"
  if [ -z "$dev_url" ]; then
    yellow "Could not extract dev SUPABASE_URL from env_config.dart"
  else
    if curl -sS -o /dev/null --max-time 5 "$dev_url/auth/v1/health" 2>/dev/null; then
      green "Dev Supabase reachable at $dev_url"
    else
      yellow "Dev Supabase NOT reachable at $dev_url"
      echo "   Check: supabase status; scutil --get LocalHostName matches env_config;"
      echo "   or launch with --dart-define=SUPABASE_URL=http://\$(ipconfig getifaddr en0):54321"
    fi
  fi
fi

# 7. Cloud backend reachable (staging/production only).
if [ "$ENV_NAME" = "staging" ] || [ "$ENV_NAME" = "production" ]; then
  if [ "$ENV_NAME" = "staging" ]; then
    url="https://toqtbqmhxmemixaumljz.supabase.co"
  else
    url="https://obtgysfcyenbfouvfixs.supabase.co"
  fi
  http_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 -I "$url" 2>/dev/null || echo "000")"
  if [ "$http_code" = "000" ]; then
    die "$ENV_NAME backend unreachable: $url" "Check internet connection and Supabase project status."
  else
    green "$ENV_NAME backend reachable: $url (HTTP $http_code)"
  fi
fi

# 8. Target device available.
if [ "$TARGET" = "device" ]; then
  if fvm flutter devices --machine 2>/dev/null | grep -q "$DEVICE_ID"; then
    green "iPhone 17 Pro ($DEVICE_ID) connected"
  else
    die "iPhone 17 Pro not connected" "Plug in via cable, unlock the phone, trust this Mac if prompted."
  fi
else
  # Simulator: must be booted.
  if xcrun simctl list devices booted 2>/dev/null | grep -q "$SIM_ID"; then
    green "iPhone 17 sim ($SIM_ID) booted"
  else
    yellow "iPhone 17 sim not booted — booting"
    xcrun simctl boot "$SIM_ID" 2>&1 | head -1
    xcrun simctl bootstatus "$SIM_ID" -b >/dev/null 2>&1
    green "iPhone 17 sim booted"
  fi
  # Verify destination resolution works (Xcode 26.4.1 breaks this on some setups).
  if /usr/bin/arch -arm64e xcrun xcodebuild -workspace "$APP_DIR/ios/Runner.xcworkspace" -scheme Runner -destination "id=$SIM_ID" -showBuildSettings 2>&1 | grep -q "SDKROOT"; then
    green "Simulator destination resolves"
  else
    red "Xcode cannot resolve simulator destination id=$SIM_ID"
    echo "   This is the Xcode 26.4.1 CoreSimulator regression."
    echo "   Workaround: use device target instead. Run with: $0 device $ENV_NAME"
    exit 1
  fi
fi

echo
green "All pre-flight checks passed."
