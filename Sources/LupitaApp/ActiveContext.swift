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
        // 3. A window that says no file (a chat app): the repo its texts name most (`Entorno LiOS`, the chat's title).
        if context.repo == nil { context.repo = resolver.repoMostNamed(in: texts(of: window)) }
        return context
    }

    /// Texts of a window's elements, a bounded walk: at most `maxElements` and `budget` seconds, so a long chat stays cheap.
    static let maxElements = 1500
    static let budget: TimeInterval = 0.04

    private static func texts(of window: AXUIElement) -> [String] {
        let started = Date()
        var queue = [window], out: [String] = [], seen = 0
        while !queue.isEmpty, seen < maxElements, Date().timeIntervalSince(started) < budget {
            let element = queue.removeFirst()
            seen += 1
            for name in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
                if let text: String = TextUnderCursor.attribute(element, name), !text.isEmpty { out.append(String(text.prefix(2000))) }
            }
            if let children: [AXUIElement] = TextUnderCursor.attribute(element, kAXChildrenAttribute) { queue += children }
        }
        return out
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
