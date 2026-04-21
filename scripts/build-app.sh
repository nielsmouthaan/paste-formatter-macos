#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="CleanPaste"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_TEMPLATE="$ROOT_DIR/AppBundle/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.local.cleanpaste}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUNDLE_VERSION="${BUNDLE_VERSION:-1}"

echo "Building release executable..."
xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$APP_NAME" -type f | head -n 1)"

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

sed \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  -e "s/__MARKETING_VERSION__/$MARKETING_VERSION/g" \
  -e "s/__BUNDLE_VERSION__/$BUNDLE_VERSION/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

chmod 755 "$MACOS_DIR/$APP_NAME"

echo "App bundle created:"
echo "$APP_BUNDLE"
