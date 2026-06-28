#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LookAway"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
SDK="$(xcrun --show-sdk-path)"

# Detect Apple Silicon vs Intel
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  TARGET="arm64-apple-macosx14.0"
else
  TARGET="x86_64-apple-macosx14.0"
fi

echo "Building $APP_NAME for $TARGET ..."

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

swiftc \
  -o "$MACOS_DIR/$APP_NAME" \
  -target "$TARGET" \
  -sdk "$SDK" \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine \
  -framework CoreAudio \
  -framework CoreGraphics \
  -framework UserNotifications \
  -framework ServiceManagement \
  "$ROOT/LookAway/LookAwayApp.swift" \
  "$ROOT/LookAway/Models/Config.swift" \
  "$ROOT/LookAway/Models/BreakStats.swift" \
  "$ROOT/LookAway/Services/ConfigManager.swift" \
  "$ROOT/LookAway/Services/TimerEngine.swift" \
  "$ROOT/LookAway/Services/MicrophoneMonitor.swift" \
  "$ROOT/LookAway/Services/SleepWakeMonitor.swift" \
  "$ROOT/LookAway/Services/IdleMonitor.swift" \
  "$ROOT/LookAway/Services/MenuBarWindowDismisser.swift" \
  "$ROOT/LookAway/Services/BreakInputShield.swift" \
  "$ROOT/LookAway/Services/LaunchAtLoginManager.swift" \
  "$ROOT/LookAway/Views/MenuBarView.swift" \
  "$ROOT/LookAway/Views/MenuControls.swift" \
  "$ROOT/LookAway/Views/LookAwayDesign.swift" \
  "$ROOT/LookAway/Views/GlassStyles.swift" \
  "$ROOT/LookAway/Views/NativeGlassBridge.swift" \
  "$ROOT/LookAway/Views/BreakOverlayView.swift" \
  "$ROOT/LookAway/Controllers/BreakOverlayController.swift"

cp "$ROOT/LookAway/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
ICONSET="$ROOT/LookAway/Resources/AppIcon.iconset"
ICNS="$ROOT/LookAway/Resources/AppIcon.icns"
mkdir -p "$RESOURCES_DIR" "$(dirname "$ICONSET")"
swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$ICNS"
cp "$ICNS" "$RESOURCES_DIR/AppIcon.icns"

# Ensure Info.plist keys match the bundle layout
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier io.github.dvdcarlomagno.lookaway" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Look Away'" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 'Look Away'" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open \"$APP_BUNDLE\""
