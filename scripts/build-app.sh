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
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ENTITLEMENTS_PATH="$ROOT_DIR/PasteFormatter.entitlements"
PRIVACY_MANIFEST="$ROOT_DIR/PrivacyInfo.xcprivacy"
ICON_NAME="AppIcon"
ICON_APPICONSET_DIR="$ROOT_DIR/Assets.xcassets/$ICON_NAME.appiconset"
MENU_BAR_ICON_SOURCE_PATH="$ROOT_DIR/Assets/MenuBarIcon.png"
SWIFTPM_RESOURCE_BUNDLE_NAME="paste-formatter_PasteFormatterUI.bundle"

usage() {
  cat <<'EOF'
Build a macOS Paste Formatter app bundle in dist/.

Usage:
  ./scripts/build-app.sh --bundle-identifier <identifier> [options]
  ./scripts/build-app.sh --help

Options:
  --bundle-identifier        Required bundle identifier for the generated app bundle.
  --signing-identity         Optional code signing identity to sign the app bundle.
  --entitlements             Entitlements plist used for code signing.
                             Defaults to PasteFormatter.entitlements.
  --help                     Show this help text.

Examples:
  ./scripts/build-app.sh --bundle-identifier com.example.paste-formatter

  ./scripts/build-app.sh \
    --bundle-identifier dev.nielsmouthaan.paste-formatter \
    --signing-identity "Developer ID Application: Example (TEAMID)"
EOF
}

