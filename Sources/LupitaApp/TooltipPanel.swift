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
    /// The tooltip's own window number, so a lookup on top of it can read it.
    var windowID: CGWindowID? { panel.map { CGWindowID($0.windowNumber) } }
    /// The answer on screen, if it is a tooltip (not a notice).
    private(set) var resolution: Resolution?

    func show(_ resolution: Resolution, at mouse: NSPoint) {
        defer { self.resolution = resolution }
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
        resolution = nil
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
        if let link = d.openURL, let url = URL(string: link) {
            workspace.open(url)
        } else if d.rule == .repo {
            workspace.open(URL(fileURLWithPath: d.absolutePath))
        } else if d.rule == .commit || d.rule == .branch {
            workspace.activateFileViewerSelecting([URL(fileURLWithPath: d.absolutePath)])
        } else if workspace.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil,
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
        .frame(width: 440, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }

    /// A row opens its file, unless it has none (a dictionary answer: git, an error, an HTML tag).
    @ViewBuilder private func row(_ d: Definition, isFirst: Bool) -> some View {
        if d.absolutePath.isEmpty && d.openURL == nil {
            rowContent(d, isFirst: isFirst)
        } else {
            Button { open(d) } label: { rowContent(d, isFirst: isFirst) }
                .buttonStyle(.plain)
                .help(Self.help(d))
        }
    }

    private func rowContent(_ d: Definition, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // The name on top, what it means below: a long meaning wraps under the name, not beside it.
            VStack(alignment: .leading, spacing: 2) {
                // A term's title is the term itself: showing the ID too would repeat it.
                if d.rule != .term {
                    Text(d.id).font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle)
                }
                if d.rule == .symbol && d.title.isEmpty {
                    Text(S.noComment).font(.body.italic()).foregroundStyle(.secondary)
                } else {
                    Text(d.title).font(.body.weight(.medium)).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let colors = d.colors, !colors.isEmpty {
                HStack(spacing: 10) { ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Swatch(sample: c) } }
            }
            if !d.summary.isEmpty {
                Text(d.summary).font(.callout).foregroundStyle(.secondary).lineLimit(4).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                if let kind = Self.kind(d.rule) {
                    Text(kind).font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
                if !d.repo.isEmpty { Text(d.repo).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor) }
                if let location = Self.location(d) {
                    Text(location).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
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

    static func kind(_ rule: DefinitionRule) -> String? {
        switch rule {
        case .repo: S.kindRepo
        case .commit: S.kindCommit
        case .branch: S.kindBranch
        case .file: S.kindFile
        case .command: S.kindCommand
        case .term: S.kindTerm
        case .symbol: S.kindSymbol
        case .address: S.kindAddress
        case .token: S.kindToken
        case .terminal: S.kindTerminal
        case .error: S.kindError
        case .pullRequest: S.kindPullRequest
        case .tag: S.kindTag
        case .color: S.kindColor
        default: nil
        }
    }

    /// `path:line` under an ID or a file; nothing for commits and branches (the repo says it all).
    static func location(_ d: Definition) -> String? {
        switch d.rule {
        case .repo, .commit, .branch: nil
        case .address: d.path.isEmpty ? nil : d.path
        case .pullRequest: nil
        case .command: d.path
        case .file: d.line > 1 ? "\(d.path):\(d.line)" : d.path
        default: d.path.isEmpty ? nil : "\(d.path):\(d.line)"
        }
    }

    static func help(_ d: Definition) -> String {
        if d.openURL != nil { return S.openOnGitHub }
        if d.rule == .repo { return S.openFolder }
        if d.rule == .commit || d.rule == .branch { return S.showFolder }
        return S.openAt(d.path, line: max(d.line, 1))
    }
}

/// A colour sample (D29): a rounded square with a hairline so white and black stay visible on any tooltip background.
struct Swatch: View {
    let sample: ColorSample

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: sample.hex))
                .frame(width: 28, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.25)))
            Text(sample.label.isEmpty ? sample.hex : "\(sample.label) \(sample.hex)")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }
}

extension Color {
    /// `#RRGGBB` or `#RRGGBBAA`.
    init(hex: String) {
        let digits = hex.dropFirst()
        let v = UInt64(digits, radix: 16) ?? 0
        let hasAlpha = digits.count == 8
        let r = Double((v >> (hasAlpha ? 24 : 16)) & 255) / 255
        let g = Double((v >> (hasAlpha ? 16 : 8)) & 255) / 255
        let b = Double((v >> (hasAlpha ? 8 : 0)) & 255) / 255
        let a = hasAlpha ? Double(v & 255) / 255 : 1
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
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
