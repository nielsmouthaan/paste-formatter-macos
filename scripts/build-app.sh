#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Paste Formatter"
EXECUTABLE_TARGET="PasteFormatter"
EXECUTABLE_NAME="Paste Formatter"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICON_NAME="AppIcon"
ICON_SOURCE_PATH="$ROOT_DIR/Assets/$ICON_NAME.icns"
NOTARIZATION_ZIP="$DIST_DIR/$APP_NAME-notarization.zip"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_TEMPLATE")"
RELEASE_ZIP="$DIST_DIR/$APP_NAME $MARKETING_VERSION.zip"

usage() {
  cat <<'EOF'
Build a macOS Paste Formatter app bundle in dist/, optionally sign it,
notarize it, and create a zip for distribution via GitHub Releases.

Usage:
  ./scripts/build-app.sh --bundle-identifier <identifier> [options]
  ./scripts/build-app.sh --help

Options:
  --bundle-identifier  Required bundle identifier for the generated app bundle.
  --signing-identity   Optional code signing identity to sign the app bundle.
  --notarize           Submit the signed app to Apple notarization and staple the ticket.
  --release-zip        Create a distributable zip in dist/ after building.
  --help               Show this help text.

Examples:
  ./scripts/build-app.sh --bundle-identifier com.example.paste-formatter

  ./scripts/build-app.sh \
    --bundle-identifier com.example.paste-formatter \
    --signing-identity "Developer ID Application: Example (TEAMID)" \
    --notarize \
    --release-zip
EOF
}

BUNDLE_IDENTIFIER=""
SIGNING_IDENTITY=""
NOTARIZE=false
CREATE_RELEASE_ZIP=false

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
    --notarize)
      NOTARIZE=true
      shift
      ;;
    --release-zip)
      CREATE_RELEASE_ZIP=true
      shift
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

if [ "$NOTARIZE" = true ] && [ -z "$SIGNING_IDENTITY" ]; then
  echo "Missing required --signing-identity argument for --notarize" >&2
  usage >&2
  exit 1
fi

echo "Building release executable..."
xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$EXECUTABLE_TARGET" -type f | head -n 1)"

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"

sed \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

if [ -f "$ICON_SOURCE_PATH" ]; then
  cp "$ICON_SOURCE_PATH" "$RESOURCES_DIR/$ICON_NAME.icns"
fi

chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing app bundle with $SIGNING_IDENTITY..."
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --options runtime --timestamp "$MACOS_DIR/$EXECUTABLE_NAME"
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" --options runtime --timestamp "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
  echo "Skipping code signing. Pass --signing-identity to sign the app bundle."
fi

if [ "$NOTARIZE" = true ]; then
  if ! command -v asc >/dev/null 2>&1; then
    echo "The asc CLI is required for notarization. Install and authenticate asc before using --notarize." >&2
    exit 1
  fi

  echo "Creating notarization zip at $NOTARIZATION_ZIP..."
  rm -f "$NOTARIZATION_ZIP"
  ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

  echo "Submitting app for notarization..."
  asc notarization submit --file "$NOTARIZATION_ZIP" --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose "$APP_BUNDLE"

  rm -f "$NOTARIZATION_ZIP"
fi

if [ "$CREATE_RELEASE_ZIP" = true ]; then
  echo "Creating release zip at $RELEASE_ZIP..."
  rm -f "$RELEASE_ZIP"
  ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_ZIP"
fi

echo "App bundle created:"
echo "$APP_BUNDLE"

if [ "$CREATE_RELEASE_ZIP" = true ]; then
  echo "Release zip created:"
  echo "$RELEASE_ZIP"
fi
