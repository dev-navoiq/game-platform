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
   /Users/ambar/Documents/game-platform/scripts/preflight-ios.sh <target> <env>
   ```
   The script kills stale processes, verifies LAN IP / cert / symlink / device availability, and tests simulator destination resolution.

2. **If pre-flight exited non-zero:** print the script's last few lines verbatim and STOP. Do not attempt `flutter run`. The script's error message is the actionable item — don't try to second-guess or auto-fix.

3. **If pre-flight passed, launch flutter:**
   - For `device`: use **release mode** (AOT, no debug-attach — works around the Xcode 26.4.1 Apple-Events debug-session timeout). Hot reload is unavailable but app runs reliably.
     ```
     cd /Users/ambar/Documents/game-platform/apps/flutter_app && fvm flutter run --release -d 00008150-00141D4C0C61401C --dart-define=ENV=<env>
     ```
   - For `sim`: use **debug mode** (hot reload works). Note that sim is currently affected by the Xcode 26.4.1 CoreSimulator regression — if pre-flight didn't catch it, the run will fail with "Unable to find a destination matching id=...". Fall back to device.
     ```
     cd /Users/ambar/Documents/game-platform/apps/flutter_app && fvm flutter run -d 93B3CE12-584D-4F1D-8C42-C1F94C109893 --dart-define=ENV=<env>
     ```
   - Launch in background using Bash with `run_in_background=true` and pipe output to `/tmp/flutter-launch.log`. Watch the log via a background Bash with an `until grep` loop, exit on "Flutter run key commands" (ready) OR any error pattern. Notify the user when ready or with the error context.

4. **After successful launch:**
   - Report which env/URL the app is now pointed at (read from `apps/flutter_app/lib/core/config/env_config.dart`)
   - Suggest the next interaction (e.g. "open the app on your phone and try guest login")

## Notes

- This command always uses `fvm flutter`, not plain `flutter`, to honor the `.fvmrc` pin (currently 3.41.9 as of 2026-05-20).
- The Apple Dev team and device/sim UUIDs are baked into the script. If the user changes phones or sims, both `scripts/preflight-ios.sh` and this command need updating.
- See `memory/build-environment-stability.md` for the full background on why these checks exist.
