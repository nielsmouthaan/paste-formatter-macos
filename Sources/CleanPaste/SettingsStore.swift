import CleanPasteCore
import Foundation

final class SettingsStore {
    private enum Keys {
        static let preserveFont = "preserveFont"
        static let preserveColors = "preserveColors"
        static let preserveLinks = "preserveLinks"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.userDefaults.register(defaults: [
            Keys.preserveFont: false,
            Keys.preserveColors: false,
            Keys.preserveLinks: true
        ])
    }

    var options: PasteFormattingOptions {
        get {
            PasteFormattingOptions(
                preserveFont: userDefaults.bool(forKey: Keys.preserveFont),
                preserveColors: userDefaults.bool(forKey: Keys.preserveColors),
                preserveLinks: userDefaults.bool(forKey: Keys.preserveLinks)
            )
        }
        set {
            userDefaults.set(newValue.preserveFont, forKey: Keys.preserveFont)
            userDefaults.set(newValue.preserveColors, forKey: Keys.preserveColors)
            userDefaults.set(newValue.preserveLinks, forKey: Keys.preserveLinks)
        }
    }
}
