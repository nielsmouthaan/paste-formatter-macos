# Changelog

## 0.1.0

- macOS menu bar app built in Swift with `LSUIElement` behavior for a Dockless utility experience
- `Paste` action in the menu with a configurable global keyboard shortcut
- Clipboard cleaning pipeline for RTF, HTML, and plain-text clipboard contents
- Formatting controls for preserving or removing fonts, colors, and links
- Plain-text paste can preserve paragraph breaks by converting rich-text paragraph spacing into empty lines
- Plain-text paste keeps consecutive rich-text list items compact by ignoring extra paragraph expansion within the same `textLists` group
- Plain-text output normalizes rich-text line separators like `U+2028` to standard newlines
- Automatic paste now restores the original clipboard after a short delay so repeated pastes still use the original copied content
- Menu options for `Launch at login` and keyboard shortcut configuration
- Menu option for `Preserve paragraph breaks in plain text`, enabled by default
- Menu includes `About Paste Formatter` linking to the GitHub repository and `Quit Paste Formatter`
- Keyboard shortcut configuration uses a single change action with live shortcut preview and no required modifiers
- Keyboard shortcut recorder shows the captured shortcut directly in the dialog while recording
- Keyboard shortcut recorder keeps the prompt text while showing the captured shortcut preview
- Keyboard shortcut preview is rendered inline in the dialog text instead of a separate accessory view
- Keyboard shortcut prompt and recorded shortcut now render reliably in one multiline dialog label
- Keyboard shortcut dialog no longer forces a fixed-width prompt label
- Keyboard shortcut dialog now recalculates its inline prompt label so the recorded shortcut stays visible
- Keyboard shortcut dialog now uses a single simple status line that switches between prompt, new shortcut, and short error text
- Accessibility permission alert copy is simplified
- Internal app references are aligned to `Paste Formatter` and the bundle identifier is `nl.nielsmouthaan.paste-formatter`
- App bundle is now signed with the configured Apple Developer identity instead of ad-hoc signing
- Accessibility prompt requests are limited to one prompt per app launch while permission is missing
- Remaining source and test paths are aligned to `PasteFormatter` naming
- Build script is generic for open source use, with optional signing and neutral default identifiers
- App bundle now includes a configurable `.icns` app icon resource when provided
- Default behavior that removes source fonts and colors while preserving links
- Preservation of paragraph styles during rich-text cleanup
- Automatic paste execution via simulated `Command + V` after clipboard cleanup
- `UserDefaults` persistence for menu toggle state between launches
- App is presented to users as `Paste Formatter`
- SwiftPM-based `.app` bundle build script that creates `dist/Paste Formatter.app`
- Core formatting tests covering font/color stripping, link preservation, and optional link removal
