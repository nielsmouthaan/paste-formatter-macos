import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?
    private var hotKeyMonitor: HotKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        let pasteboardService = PasteboardService()
        let pasteExecutor = PasteActionExecutor()
        let launchAtLoginService = LaunchAtLoginService()

        var statusMenuController: StatusMenuController?
        let hotKeyMonitor = HotKeyMonitor {
            statusMenuController?.performFormattedPaste()
        }

        let controller = StatusMenuController(
            settingsStore: settingsStore,
            pasteboardService: pasteboardService,
            pasteExecutor: pasteExecutor,
            launchAtLoginService: launchAtLoginService,
            applyShortcut: { shortcut in
                hotKeyMonitor.updateShortcut(shortcut)
            }
        )
        controller.start()
        statusMenuController = controller
        self.statusMenuController = controller

        hotKeyMonitor.start(with: settingsStore.keyboardShortcut)
        self.hotKeyMonitor = hotKeyMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor?.stop()
    }
}
