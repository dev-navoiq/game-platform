#!/usr/bin/env bash
# Tile the master branding PNGs into per-platform icon + splash assets.
#
# Inputs (must exist):
#   apps/flutter_app/assets/branding/icon_source.png       1024x1024
#   apps/flutter_app/assets/branding/icon_foreground.png   1024x1024 transparent
#   apps/flutter_app/assets/branding/splash_logo.png       1024x512
#
# Re-run any time those source PNGs change. Uses macOS `sips`, no pub-get.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/flutter_app"
SRC_ICON="$APP/assets/branding/icon_source.png"
SRC_FG="$APP/assets/branding/icon_foreground.png"
SRC_SPLASH="$APP/assets/branding/splash_logo.png"

for f in "$SRC_ICON" "$SRC_FG" "$SRC_SPLASH"; do
  [[ -f "$f" ]] || { echo "missing: $f"; exit 1; }
done

ios_resize() {
  local size_px="$1"
  local out="$2"
  sips -s format png -z "$size_px" "$size_px" "$SRC_ICON" --out "$out" > /dev/null
}

# ─── iOS app icon ──────────────────────────────────────────────────────────────
IOS_ICONS="$APP/ios/Runner/Assets.xcassets/AppIcon.appiconset"
echo "iOS icons → $IOS_ICONS"
ios_resize 40   "$IOS_ICONS/Icon-App-20x20@2x.png"
ios_resize 60   "$IOS_ICONS/Icon-App-20x20@3x.png"
ios_resize 29   "$IOS_ICONS/Icon-App-29x29@1x.png"
ios_resize 58   "$IOS_ICONS/Icon-App-29x29@2x.png"
ios_resize 87   "$IOS_ICONS/Icon-App-29x29@3x.png"
ios_resize 80   "$IOS_ICONS/Icon-App-40x40@2x.png"
ios_resize 120  "$IOS_ICONS/Icon-App-40x40@3x.png"
ios_resize 120  "$IOS_ICONS/Icon-App-60x60@2x.png"
ios_resize 180  "$IOS_ICONS/Icon-App-60x60@3x.png"
ios_resize 20   "$IOS_ICONS/Icon-App-20x20@1x.png"
ios_resize 76   "$IOS_ICONS/Icon-App-76x76@1x.png"
ios_resize 152  "$IOS_ICONS/Icon-App-76x76@2x.png"
ios_resize 167  "$IOS_ICONS/Icon-App-83.5x83.5@2x.png"
ios_resize 40   "$IOS_ICONS/Icon-App-40x40@1x.png"
ios_resize 1024 "$IOS_ICONS/Icon-App-1024x1024@1x.png"

# App Store marketing icon must NOT have alpha. Flatten via sips.
sips -s format png -s formatOptions normal "$IOS_ICONS/Icon-App-1024x1024@1x.png" \
  --out "$IOS_ICONS/Icon-App-1024x1024@1x.png" > /dev/null

# ─── Android app icon ──────────────────────────────────────────────────────────
ANDROID_RES="$APP/android/app/src/main/res"
echo "Android icons → $ANDROID_RES/mipmap-*/"
android_resize() {
  local size_px="$1"
  local out_dir="$ANDROID_RES/$2"
  mkdir -p "$out_dir"
  sips -s format png -z "$size_px" "$size_px" "$SRC_ICON" \
    --out "$out_dir/ic_launcher.png" > /dev/null
}
android_resize 48  mipmap-mdpi
android_resize 72  mipmap-hdpi
android_resize 96  mipmap-xhdpi
android_resize 144 mipmap-xxhdpi
android_resize 192 mipmap-xxxhdpi

# Android adaptive icon (foreground is transparent, background is solid felt)
android_fg_resize() {
  local size_px="$1"
  local out_dir="$ANDROID_RES/$2"
  mkdir -p "$out_dir"
  sips -s format png -z "$size_px" "$size_px" "$SRC_FG" \
    --out "$out_dir/ic_launcher_foreground.png" > /dev/null
}
android_fg_resize 108 mipmap-mdpi
android_fg_resize 162 mipmap-hdpi
android_fg_resize 216 mipmap-xhdpi
android_fg_resize 324 mipmap-xxhdpi
android_fg_resize 432 mipmap-xxxhdpi

# Adaptive icon XML descriptor + background color
ADAPTIVE_DIR="$ANDROID_RES/mipmap-anydpi-v26"
mkdir -p "$ADAPTIVE_DIR"
cat > "$ADAPTIVE_DIR/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

VALUES_DIR="$ANDROID_RES/values"
mkdir -p "$VALUES_DIR"
COLORS_FILE="$VALUES_DIR/colors.xml"
if [[ -f "$COLORS_FILE" ]]; then
  # only add the entry if it doesn't already exist
  if ! grep -q "ic_launcher_background" "$COLORS_FILE"; then
    # insert before </resources>
    /usr/bin/sed -i '' 's|</resources>|    <color name="ic_launcher_background">#122e1d</color>\n</resources>|' "$COLORS_FILE"
  fi
else
  cat > "$COLORS_FILE" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#122e1d</color>
</resources>
EOF
fi

# ─── iOS splash (LaunchImage) ──────────────────────────────────────────────────
LAUNCH_IMG="$APP/ios/Runner/Assets.xcassets/LaunchImage.imageset"
echo "iOS splash → $LAUNCH_IMG"
sips -s format png -z 256 512  "$SRC_SPLASH" --out "$LAUNCH_IMG/LaunchImage.png"     > /dev/null
sips -s format png -z 512 1024 "$SRC_SPLASH" --out "$LAUNCH_IMG/LaunchImage@2x.png"  > /dev/null
sips -s format png -z 768 1536 "$SRC_SPLASH" --out "$LAUNCH_IMG/LaunchImage@3x.png"  > /dev/null

# ─── Android splash (drawable) ─────────────────────────────────────────────────
echo "Android splash → $ANDROID_RES/drawable*/"
sips -s format png -z 512 1024 "$SRC_SPLASH" --out "$ANDROID_RES/drawable/launch_image.png"     > /dev/null
sips -s format png -z 512 1024 "$SRC_SPLASH" --out "$ANDROID_RES/drawable-v21/launch_image.png" > /dev/null

echo "Done."
