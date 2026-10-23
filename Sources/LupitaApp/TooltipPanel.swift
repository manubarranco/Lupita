import AppKit
import SwiftUI
import LupitaCore

/// Floating, non-activating panel next to the cursor. Esc or a click elsewhere closes it.
@MainActor
final class TooltipPanel {
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var dismissTask: Task<Void, Never>?
    /// Called when a shown tooltip or notice goes away, whatever closed it.
    var onClose: (() -> Void)?
    /// Where the tooltip or notice is on screen, while it is shown.
    var frame: NSRect? { panel?.frame }

    func show(_ resolution: Resolution, at mouse: NSPoint) {
        present(TooltipView(resolution: resolution, open: { [weak self] d in
            self?.close()
            FileOpener.open(d)
        }), at: mouse, autoDismiss: nil)
    }

    /// Closes on its own only through `close(after:)` or `close()`, or a click or Esc.
    func showNotice(_ text: String, at mouse: NSPoint) {
        present(NoticeView(text: text), at: mouse, autoDismiss: nil)
    }

    func close(after seconds: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { self?.close() }
        }
    }

    func close() {
        dismissTask?.cancel()
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        onClose?()
    }

    private func present<V: View>(_ view: V, at mouse: NSPoint, autoDismiss: TimeInterval?) {
        close()
        let host = FirstClickHostingView(rootView: view)
        let size = host.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameOrigin(origin(for: size, near: mouse))
        panel.orderFrontRegardless()
        self.panel = panel

        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { self?.close(); return nil }
            return event
        }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            MainActor.assumeIsolated {
                if event.type != .keyDown || event.keyCode == 53 { self?.close() }
            }
        }) { monitors.append(global) }
        if let autoDismiss {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(autoDismiss))
                if !Task.isCancelled { self?.close() }
            }
        }
    }

    /// Below-right of the cursor, kept inside the screen.
    private func origin(for size: NSSize, near mouse: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .infinite
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - 18 - size.height)
        if origin.x + size.width > bounds.maxX { origin.x = bounds.maxX - size.width - 8 }
        if origin.y < bounds.minY { origin.y = mouse.y + 18 }
        return origin
    }
}

/// A click on a non-key panel must act on the first click, not just focus it.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

enum FileOpener {
    /// Opens the file at the line: in VS Code when installed, otherwise the default app.
    @MainActor static func open(_ d: Definition) {
        let workspace = NSWorkspace.shared
        if workspace.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil,
           let path = d.absolutePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "vscode://file\(path):\(max(d.line, 1))") {
            workspace.open(url)
        } else {
            workspace.open(URL(fileURLWithPath: d.absolutePath))
        }
    }
}

// MARK: - Views

struct TooltipView: View {
    let resolution: Resolution
    let open: (Definition) -> Void
    static let maxRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if resolution.isSuggestion {
                Text(S.didYouMean(resolution.key ?? "", read: resolution.query))
                    .font(.caption).foregroundStyle(.secondary)
            } else if resolution.kind == .ambiguous {
                Text(S.unclearReading(resolution.query))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(resolution.definitions.prefix(Self.maxRows).enumerated()), id: \.offset) { i, d in
                row(d, isFirst: i == 0)
                    .opacity(resolution.isSuggestion ? 0.75 : 1)
            }
            if resolution.definitions.count > Self.maxRows {
                Text(S.moreDefinitions(resolution.definitions.count - Self.maxRows))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let m = resolution.mentions, m.count > 0 {
                Text(S.cited(m.count, files: m.files.count))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 380, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }

    private func row(_ d: Definition, isFirst: Bool) -> some View {
        Button { open(d) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(d.id).font(.system(.body, design: .monospaced).weight(.semibold))
                    Text(d.title).font(.body.weight(.medium)).lineLimit(2)
                }
                if !d.summary.isEmpty {
                    Text(d.summary).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                }
                HStack(spacing: 6) {
                    Text(d.repo).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                    Text("\(d.path):\(d.line)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    if isFirst && resolution.fromOtherRepo {
                        Text(S.fromAnotherRepo).font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(S.openAt(d.path, line: d.line))
    }
}

struct NoticeView: View {
    let text: String
    var body: some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
