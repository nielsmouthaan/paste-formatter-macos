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
ENTITLEMENTS_PATH="$ROOT_DIR/PasteFormatter.entitlements"
PRIVACY_MANIFEST="$ROOT_DIR/PrivacyInfo.xcprivacy"
ICON_NAME="AppIcon"
ICON_APPICONSET_DIR="$ROOT_DIR/Assets.xcassets/$ICON_NAME.appiconset"
MENU_BAR_ICON_SOURCE_PATH="$ROOT_DIR/Assets/MenuBarIcon.png"
SWIFTPM_RESOURCE_BUNDLE_NAME="paste-formatter_PasteFormatterUI.bundle"
NOTARIZATION_ZIP="$DIST_DIR/$APP_NAME-notarization.zip"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_TEMPLATE")"
RELEASE_ZIP="$DIST_DIR/$APP_NAME $MARKETING_VERSION.zip"
APP_STORE_PACKAGE="$DIST_DIR/PasteFormatter-$MARKETING_VERSION-mas.pkg"
APP_STORE_SIGNING_ENTITLEMENTS=""

cleanup() {
  if [ -n "$APP_STORE_SIGNING_ENTITLEMENTS" ]; then
    rm -f "$APP_STORE_SIGNING_ENTITLEMENTS"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Build a macOS Paste Formatter app bundle in dist/, optionally sign it,
notarize it, create a zipped release build, or create a Mac App Store
installer package.

Usage:
  ./scripts/build-app.sh --bundle-identifier <identifier> [options]
  ./scripts/build-app.sh --help

Options:
  --bundle-identifier        Required bundle identifier for the generated app bundle.
  --signing-identity         Optional code signing identity to sign the app bundle.
  --entitlements             Entitlements plist used for code signing.
                             Defaults to PasteFormatter.entitlements.
  --provisioning-profile     Provisioning profile to embed before signing.
                             Required with --app-store-package.
  --notarize                 Submit the signed app to Apple notarization and staple the ticket.
  --release-zip              Create a distributable zip in dist/ after building.
  --app-store-package        Create a Mac App Store installer package in dist/.
  --installer-signing-identity
                             Required with --app-store-package. Use a Mac Installer
                             Distribution identity, commonly named
                             "3rd Party Mac Developer Installer: ...".
  --help                     Show this help text.

Examples:
  ./scripts/build-app.sh --bundle-identifier com.example.paste-formatter

  ./scripts/build-app.sh \
    --bundle-identifier com.example.paste-formatter \
    --signing-identity "Developer ID Application: Example (TEAMID)" \
    --notarize \
    --release-zip

  ./scripts/build-app.sh \
    --bundle-identifier com.example.paste-formatter \
    --signing-identity "3rd Party Mac Developer Application: Example (TEAMID)" \
    --installer-signing-identity "3rd Party Mac Developer Installer: Example (TEAMID)" \
    --provisioning-profile "Paste Formatter.provisionprofile" \
    --app-store-package
EOF
}

BUNDLE_IDENTIFIER=""
SIGNING_IDENTITY=""
INSTALLER_SIGNING_IDENTITY=""
PROVISIONING_PROFILE=""
NOTARIZE=false
CREATE_RELEASE_ZIP=false
CREATE_APP_STORE_PACKAGE=false

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
    --installer-signing-identity)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --installer-signing-identity" >&2
        usage >&2
        exit 1
      fi
      INSTALLER_SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --provisioning-profile)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --provisioning-profile" >&2
        usage >&2
        exit 1
      fi
      PROVISIONING_PROFILE="$2"
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
    --app-store-package)
      CREATE_APP_STORE_PACKAGE=true
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

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Missing required --signing-identity argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ -z "$INSTALLER_SIGNING_IDENTITY" ]; then
    echo "Missing required --installer-signing-identity argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ -z "$PROVISIONING_PROFILE" ]; then
    echo "Missing required --provisioning-profile argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ "$NOTARIZE" = true ]; then
    echo "--notarize is for Developer ID distribution and cannot be combined with --app-store-package" >&2
    exit 1
  fi

  if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "Missing entitlements file for --app-store-package: $ENTITLEMENTS_PATH" >&2
    exit 1
  fi
fi

