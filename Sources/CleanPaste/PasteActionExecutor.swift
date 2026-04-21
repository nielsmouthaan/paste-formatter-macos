import ApplicationServices
import Carbon.HIToolbox
import Foundation

@MainActor
struct PasteActionExecutor {
    func executePaste() -> Bool {
        guard AXIsProcessTrusted() else {
            let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
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
