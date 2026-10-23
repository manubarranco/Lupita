import LupitaCore
import AppKit
import ApplicationServices

/// The two macOS permissions (D10). Both are needed: Screen Recording powers OCR, the main
/// path in Electron and web apps (D15).
@MainActor
enum Permissions {
    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case screenRecording = "Privacy_ScreenCapture"
    }

    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func open(_ pane: Pane) {
        if pane == .screenRecording { CGRequestScreenCaptureAccess() }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!)
    }

    /// First launch without Accessibility: say what each permission is for, then open Settings.
    static func explainIfNeeded() {
        guard !accessibility else { return }
        let alert = NSAlert()
        alert.messageText = S.permissionsTitle
        alert.informativeText = S.permissionsBody
        alert.addButton(withTitle: S.openAccessibility)
        alert.addButton(withTitle: S.later)
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { open(.accessibility) }
    }
}
