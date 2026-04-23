#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Paste Formatter.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICON_NAME="AppIcon"
ICON_SOURCE_PATH="$ROOT_DIR/Assets/$ICON_NAME.icns"

usage() {
  cat <<'EOF'
Build a macOS Paste Formatter app bundle in dist/ and optionally sign it.

Usage:
  ./scripts/build-app.sh --bundle-identifier <identifier> [--signing-identity <identity>]
  ./scripts/build-app.sh --help

Options:
  --bundle-identifier  Required bundle identifier for the generated app bundle.
  --signing-identity   Optional code signing identity to sign the app bundle.
  --help               Show this help text.
EOF
}

BUNDLE_IDENTIFIER=""
SIGNING_IDENTITY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle-identifier)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --bundle-identifier" >&2
        usage >&2
        exit 1
      fi
      BUNDLE_IDENTIFIER="$2"
      shift 2
      ;;
    --signing-identity)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --signing-identity" >&2
        usage >&2
        exit 1
      fi
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$BUNDLE_IDENTIFIER" ]; then
  echo "Missing required --bundle-identifier argument" >&2
  usage >&2
  exit 1
fi

echo "Building release executable..."
xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/PasteFormatter" -type f | head -n 1)"

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/Paste Formatter"

sed \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

if [ -f "$ICON_SOURCE_PATH" ]; then
  cp "$ICON_SOURCE_PATH" "$RESOURCES_DIR/$ICON_NAME.icns"
fi

chmod 755 "$MACOS_DIR/Paste Formatter"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing app bundle with $SIGNING_IDENTITY..."
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --timestamp=none "$MACOS_DIR/Paste Formatter"
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --timestamp=none "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
else
  echo "Skipping code signing. Pass --signing-identity to sign the app bundle."
fi

echo "App bundle created:"
echo "$APP_BUNDLE"
