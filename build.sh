#!/usr/bin/env bash
# Builds build/MenuClip.app.
#
#   ./build.sh              Apple Silicon (arm64), the default
#   ./build.sh universal    Apple Silicon + Intel (needs full Xcode, not just the Command Line Tools)
#
# Needs the Xcode Command Line Tools: xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MenuClip"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

case "${1:-arm64}" in
  arm64) ARCH_FLAGS=(--arch arm64) ;;
  universal) ARCH_FLAGS=(--arch arm64 --arch x86_64) ;;
  *) echo "usage: $0 [arm64|universal]" >&2; exit 1 ;;
esac

swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swift Scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Ad-hoc signature: enough to run on your own Mac.
codesign --force --sign - "$APP"

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"
echo "Install with: cp -R $APP /Applications/"
