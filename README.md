# CleanPaste 0.1.0

Minimal macOS menu bar app for pasting cleaned rich text:

- removes fonts unless `Preserve font` is enabled
- removes foreground/background colors unless `Preserve colors` is enabled
- preserves links by default
- keeps paragraph styles intact

## Run

```bash
swift run CleanPaste
```

## Build A `.app`

```bash
./scripts/build-app.sh
```

This creates a launchable bundle at `dist/CleanPaste.app`.

Optional overrides:

```bash
BUNDLE_IDENTIFIER=com.yourcompany.CleanPaste MARKETING_VERSION=0.1.0 BUNDLE_VERSION=1 ./scripts/build-app.sh
```

The app appears in the menu bar with:

- `Paste` using the fixed shortcut `Control + Option + Command + V`
- toggles for font, colors, and links
- persisted settings through `UserDefaults`

## Accessibility

Automatic pasting is done by simulating `Command + V`, so macOS will ask for Accessibility permission the first time the app tries to paste automatically. If permission is missing, CleanPaste still leaves the cleaned content on the clipboard so you can paste manually.

## Notes

- The generated `.app` is currently unsigned and not notarized.
- `LSUIElement` is enabled, so the app launches as a menu bar utility without a Dock icon.
