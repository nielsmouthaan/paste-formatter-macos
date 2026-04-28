import AppKit
import Foundation
import PasteFormatterUI

@MainActor
final class KeyboardShortcutRecorder {
    private let basePrompt = "Press the shortcut you want to use."
    private let isShortcutAvailable: @MainActor (KeyboardShortcut) -> Bool

    init(isShortcutAvailable: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true }) {
        self.isShortcutAvailable = isShortcutAvailable
    }

    func recordShortcut(current: KeyboardShortcut) -> KeyboardShortcut? {
        let alert = NSAlert()
        alert.messageText = "Set Keyboard Shortcut"
        alert.informativeText = ""

        let saveButton = alert.addButton(withTitle: "Save")
        saveButton.isEnabled = false
        alert.addButton(withTitle: "Cancel")

        let promptLabel = NSTextField(labelWithString: basePrompt)
        promptLabel.allowsEditingTextAttributes = true
        promptLabel.sizeToFit()
        alert.accessoryView = promptLabel

        var recordedShortcut: KeyboardShortcut?
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch KeyboardShortcut.recordingResult(for: event) {
            case let .valid(shortcut):
                guard self.isShortcutAvailable(shortcut) else {
                    recordedShortcut = nil
                    saveButton.isEnabled = false
                    NSSound.beep()
                    self.updatePromptLabel(
                        promptLabel,
                        prefix: "Invalid shortcut: ",
                        emphasizedText: shortcut.displayString
                    )
                    return nil
                }

                recordedShortcut = shortcut
                self.updatePromptLabel(
                    promptLabel,
                    prefix: "New shortcut: ",
                    emphasizedText: shortcut.displayString
                )
                saveButton.isEnabled = true
            case let .invalid(displayString):
                recordedShortcut = nil
                saveButton.isEnabled = false
                NSSound.beep()
                self.updatePromptLabel(
                    promptLabel,
                    prefix: "Invalid shortcut: ",
                    emphasizedText: displayString
                )
            }

            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return recordedShortcut
    }

    private func updatePromptLabel(_ label: NSTextField, prefix: String, emphasizedText: String) {
        let attributedString = NSMutableAttributedString(string: prefix)
        attributedString.append(
            NSAttributedString(
                string: emphasizedText,
                attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
            )
        )

        label.attributedStringValue = attributedString
        label.sizeToFit()
        label.window?.layoutIfNeeded()
        label.window?.displayIfNeeded()
    }
}
