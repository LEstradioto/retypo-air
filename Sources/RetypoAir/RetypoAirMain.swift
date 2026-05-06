import AppKit

@main
enum RetypoAirMain {
    @MainActor
    static func main() {
        _ = DotEnvLoader.load()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