if [ -n "$PROVISIONING_PROFILE" ] && [ ! -f "$PROVISIONING_PROFILE" ]; then
  echo "Provisioning profile not found: $PROVISIONING_PROFILE" >&2
  exit 1
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  PROFILE_PLIST="$(mktemp "${TMPDIR:-/tmp}/paste-formatter-profile.XXXXXX.plist")"
  if ! /usr/bin/openssl smime -inform der -verify -noverify -in "$PROVISIONING_PROFILE" -out "$PROFILE_PLIST" >/dev/null 2>&1; then
    rm -f "$PROFILE_PLIST"
    echo "Could not decode provisioning profile: $PROVISIONING_PROFILE" >&2
    exit 1
  fi

  PROFILE_APP_IDENTIFIER="$(
    /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$PROFILE_PLIST" 2>/dev/null \
      || true
  )"

  PROFILE_TEAM_IDENTIFIER="$(
    /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" "$PROFILE_PLIST" 2>/dev/null \
      || true
  )"

  PROFILE_BUNDLE_IDENTIFIER="${PROFILE_APP_IDENTIFIER#*.}"
  if [ -z "$PROFILE_APP_IDENTIFIER" ] || [ "$PROFILE_BUNDLE_IDENTIFIER" != "$BUNDLE_IDENTIFIER" ]; then
    rm -f "$PROFILE_PLIST"
    echo "Provisioning profile does not match bundle identifier $BUNDLE_IDENTIFIER." >&2
    echo "Profile application identifier: ${PROFILE_APP_IDENTIFIER:-unknown}" >&2
    exit 1
  fi

  APP_STORE_SIGNING_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/paste-formatter-entitlements.XXXXXX.plist")"
  cp "$ENTITLEMENTS_PATH" "$APP_STORE_SIGNING_ENTITLEMENTS"

  /usr/libexec/PlistBuddy -c "Delete :com.apple.application-identifier" "$APP_STORE_SIGNING_ENTITLEMENTS" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $PROFILE_APP_IDENTIFIER" "$APP_STORE_SIGNING_ENTITLEMENTS"

  if [ -n "$PROFILE_TEAM_IDENTIFIER" ]; then
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.team-identifier" "$APP_STORE_SIGNING_ENTITLEMENTS" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $PROFILE_TEAM_IDENTIFIER" "$APP_STORE_SIGNING_ENTITLEMENTS"
  fi

  PROFILE_KEYCHAIN_GROUP_COUNT="$(/usr/bin/plutil -extract "Entitlements.keychain-access-groups" raw -o - "$PROFILE_PLIST" 2>/dev/null || true)"
  if [[ "$PROFILE_KEYCHAIN_GROUP_COUNT" =~ ^[0-9]+$ ]]; then
    /usr/libexec/PlistBuddy -c "Delete :keychain-access-groups" "$APP_STORE_SIGNING_ENTITLEMENTS" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :keychain-access-groups array" "$APP_STORE_SIGNING_ENTITLEMENTS"

    for ((INDEX = 0; INDEX < PROFILE_KEYCHAIN_GROUP_COUNT; INDEX++)); do
      PROFILE_KEYCHAIN_GROUP="$(/usr/bin/plutil -extract "Entitlements.keychain-access-groups.$INDEX" raw -o - "$PROFILE_PLIST")"
      /usr/libexec/PlistBuddy -c "Add :keychain-access-groups:$INDEX string $PROFILE_KEYCHAIN_GROUP" "$APP_STORE_SIGNING_ENTITLEMENTS"
    done
  fi

  rm -f "$PROFILE_PLIST"
fi

echo "Building release executable..."
if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  xcodebuildmcp swift-package build \
    --package-path "$ROOT_DIR" \
    --configuration release \
    --architectures arm64 x86_64
else
  xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  EXECUTABLE_PATH="$ROOT_DIR/.build/apple/Products/Release/$EXECUTABLE_TARGET"
else
  EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$EXECUTABLE_TARGET" -type f ! -path "$ROOT_DIR/.build/apple/*" | head -n 1)"
fi

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
  "512:512:AppIcon-256x256@2x.png:icon_256x256@2x.png"
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

if [ -n "$PROVISIONING_PROFILE" ]; then
  cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
fi

chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  BINARY_ARCHITECTURES="$(/usr/bin/lipo -archs "$MACOS_DIR/$EXECUTABLE_NAME")"
  if [[ " $BINARY_ARCHITECTURES " != *" arm64 "* ]] || [[ " $BINARY_ARCHITECTURES " != *" x86_64 "* ]]; then
    echo "Mac App Store package builds must include arm64 and x86_64. Found: $BINARY_ARCHITECTURES" >&2
    exit 1
  fi

  echo "Verified universal app binary architectures: $BINARY_ARCHITECTURES"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing app bundle with $SIGNING_IDENTITY..."
  CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")
  CODESIGN_ENTITLEMENTS_PATH="$ENTITLEMENTS_PATH"

  if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
    CODESIGN_ENTITLEMENTS_PATH="$APP_STORE_SIGNING_ENTITLEMENTS"
  fi

  if [ -f "$CODESIGN_ENTITLEMENTS_PATH" ]; then
    CODESIGN_ARGS+=(--entitlements "$CODESIGN_ENTITLEMENTS_PATH")
  fi

  if [ "$CREATE_APP_STORE_PACKAGE" = false ]; then
    CODESIGN_ARGS+=(--options runtime --timestamp)
  fi

  /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

  if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
    SIGNED_ENTITLEMENTS_PLIST="$(mktemp "${TMPDIR:-/tmp}/paste-formatter-signed-entitlements.XXXXXX.plist")"
    /usr/bin/codesign -d --entitlements :- "$APP_BUNDLE" > "$SIGNED_ENTITLEMENTS_PLIST" 2>/dev/null
    SIGNED_APP_IDENTIFIER="$(
      /usr/libexec/PlistBuddy -c "Print :com.apple.application-identifier" "$SIGNED_ENTITLEMENTS_PLIST" 2>/dev/null \
        || true
    )"
    rm -f "$SIGNED_ENTITLEMENTS_PLIST"

    if [ "$SIGNED_APP_IDENTIFIER" != "$PROFILE_APP_IDENTIFIER" ]; then
      echo "Signed app entitlements do not match provisioning profile." >&2
      echo "Signed application identifier: ${SIGNED_APP_IDENTIFIER:-unknown}" >&2
      echo "Profile application identifier: $PROFILE_APP_IDENTIFIER" >&2
      exit 1
    fi

    echo "Verified signed application identifier: $SIGNED_APP_IDENTIFIER"
  fi
else
  echo "Skipping code signing. Pass --signing-identity to sign the app bundle."
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  echo "Creating Mac App Store package at $APP_STORE_PACKAGE..."
  rm -f "$APP_STORE_PACKAGE"
  productbuild \
    --sign "$INSTALLER_SIGNING_IDENTITY" \
    --component "$APP_BUNDLE" /Applications \
    "$APP_STORE_PACKAGE"
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

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  echo "Mac App Store package created:"
  echo "$APP_STORE_PACKAGE"
fi
