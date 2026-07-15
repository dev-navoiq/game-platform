---
description: Pre-flight checks + launch the Flutter app on iOS (device or simulator) against a chosen environment
allowed-tools: Bash, Read
---

You are launching the Flutter game-platform app on iOS with pre-flight environment checks.

Parse `$ARGUMENTS` to determine target and env:
- First word is target: `device` (default) or `sim`
- Second word is env: `development` (default), `staging`, or `production`

Examples of `$ARGUMENTS`:
- `device staging` → physical iPhone 17 Pro, staging Supabase
- `sim development` → iPhone 17 simulator, local Supabase
- (empty) → device, development

## Steps

1. **Run pre-flight** via Bash:
   ```
   /Users/ambar/Developer/game-platform/scripts/preflight-ios.sh <target> <env>
   ```
   The script kills stale processes, verifies LAN IP / cert / symlink / device availability, and tests simulator destination resolution.

2. **If pre-flight exited non-zero:** print the script's last few lines verbatim and STOP. Do not attempt `flutter run`. The script's error message is the actionable item — don't try to second-guess or auto-fix.

3. **If pre-flight passed, launch flutter:**
   - For `device`: use **release mode** (AOT, no debug-attach — works around the Xcode 26.4.1 Apple-Events debug-session timeout). Hot reload is unavailable but app runs reliably.
     ```
     cd /Users/ambar/Developer/game-platform/apps/flutter_app && fvm flutter run --release -d 00008150-00141D4C0C61401C --dart-define=ENV=<env>
     ```
     **When env is `development`, also pass `--dart-define=ALLOW_DEV_RELEASE=true`** — main.dart has a fail-closed guard (SECURITY-AUDIT M7) that throws on release+development, which otherwise leaves the app dead on the native splash screen. Never pass this flag for staging/production builds.
   - For `sim`: use **debug mode** (hot reload works). Note that sim is currently affected by the Xcode 26.4.1 CoreSimulator regression — if pre-flight didn't catch it, the run will fail with "Unable to find a destination matching id=...". Fall back to device.
     ```
     cd /Users/ambar/Developer/game-platform/apps/flutter_app && fvm flutter run -d 93B3CE12-584D-4F1D-8C42-C1F94C109893 --dart-define=ENV=<env>
     ```
   - Launch in background using Bash with `run_in_background=true` and pipe output to a **session-unique log path** (e.g. `/tmp/flutter-launch-$$.log` or a file in the session scratchpad — NOT a fixed `/tmp/flutter-launch.log`, which collides when two sessions deploy concurrently). Watch the log via a background Bash with an `until grep` loop, exit on "Flutter run key commands" (ready) OR any error pattern. Notify the user when ready or with the error context.
   - Before launching, check `pgrep -f "flutter_tools.snapshot run"` — another session may already be mid-deploy to the same device; two concurrent xcodebuilds on this workspace corrupt each other. If one is running, surface it to the user instead of racing it.

4. **After successful launch:**
   - Report which env/URL the app is now pointed at (read from `apps/flutter_app/lib/core/config/env_config.dart`)
   - Suggest the next interaction (e.g. "open the app on your phone and try guest login")

## Notes

- This command always uses `fvm flutter`, not plain `flutter`, to honor the `.fvmrc` pin (currently 3.41.9 as of 2026-05-20).
- The Apple Dev team and device/sim UUIDs are baked into the script. If the user changes phones or sims, both `scripts/preflight-ios.sh` and this command need updating.
- See `memory/build-environment-stability.md` for the full background on why these checks exist.
