import AppKit
import CleanPasteCore
import Foundation

@MainActor
final class StatusMenuController: NSObject {
    private let settingsStore: SettingsStore
    private let pasteboardService: PasteboardService
    private let pasteExecutor: PasteActionExecutor

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private lazy var pasteItem: NSMenuItem = {
        let item = NSMenuItem(title: "Paste", action: #selector(handlePasteMenuItem), keyEquivalent: "v")
        item.keyEquivalentModifierMask = [.control, .option, .command]
        item.target = self
        return item
    }()

    private lazy var preserveFontItem = makeToggleItem(
        title: "Preserve font",
        action: #selector(togglePreserveFont)
    )

    private lazy var preserveColorsItem = makeToggleItem(
        title: "Preserve colors",
        action: #selector(togglePreserveColors)
    )

    private lazy var preserveLinksItem = makeToggleItem(
        title: "Preserve links",
        action: #selector(togglePreserveLinks)
    )

    init(
        settingsStore: SettingsStore,
        pasteboardService: PasteboardService,
        pasteExecutor: PasteActionExecutor
    ) {
        self.settingsStore = settingsStore
        self.pasteboardService = pasteboardService
        self.pasteExecutor = pasteExecutor
    }

    func start() {
        configureStatusItem()
        configureMenu()
        refreshMenuState()
    }

    func performCleanPaste() {
        guard let payload = pasteboardService.readCurrentContents() else {
            NSSound.beep()
            presentAlert(
                title: "Nothing to paste",
                message: "CleanPaste only handles plain text, RTF, and HTML clipboard content."
            )
            return
        }

        let didWriteClipboard: Bool
        switch payload {
        case .attributed(let attributedString):
            let cleaned = RichTextCleaner.clean(attributedString, options: settingsStore.options)
            didWriteClipboard = pasteboardService.write(.attributed(cleaned))
        case .plainText(let string):
            didWriteClipboard = pasteboardService.write(.plainText(string))
        }

        guard didWriteClipboard else {
            NSSound.beep()
            presentAlert(
                title: "Paste failed",
                message: "CleanPaste could not write the transformed content back to the clipboard."
            )
            return
        }

        Task { @MainActor [weak self, pasteExecutor] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self else {
                return
            }

            if !pasteExecutor.executePaste() {
                self.presentAlert(
                    title: "Accessibility permission required",
                    message: "CleanPaste needs Accessibility access to send Command-V automatically. The cleaned content is already on the clipboard, so you can paste manually after granting permission in System Settings."
                )
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clean Paste") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "Paste"
        }

        button.toolTip = "Clean Paste"
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.addItem(pasteItem)
        menu.addItem(.separator())
        menu.addItem(preserveFontItem)
        menu.addItem(preserveColorsItem)
        menu.addItem(preserveLinksItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshMenuState() {
        let options = settingsStore.options
        preserveFontItem.state = options.preserveFont ? .on : .off
        preserveColorsItem.state = options.preserveColors ? .on : .off
        preserveLinksItem.state = options.preserveLinks ? .on : .off
    }

    private func makeToggleItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func updateOptions(_ mutate: (inout PasteFormattingOptions) -> Void) {
        var options = settingsStore.options
        mutate(&options)
        settingsStore.options = options
        refreshMenuState()
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func handlePasteMenuItem() {
        performCleanPaste()
    }

    @objc private func togglePreserveFont() {
        updateOptions { options in
            options.preserveFont.toggle()
        }
    }

    @objc private func togglePreserveColors() {
        updateOptions { options in
            options.preserveColors.toggle()
        }
    }

    @objc private func togglePreserveLinks() {
        updateOptions { options in
            options.preserveLinks.toggle()
        }
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