resolve_sparkle_framework() {
  local framework_path=""

  framework_path="$(find "$ROOT_DIR/.build/artifacts" \
    -path "*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
    -type d 2>/dev/null | head -n 1)"

  if [ -z "$framework_path" ]; then
    framework_path="$(find "$ROOT_DIR/.build" \
      -path "*/Sparkle.framework" \
      -type d \
      ! -path "*/dSYMs/*" 2>/dev/null | head -n 1)"
  fi

  if [ -z "$framework_path" ]; then
    echo "Could not find Sparkle.framework under $ROOT_DIR/.build after building." >&2
    exit 1
  fi

  echo "$framework_path"
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
    --entitlements)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --entitlements" >&2
        usage >&2
        exit 1
      fi
      ENTITLEMENTS_PATH="$2"
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
swift build --package-path "$ROOT_DIR" --configuration release

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$EXECUTABLE_TARGET" -type f ! -path "$ROOT_DIR/.build/apple/*" | head -n 1)"

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"

sed \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

if [ ! -d "$ICON_APPICONSET_DIR" ]; then
  echo "Missing app icon set: $ICON_APPICONSET_DIR" >&2
  exit 1
fi

ICON_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paste-formatter-icon.XXXXXX")"
ICONSET_DIR="$ICON_WORK_DIR/$ICON_NAME.iconset"
mkdir -p "$ICONSET_DIR"

ICON_ENTRIES=(
  "16:16:AppIcon-16x16.png:icon_16x16.png"
  "32:32:AppIcon-16x16@2x.png:icon_16x16@2x.png"
  "32:32:AppIcon-32x32.png:icon_32x32.png"
  "64:64:AppIcon-32x32@2x.png:icon_32x32@2x.png"
  "128:128:AppIcon-128x128.png:icon_128x128.png"
  "256:256:AppIcon-128x128@2x.png:icon_128x128@2x.png"
  "256:256:AppIcon-256x256.png:icon_256x256.png"
  "512:512:AppIcon-256x256@2x.png:icon_256x256.png"
  "512:512:AppIcon-512x512.png:icon_512x512.png"
  "1024:1024:AppIcon-512x512@2x.png:icon_512x512@2x.png"
)

for ICON_ENTRY in "${ICON_ENTRIES[@]}"; do
  IFS=":" read -r EXPECTED_WIDTH EXPECTED_HEIGHT SOURCE_FILENAME ICONSET_FILENAME <<< "$ICON_ENTRY"
  SOURCE_ICON_PATH="$ICON_APPICONSET_DIR/$SOURCE_FILENAME"

  if [ ! -f "$SOURCE_ICON_PATH" ]; then
    echo "Missing app icon image: $SOURCE_ICON_PATH" >&2
    exit 1
  fi

  ICON_WIDTH="$(/usr/bin/sips -g pixelWidth "$SOURCE_ICON_PATH" | awk '/pixelWidth/ { print $2 }')"
  ICON_HEIGHT="$(/usr/bin/sips -g pixelHeight "$SOURCE_ICON_PATH" | awk '/pixelHeight/ { print $2 }')"

  if [ "$ICON_WIDTH" != "$EXPECTED_WIDTH" ] || [ "$ICON_HEIGHT" != "$EXPECTED_HEIGHT" ]; then
    echo "App icon image must be ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}: $SOURCE_ICON_PATH is ${ICON_WIDTH}x${ICON_HEIGHT}" >&2
    exit 1
  fi

  cp "$SOURCE_ICON_PATH" "$ICONSET_DIR/$ICONSET_FILENAME"
done

/usr/bin/iconutil --convert icns --output "$RESOURCES_DIR/$ICON_NAME.icns" "$ICONSET_DIR"
rm -rf "$ICON_WORK_DIR"

if [ ! -f "$MENU_BAR_ICON_SOURCE_PATH" ]; then
  echo "Missing menu bar icon: $MENU_BAR_ICON_SOURCE_PATH" >&2
  exit 1
fi

MENU_BAR_ICON_WIDTH="$(/usr/bin/sips -g pixelWidth "$MENU_BAR_ICON_SOURCE_PATH" | awk '/pixelWidth/ { print $2 }')"
MENU_BAR_ICON_HEIGHT="$(/usr/bin/sips -g pixelHeight "$MENU_BAR_ICON_SOURCE_PATH" | awk '/pixelHeight/ { print $2 }')"

if [ "$MENU_BAR_ICON_WIDTH" != "36" ] || [ "$MENU_BAR_ICON_HEIGHT" != "36" ]; then
  echo "Menu bar icon must be a 36x36 PNG: $MENU_BAR_ICON_SOURCE_PATH is ${MENU_BAR_ICON_WIDTH}x${MENU_BAR_ICON_HEIGHT}" >&2
  exit 1
fi

cp "$MENU_BAR_ICON_SOURCE_PATH" "$RESOURCES_DIR/MenuBarIcon.png"

if [ -f "$PRIVACY_MANIFEST" ]; then
  cp "$PRIVACY_MANIFEST" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
fi

while IFS= read -r RESOURCE_BUNDLE; do
  echo "Copying resources from $(basename "$RESOURCE_BUNDLE")..."
  RESOURCE_BUNDLE_DESTINATION="$RESOURCES_DIR/$(basename "$RESOURCE_BUNDLE")"
  rm -rf "$RESOURCE_BUNDLE_DESTINATION"
  ditto "$RESOURCE_BUNDLE" "$RESOURCE_BUNDLE_DESTINATION"

  for RESOURCE_BUNDLE_INFO_PLIST in \
    "$RESOURCE_BUNDLE_DESTINATION/Contents/Info.plist" \
    "$RESOURCE_BUNDLE_DESTINATION/Info.plist"; do
    if [ ! -f "$RESOURCE_BUNDLE_INFO_PLIST" ]; then
      continue
    fi

    RESOURCE_BUNDLE_EXECUTABLE="$(
      /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$RESOURCE_BUNDLE_INFO_PLIST" 2>/dev/null \
        || true
    )"

    if [ -n "$RESOURCE_BUNDLE_EXECUTABLE" ] \
      && [ ! -f "$RESOURCE_BUNDLE_DESTINATION/Contents/MacOS/$RESOURCE_BUNDLE_EXECUTABLE" ] \
      && [ ! -f "$RESOURCE_BUNDLE_DESTINATION/$RESOURCE_BUNDLE_EXECUTABLE" ]; then
      /usr/libexec/PlistBuddy -c "Delete :CFBundleExecutable" "$RESOURCE_BUNDLE_INFO_PLIST"
    fi
  done
done < <(find "$(dirname "$EXECUTABLE_PATH")" -maxdepth 1 -name "*.bundle" -type d)

SWIFTPM_RESOURCE_BUNDLE_PATH="$RESOURCES_DIR/$SWIFTPM_RESOURCE_BUNDLE_NAME"
if [ ! -d "$SWIFTPM_RESOURCE_BUNDLE_PATH" ]; then
  echo "Missing SwiftPM resource bundle in app resources: $SWIFTPM_RESOURCE_BUNDLE_PATH" >&2
  exit 1
fi

if [ ! -f "$SWIFTPM_RESOURCE_BUNDLE_PATH/OnboardingAppIcon.png" ] \
  && [ ! -f "$SWIFTPM_RESOURCE_BUNDLE_PATH/Contents/Resources/OnboardingAppIcon.png" ]; then
  echo "Missing onboarding icon in SwiftPM resource bundle: $SWIFTPM_RESOURCE_BUNDLE_PATH" >&2
  exit 1
fi

SPARKLE_FRAMEWORK_PATH="$(resolve_sparkle_framework)"
echo "Copying Sparkle.framework..."
ditto "$SPARKLE_FRAMEWORK_PATH" "$FRAMEWORKS_DIR/Sparkle.framework"

chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing Sparkle helper tools with $SIGNING_IDENTITY..."
  SPARKLE_BUNDLE_PATH="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
  SPARKLE_SIGN_PATHS=(
    "$SPARKLE_BUNDLE_PATH/Autoupdate"
    "$SPARKLE_BUNDLE_PATH/XPCServices/Downloader.xpc"
    "$SPARKLE_BUNDLE_PATH/XPCServices/Installer.xpc"
    "$SPARKLE_BUNDLE_PATH/Updater.app"
  )

  for SPARKLE_SIGN_PATH in "${SPARKLE_SIGN_PATHS[@]}"; do
    if [ -e "$SPARKLE_SIGN_PATH" ]; then
      /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$SPARKLE_SIGN_PATH"
    fi
  done

  echo "Signing bundled frameworks with $SIGNING_IDENTITY..."
  while IFS= read -r FRAMEWORK_PATH; do
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$FRAMEWORK_PATH"
  done < <(find "$FRAMEWORKS_DIR" -type d -name "*.framework")

  echo "Signing app bundle with $SIGNING_IDENTITY..."
  CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY" --options runtime --timestamp)

  if [ -f "$ENTITLEMENTS_PATH" ]; then
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS_PATH")
  fi

  /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
  echo "Skipping code signing. Pass --signing-identity to sign the app bundle."
fi

echo "App bundle created:"
echo "$APP_BUNDLE"
