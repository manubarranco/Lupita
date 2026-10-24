import AppKit

// Development aid: draw tooltips to PNG files and exit (see TooltipGallery).
if let i = CommandLine.arguments.firstIndex(of: "--render-tooltips") {
    let code = MainActor.assumeIsolated { TooltipGallery.run(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
