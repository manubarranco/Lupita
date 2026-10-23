import AppKit
import ApplicationServices
import LupitaCore

/// Which repo (and file) the user is looking at, from the window under the cursor (D8, D12).
@MainActor
struct ActiveContext {
    var bundleID: String?
    var repo: String?
    /// Path relative to `repo`, when the window says which file it shows.
    var path: String?

    static func at(_ point: CGPoint, resolver: Resolver) -> ActiveContext {
        var context = ActiveContext()
        guard let window = windowUnderCursor(point) else { return context }
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        context.bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier

        // 1. The window's document (editors set it): exact repo and path.
        if let document: String = TextUnderCursor.attribute(window, kAXDocumentAttribute),
           let url = URL(string: document), url.isFileURL,
           let repo = resolver.index.repos.first(where: { url.path.hasPrefix($0.path + "/") }) {
            context.repo = repo.name
            context.path = String(url.path.dropFirst(repo.path.count + 1))
            return context
        }
        // 2. A repo named in the title: "CLAUDE.md — atlas — Visual Studio Code", "atlas — -zsh".
        if let title: String = TextUnderCursor.attribute(window, kAXTitleAttribute) {
            context.repo = resolver.repoNamed(in: title)
        }
        return context
    }

    private static func windowUnderCursor(_ point: CGPoint) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
              let element else { return nil }
        if let window: AXUIElement = TextUnderCursor.attribute(element, kAXWindowAttribute) { return window }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return TextUnderCursor.attribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute)
    }
}
