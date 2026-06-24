#!/usr/bin/env bash
# Run the Flutter integration_test suite on a dedicated iOS simulator and
# record the simulator screen to a .mov file for human review.
#
# Designed to be called from BOTH:
#   - the self-hosted GitHub Actions runner (.github/workflows/ui-tests-mac.yml)
#   - a developer shell, for local smoke testing
#
# Outputs (in $OUT_DIR, defaults to ./ui-run-artifacts):
#   - run.mov            screen recording of the entire test run
#   - test.log           raw flutter test output
#   - summary.txt        one-line pass/fail + duration
#
# Env vars:
#   SIM_NAME      Simulator display name to use (default: CI-iPhone-17).
#                 Created on first run if missing.
#   SIM_DEVICE    Apple device type ID for creation
#                 (default: com.apple.CoreSimulator.SimDeviceType.iPhone-17).
#   SIM_RUNTIME   Apple runtime ID for creation
#                 (default: latest iOS runtime found via simctl).
#   OUT_DIR       Where artifacts land (default: ./ui-run-artifacts).
#   TEST_TARGET   Path/glob passed to `flutter test` (default: integration_test).
#   FLUTTER       Flutter command to use (default: `fvm flutter`).
#
# Exit code = the underlying `flutter test` exit code; recording is always
# finalized before exit so the .mov is viewable even on failure.

set -u
set -o pipefail

SIM_NAME="${SIM_NAME:-CI-iPhone-17}"
SIM_DEVICE="${SIM_DEVICE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}"
OUT_DIR="${OUT_DIR:-$(pwd)/ui-run-artifacts}"
TEST_TARGET="${TEST_TARGET:-integration_test}"
FLUTTER="${FLUTTER:-fvm flutter}"

# Pick the newest installed iOS runtime if none specified.
if [[ -z "${SIM_RUNTIME:-}" ]]; then
  SIM_RUNTIME=$(
    xcrun simctl list runtimes available 2>/dev/null \
      | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' \
      | tail -1
  )
fi
if [[ -z "$SIM_RUNTIME" ]]; then
  echo "fatal: no iOS runtime found via simctl. Install one via Xcode." >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
MOV="$OUT_DIR/run.mov"
LOG="$OUT_DIR/test.log"
SUMMARY="$OUT_DIR/summary.txt"
rm -f "$MOV" "$LOG" "$SUMMARY"

# ── 1. Ensure the dedicated CI simulator exists ──────────────────────────────
# NOTE: `simctl list devices "<SimRuntime ID>"` is a no-op filter — it only
# accepts display names ("iOS 26.4"). Cheaper to scan everything and pick by
# unique name. SIM_NAME must be unique across runtimes (it is by convention).
UDID=$(
  xcrun simctl list devices 2>/dev/null \
    | grep -F " $SIM_NAME (" \
    | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1
)

if [[ -z "$UDID" ]]; then
  echo "[run-ui-tests] creating simulator '$SIM_NAME' ($SIM_DEVICE / $SIM_RUNTIME)"
  UDID=$(xcrun simctl create "$SIM_NAME" "$SIM_DEVICE" "$SIM_RUNTIME")
  if [[ -z "$UDID" ]]; then
    echo "fatal: simctl create failed" >&2
    exit 2
  fi
fi
echo "[run-ui-tests] using simulator $SIM_NAME ($UDID)"

# ── 2. Boot the simulator (idempotent) ───────────────────────────────────────
STATE=$(
  xcrun simctl list devices 2>/dev/null \
    | grep -F "$UDID" \
    | grep -oE '\((Booted|Shutdown|Booting|Shutting Down|Creating)\)' \
    | head -1 \
    | tr -d '()'
)
if [[ "$STATE" != "Booted" ]]; then
  echo "[run-ui-tests] booting $SIM_NAME (was: ${STATE:-unknown})"
  xcrun simctl boot "$UDID"
fi
# Wait for SpringBoard so recording doesn't capture a black screen.
xcrun simctl bootstatus "$UDID" -b >/dev/null

# Open Simulator.app so the device is on-screen (improves recording quality
# and lets a human watch the run unfold). Headless recording works without
# it, but is harder to debug.
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true

# ── 3. Start screen recording in the background ──────────────────────────────
echo "[run-ui-tests] starting screen recording -> $MOV"
xcrun simctl io "$UDID" recordVideo --codec h264 "$MOV" &
REC_PID=$!

