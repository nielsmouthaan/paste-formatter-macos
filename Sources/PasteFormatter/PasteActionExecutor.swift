import ApplicationServices
import Carbon.HIToolbox
import Foundation

@MainActor
struct PasteActionExecutor {
    private static var hasPromptedForAccessibility = false

    func executePaste() -> Bool {
        guard AXIsProcessTrusted() else {
            if !Self.hasPromptedForAccessibility {
                let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                Self.hasPromptedForAccessibility = true
            }
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
