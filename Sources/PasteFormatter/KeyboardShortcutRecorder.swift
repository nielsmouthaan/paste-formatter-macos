import AppKit
import Foundation

@MainActor
final class KeyboardShortcutRecorder {
    private let basePrompt = "Press the shortcut you want to use."

    func recordShortcut(current: KeyboardShortcut) -> KeyboardShortcut? {
        let alert = NSAlert()
        alert.messageText = "Set keyboard shortcut"
        alert.informativeText = ""

        let saveButton = alert.addButton(withTitle: "Save")
        saveButton.isEnabled = false
        alert.addButton(withTitle: "Cancel")

        let promptLabel = NSTextField(labelWithString: basePrompt)
        promptLabel.sizeToFit()
        alert.accessoryView = promptLabel

        var recordedShortcut: KeyboardShortcut?
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let shortcut = KeyboardShortcut(recording: event) else {
                NSSound.beep()
                self.updatePromptLabel(promptLabel, with: "Unsupported shortcut.")
                return nil
            }

            recordedShortcut = shortcut
            self.updatePromptLabel(promptLabel, with: "New shortcut: \(shortcut.displayString)")
            saveButton.isEnabled = true
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

    private func updatePromptLabel(_ label: NSTextField, with text: String) {
        label.stringValue = text
        label.sizeToFit()
        label.window?.layoutIfNeeded()
        label.window?.displayIfNeeded()
    }
}
