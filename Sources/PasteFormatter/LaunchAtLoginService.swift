import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    enum LaunchAtLoginError: LocalizedError {
        case requiresAppBundle
        case underlying(NSError)

        var errorDescription: String? {
            switch self {
            case .requiresAppBundle:
                return "Launch at login only works when Paste Formatter is running from a .app bundle."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    private let appService = SMAppService.mainApp

    var status: SMAppService.Status {
        appService.status
    }

    var isEnabled: Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginError> {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return .failure(.requiresAppBundle)
        }

        do {
            if enabled {
                try appService.register()
            } else {
                try appService.unregister()
            }

            return .success(())
        } catch {
            return .failure(.underlying(error as NSError))
        }
    }
}
