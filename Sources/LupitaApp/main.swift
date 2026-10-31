import AppKit
import SwiftUI

// Development aid: draw tooltips to PNG files and exit (see TooltipGallery).
if let i = CommandLine.arguments.firstIndex(of: "--render-tooltips") {
    let code = MainActor.assumeIsolated { TooltipGallery.run(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}

// Development aid: every theme × light/dark × the ten states of the design system, drawn with the real views.
if let i = CommandLine.arguments.firstIndex(of: "--render-themes") {
    let code = MainActor.assumeIsolated { ThemeGallery.run(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}

// Development aid: the «Aspecto» window drawn to PNG for every theme, mode, size and density, and the end-to-end check.
if let i = CommandLine.arguments.firstIndex(of: "--render-appearance") {
    let code = MainActor.assumeIsolated { AspectoGallery.run(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}
if let i = CommandLine.arguments.firstIndex(of: "--selftest-appearance") {
    let code = MainActor.assumeIsolated { AspectoGallery.selftest(Array(CommandLine.arguments.dropFirst(i + 1))) }
    exit(code)
}
// Development aid: open the real Aspecto window, save a picture of it after 3 s and quit.
if let i = CommandLine.arguments.firstIndex(of: "--show-appearance") {
    MainActor.assumeIsolated { AspectoGallery.show(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(0)
}

// Development aid: the contact sheet of the git vocabulary cards and the menu switch (D42).
if let i = CommandLine.arguments.firstIndex(of: "--render-vocabulary") {
    let code = MainActor.assumeIsolated { TooltipGallery.runVocabulary(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

// Development aid: the card of a tracker key in its three states, next to two that already worked.
if let i = CommandLine.arguments.firstIndex(of: "--render-tracker-states") {
    let code = MainActor.assumeIsolated { TrackerSheet.run(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

// Development aid: the underline of IDs (solid) and terms (dashed) drawn to PNG.
if let i = CommandLine.arguments.firstIndex(of: "--render-underline") {
    let code = MainActor.assumeIsolated { TooltipGallery.runUnderline(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

// Development aid: the menu drawn to PNG with the folders in the current settings (D44).
if let i = CommandLine.arguments.firstIndex(of: "--render-menu") {
    let code = MainActor.assumeIsolated { TooltipGallery.runMenu(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

// Development aid: where a notice lands for a mouse at x,y (Cocoa points), to check it sits next to the cursor.
if let i = CommandLine.arguments.firstIndex(of: "--probe-notice") {
    let code = MainActor.assumeIsolated { () -> Int32 in
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let parts = (CommandLine.arguments.dropFirst(i + 1).first ?? "600,500").split(separator: ",").compactMap { Double($0) }
        let mouse = NSPoint(x: parts.first ?? 600, y: parts.last ?? 500)
        let panel = TooltipPanel()
        panel.showNotice("Lupita no encuentra nada para «ZX9» en tus repos.", at: mouse)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        guard let f = panel.frame, let w = panel.windowFrame else { return 1 }
        print("mouse \(mouse)\nvisible \(f)\nwindow \(w)\ngap right \(f.minX - mouse.x) · gap below \(mouse.y - f.maxY)")
        return 0
    }
    exit(code)
}

// Development aid: measure the code-box detector on a real window (see WindowDiagnostic).
if let i = CommandLine.arguments.firstIndex(of: "--diagnose-window") {
    exit(WindowDiagnostic.run(Array(CommandLine.arguments.dropFirst(i + 1))))
}

// Development aid: install a release from a local feed without alerts (see Updater).
if let i = CommandLine.arguments.firstIndex(of: "--update-from") {
    let code = MainActor.assumeIsolated { Updater.runUpdateFrom(CommandLine.arguments.dropFirst(i + 1).first) }
    exit(code)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
