import AppKit

@main
struct PasteFormatterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
