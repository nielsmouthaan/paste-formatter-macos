#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="${APP_NAME:-Paste Formatter}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-PasteFormatter}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICON_NAME="${ICON_NAME:-AppIcon}"
ICON_SOURCE_PATH="${ICON_SOURCE_PATH:-$ROOT_DIR/Assets/$ICON_NAME.icns}"

BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.example.paste-formatter}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUNDLE_VERSION="${BUNDLE_VERSION:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

echo "Building release executable..."
xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$EXECUTABLE_NAME" -type f | head -n 1)"

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

sed \
  -e "s/__APP_EXECUTABLE__/$APP_NAME/g" \
  -e "s/__APP_NAME__/$APP_NAME/g" \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  -e "s/__APP_ICON_FILE__/$ICON_NAME/g" \
  -e "s/__MARKETING_VERSION__/$MARKETING_VERSION/g" \
  -e "s/__BUNDLE_VERSION__/$BUNDLE_VERSION/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

if [ -f "$ICON_SOURCE_PATH" ]; then
  cp "$ICON_SOURCE_PATH" "$RESOURCES_DIR/$ICON_NAME.icns"
fi

chmod 755 "$MACOS_DIR/$APP_NAME"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing app bundle with $SIGNING_IDENTITY..."
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --timestamp=none "$MACOS_DIR/$APP_NAME"
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --timestamp=none "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
else
  echo "Skipping code signing. Set SIGNING_IDENTITY to sign the app bundle."
fi

echo "App bundle created:"
echo "$APP_BUNDLE"
