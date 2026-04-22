# Paste Formatter 0.1.0

Minimal macOS menu bar app for pasting cleaned rich text:

- removes fonts unless `Preserve font` is enabled
- removes foreground/background colors unless `Preserve colors` is enabled
- preserves links by default
- preserves paragraph breaks in plain text by default when the source uses paragraph spacing
  while keeping consecutive rich-text list items compact
- keeps paragraph styles intact
- restores the original clipboard shortly after a successful automatic paste so repeated pastes still start from the original copied content

## Run

```bash
swift run PasteFormatter
```

## Build A `.app`

```bash
./scripts/build-app.sh
```

This creates a launchable bundle at `dist/Paste Formatter.app`.

Optional overrides:

```bash
APP_NAME="Paste Formatter" \
EXECUTABLE_NAME=PasteFormatter \
BUNDLE_IDENTIFIER=com.example.paste-formatter \
MARKETING_VERSION=0.1.0 \
BUNDLE_VERSION=1 \
./scripts/build-app.sh
```

To sign the app bundle, also provide a signing identity:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
BUNDLE_IDENTIFIER=com.example.paste-formatter \
./scripts/build-app.sh
```

If `Assets/AppIcon.icns` exists, the build script copies it into the app bundle automatically. You can override that path with `ICON_SOURCE_PATH` or change the resource name with `ICON_NAME`.

The app appears in the menu bar with:

- `Paste` using a configurable global keyboard shortcut
- toggles for font, colors, and links
- a toggle for `Preserve paragraph breaks in plain text`
- `Launch at login` as a menu toggle for app bundle installs
- `Change keyboard shortcut…` to record any supported shortcut
- `About Paste Formatter` to open the GitHub project page
- persisted settings through `UserDefaults`

## Accessibility

Automatic pasting is done by simulating `Command + V`, so macOS will ask for Accessibility permission the first time the app tries to paste automatically. If permission is missing, Paste Formatter still leaves the cleaned content on the clipboard so you can paste manually.

After a successful automatic paste, Paste Formatter restores the original clipboard about one second later. This keeps repeated pastes anchored to what you originally copied instead of to Paste Formatter's temporary transformed clipboard content.

## Notes

- The build script is generic by default and skips signing unless `SIGNING_IDENTITY` is provided.
- The build script picks up `Assets/AppIcon.icns` automatically when present.
- `LSUIElement` is enabled, so the app launches as a menu bar utility without a Dock icon.
- `Launch at login` uses `SMAppService`, which requires the app to run from a signed `.app` bundle before macOS will fully accept it.
