#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$APP_DIR/.swift-home" "$APP_DIR/.swiftpm-modulecache" "$APP_DIR/.clang-cache"

export SWIFTPM_MODULECACHE_OVERRIDE="$APP_DIR/.swiftpm-modulecache"
export CLANG_MODULE_CACHE_PATH="$APP_DIR/.clang-cache"
export HOME="${HOME:-$APP_DIR/.swift-home}"

osascript -e 'tell application id "app.retypoair.dev" to quit' >/dev/null 2>&1 || true
pkill -f '/RetypoAir($| )' >/dev/null 2>&1 || true
pkill -f 'swift run.*RetypoAir' >/dev/null 2>&1 || true

cd "$APP_DIR"
swift build -c debug

BIN_DIR="$(swift build -c debug --show-bin-path)"
APP_BUNDLE="$APP_DIR/build-dev/RetypoAir-dev.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>RetypoAir</string>
  <key>CFBundleIdentifier</key>
  <string>app.retypoair.dev</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Retypo Air</string>
  <key>CFBundleDisplayName</key>
  <string>Retypo Air Dev</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.0.1-dev</string>
  <key>CFBundleVersion</key>
  <string>0.0.1-dev</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Retypo Air can import selected text by briefly sending Copy to the focused app.</string>
</dict>
</plist>
PLIST

cp "$BIN_DIR/RetypoAir" "$MACOS_DIR/RetypoAir"
chmod +x "$MACOS_DIR/RetypoAir"

for bundle_path in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle_path" ]] || continue
  cp -R "$bundle_path" "$RESOURCES_DIR/"
done

codesign --force --deep -s - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built: $APP_BUNDLE"
echo "Open it, then grant Accessibility permission to 'Retypo Air Dev' if prompted."

if [[ "${RETYPO_OPEN_APP:-1}" != "0" ]]; then
  open -n "$APP_BUNDLE" --args "$@"
fi