# Always finalize the recording, even on test failure or Ctrl-C, so the .mov
# header is written and the file is playable.
cleanup() {
  if kill -0 "$REC_PID" 2>/dev/null; then
    echo "[run-ui-tests] stopping screen recording (pid $REC_PID)"
    kill -INT "$REC_PID" 2>/dev/null || true
    # simctl needs ~1s to flush; wait for the process to exit naturally.
    wait "$REC_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ── 4. Run the integration tests ─────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)/apps/flutter_app"
cd "$APP_DIR"

# Diagnostic dump — answers "why doesn't xcodebuild see the sim". Cheap;
# always written to test.log so post-mortem doesn't need a re-run.
{
  echo "── Diagnostic dump ───────────────────────────────────────"
  echo "[xcode-select -p]"
  xcode-select -p
  echo "[xcrun --find xcodebuild]"
  xcrun --find xcodebuild
  echo "[xcrun simctl list devices booted]"
  xcrun simctl list devices booted
  echo "[flutter devices]"
  $FLUTTER devices
  echo "[xcodebuild -showdestinations -scheme Runner -workspace ios/Runner.xcworkspace]"
  xcodebuild -showdestinations -scheme Runner -workspace ios/Runner.xcworkspace 2>&1 \
    | head -40 || true
  echo
  echo "[xcodebuild -showdestinations -scheme Runner -workspace ios/Runner.xcworkspace -sdk iphonesimulator]"
  # If the simulator destinations DISAPPEAR when -sdk iphonesimulator is added,
  # the scheme/target chain is incompatible with the sim SDK (a pod is
  # iphoneos-only). If they STAY, xcodebuild can resolve sims and the bug is
  # in how flutter+xcodebuild combine -sdk with -destination id=.
  xcodebuild -showdestinations -scheme Runner -workspace ios/Runner.xcworkspace \
    -sdk iphonesimulator 2>&1 | head -40 || true
  echo
  echo "[xcodebuild -showBuildSettings ... Debug iphonesimulator | grep SUPPORTED_PLATFORMS|SDKROOT|VALID_ARCHS|EXCLUDED_ARCHS]"
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Debug -sdk iphonesimulator -showBuildSettings 2>&1 \
    | grep -E "SUPPORTED_PLATFORMS|SDKROOT|VALID_ARCHS|EXCLUDED_ARCHS|TARGETED_DEVICE_FAMILY|EFFECTIVE_PLATFORM_NAME" \
    | sort -u | head -30 || true
  echo
  echo "── Workaround experiment: direct xcodebuild with explicit platform ──"
  # Flutter (and `flutter build ios --simulator`) invoke xcodebuild with
  # `-destination id=<UDID>` — no platform prefix. In Xcode 26.4.1 this seems
  # to resolve the wrong destination set (iOS Device-only) and fails. The
  # standard incantation `-destination "platform=iOS Simulator,id=<UDID>"`
  # should resolve correctly. If this build SUCCEEDS, we have the workaround:
  # bypass Flutter and drive xcodebuild directly for the actual test build.
  echo "[xcodebuild build, -destination id=UDID  (mirrors Flutter)]"
  xcodebuild build -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Debug -sdk iphonesimulator \
    -destination "id=$UDID" 2>&1 | tail -25 || true
  echo
  echo "[xcodebuild build, -destination platform=iOS Simulator,id=UDID]"
  xcodebuild build -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" 2>&1 | tail -25 || true
  echo "── End diagnostic dump ───────────────────────────────────"
} 2>&1 | tee -a "$LOG"

echo "[run-ui-tests] running '$FLUTTER test $TEST_TARGET' on $UDID"
START_TS=$SECONDS
set +e
# `tee -a` (append) — earlier `tee` form truncated the diagnostic dump
# above. `--verbose` exposes the xcodebuild command Flutter generates so
# we can see exactly which flags it's passing (e.g. -sdk iphoneos vs
# iphonesimulator, or a generic/platform= destination).
$FLUTTER test "$TEST_TARGET" -d "$UDID" --reporter expanded --verbose 2>&1 \
  | tee -a "$LOG"
TEST_EXIT=${PIPESTATUS[0]}
set -e
DURATION=$(( SECONDS - START_TS ))

# ── 5. Write summary ────────────────────────────────────────────────────────
if [[ $TEST_EXIT -eq 0 ]]; then
  RESULT="PASS"
else
  RESULT="FAIL (exit=$TEST_EXIT)"
fi
{
  echo "result:   $RESULT"
  echo "duration: ${DURATION}s"
  echo "sim:      $SIM_NAME ($UDID)"
  echo "target:   $TEST_TARGET"
  echo "log:      $LOG"
  echo "video:    $MOV"
} | tee "$SUMMARY"

# cleanup() runs on EXIT and finalizes the .mov.
exit "$TEST_EXIT"
