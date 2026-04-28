import AppKit
import ApplicationServices
import Foundation

@MainActor
enum AccessibilityPermissionController {
    private static var didRequestSystemPrompt = false
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func openSettings() {
        requestSystemPromptIfNeeded()
        NSWorkspace.shared.open(settingsURL)
    }

    private static func requestSystemPromptIfNeeded() {
        guard !isTrusted, !didRequestSystemPrompt else {
            return
        }

        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        didRequestSystemPrompt = true
    }
}
