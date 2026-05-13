import Foundation
import OSLog
import Sparkle

@MainActor
final class UpdateController {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.nielsmouthaan.paste-formatter",
        category: "UpdateController"
    )
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func start() {
        do {
            try updaterController.updater.start()
        } catch {
            logger.error("Failed to start Sparkle updater: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
