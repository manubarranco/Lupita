import AppKit

// Development aid: draw tooltips to PNG files and exit (see TooltipGallery).
if let i = CommandLine.arguments.firstIndex(of: "--render-tooltips") {
    let code = MainActor.assumeIsolated { TooltipGallery.run(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}

// Development aid: the contact sheet of the git vocabulary cards and the menu switch (D42).
if let i = CommandLine.arguments.firstIndex(of: "--render-vocabulary") {
    let code = MainActor.assumeIsolated { TooltipGallery.runVocabulary(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

// Development aid: measure the code-box detector on a real window (see WindowDiagnostic).
if let i = CommandLine.arguments.firstIndex(of: "--diagnose-window") {
    exit(WindowDiagnostic.run(Array(CommandLine.arguments.dropFirst(i + 1))))
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
