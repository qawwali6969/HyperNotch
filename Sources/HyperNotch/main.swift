import Cocoa

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // Runs as a menu bar / accessory app, no dock icon clutter
    app.run()
}


