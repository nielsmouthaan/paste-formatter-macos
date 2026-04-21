import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?
    private var hotKeyMonitor: HotKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        let pasteboardService = PasteboardService()
        let pasteExecutor = PasteActionExecutor()

        let statusMenuController = StatusMenuController(
            settingsStore: settingsStore,
            pasteboardService: pasteboardService,
            pasteExecutor: pasteExecutor
        )
        statusMenuController.start()
        self.statusMenuController = statusMenuController

        let hotKeyMonitor = HotKeyMonitor {
            statusMenuController.performCleanPaste()
        }
        hotKeyMonitor.start()
        self.hotKeyMonitor = hotKeyMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor?.stop()
    }
}
