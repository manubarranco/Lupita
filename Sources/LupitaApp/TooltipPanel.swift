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
    var frame: NSRect? {
        guard let f = panel?.frame else { return nil }
        let i = shadowInsets
        return NSRect(x: f.minX + i.left, y: f.minY + i.bottom, width: f.width - i.left - i.right, height: f.height - i.top - i.bottom)
    }
    /// The whole panel, margin included (dev aid).
    var windowFrame: NSRect? { panel?.frame }
    /// The room the shadow takes around the visible box; the panel is the box plus this.
    private var shadowInsets = NSEdgeInsets()
    /// The tooltip's own window number, so a lookup on top of it can read it.
    var windowID: CGWindowID? { panel.map { CGWindowID($0.windowNumber) } }
    /// The answer on screen, if it is a tooltip (not a notice).
    private(set) var resolution: Resolution?

    func show(_ resolution: Resolution, at mouse: NSPoint) {
        defer { self.resolution = resolution }
        // The theme is read when the tooltip opens, so a change in Aspecto shows the next time.
        let theme = TooltipStyle.current()
        present(TooltipView(resolution: resolution, theme: theme, open: { [weak self] d in
            self?.close()
            FileOpener.open(d)
        }), insets: theme.insets(of: theme.containerShadow), at: mouse, autoDismiss: nil)
    }

    /// Closes on its own only through `close(after:)` or `close()`, or a click or Esc.
    func showNotice(_ text: String, at mouse: NSPoint) {
        let theme = TooltipStyle.current()
        present(NoticeView(text: text, theme: theme), insets: theme.insets(of: theme.noticeShadow), at: mouse, autoDismiss: nil)
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

    /// `insets` is the room the shadow needs: the panel is the visible box plus that margin (it draws no shadow of its own).
    private func present<V: View>(_ view: V, insets: EdgeInsets, at mouse: NSPoint, autoDismiss: TimeInterval?) {
        close()
        let host = FirstClickHostingView(rootView: view.padding(insets))
        let size = host.fittingSize
        host.sizingOptions = []   // the panel keeps the size measured here; the hosting view must not resize its window
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.contentView = host
        panel.setContentSize(size)   // the hosting view may have grown the window by itself: the panel is exactly the fitting size
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        shadowInsets = NSEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
        panel.setFrameOrigin(origin(for: size, insets: insets, near: mouse))
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

    /// Below-right of the cursor, kept inside the screen. The visible box (the panel minus the shadow margin) goes where
    /// it always went; the panel is placed so that its margin hangs around the box.
    private func origin(for size: NSSize, insets: EdgeInsets, near mouse: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .infinite
        let box = NSSize(width: size.width - insets.leading - insets.trailing, height: size.height - insets.top - insets.bottom)
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - 18 - box.height)
        if origin.x + box.width > bounds.maxX { origin.x = bounds.maxX - box.width - 8 }
        if origin.y < bounds.minY { origin.y = mouse.y + 18 }
        return NSPoint(x: origin.x - insets.leading, y: origin.y - insets.bottom)
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
    let theme: TooltipTheme
    let open: (Definition) -> Void
    /// The row drawn as hovered from the start (the galleries have no pointer).
    var previewHover: Int? = nil

    var body: some View {
        if let list = resolution.range {
            rangeBody(list)
        } else {
            definitionsBody
        }
    }

    /// A range of IDs (D41): a header, one compact line per ID, repo and file once at the bottom.
    private func rangeBody(_ list: RangeList) -> some View {
        VStack(alignment: .leading, spacing: theme.space.rangeGap) {
            Text(S.rangeHeader(list.count, noun: list.noun)).themed(.eyebrow, theme)
            VStack(alignment: .leading, spacing: theme.space.rangeLineGap) {
                ForEach(Array(list.rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .more(let n): Text(S.rangeMore(n)).themed(.description, theme)
                    case .entry(let e): rangeLine(e)
                    }
                }
            }
            if list.sharedRepo != nil || list.sharedPath != nil {
                HStack(spacing: theme.space.inlineGap) {
                    if let repo = list.sharedRepo { Text(repo).themed(.repo, theme) }
                    if let path = list.sharedPath { Text(path).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle) }
                }
            }
        }
        .padding(theme.space.padding)
        .frame(width: theme.width, alignment: .leading)
        .themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)
    }

    @ViewBuilder private func rangeLine(_ e: RangeList.Entry) -> some View {
        if let d = e.definition {
            Button { open(d) } label: {
                HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {
                    Text(e.id).themed(.id, theme)
                    Text(d.title).themed(.title, theme).lineLimit(theme.limits.rangeTitleLines).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.help(d))
        } else {
            HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {
                Text(e.id).themed(.id, theme)
                Text(S.notDefined).themed(.placeholder, theme)
            }
        }
    }

    private var definitionsBody: some View {
        VStack(alignment: .leading, spacing: theme.space.blockGap) {
            if resolution.isSuggestion {
                Text(S.didYouMean(resolution.key ?? "", read: resolution.query)).themed(.eyebrow, theme)
            } else if resolution.kind == .ambiguous {
                Text(S.unclearReading(resolution.query)).themed(.eyebrow, theme)
            }
            ForEach(Array(resolution.definitions.prefix(theme.limits.maxRows).enumerated()), id: \.offset) { i, d in
                row(d, index: i)
                    .opacity(resolution.isSuggestion ? theme.suggestionOpacity : 1)
            }
            if resolution.definitions.count > theme.limits.maxRows {
                Text(S.moreDefinitions(resolution.definitions.count - theme.limits.maxRows)).themed(.footnote, theme)
            }
            if let m = resolution.mentions, m.count > 0 {
                Text(S.cited(m.count, files: m.files.count)).themed(.footnote, theme)
            }
        }
        .padding(theme.space.padding)
        .frame(width: theme.width, alignment: .leading)
        .themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)
    }

    /// A row opens its file, unless it has none (a dictionary answer: git, an error, an HTML tag).
    @ViewBuilder private func row(_ d: Definition, index: Int) -> some View {
        if d.absolutePath.isEmpty && d.openURL == nil {
            rowContent(d, isFirst: index == 0)
        } else {
            Button { open(d) } label: { rowContent(d, isFirst: index == 0) }
                .buttonStyle(.plain)
                .modifier(HoverBand(theme: theme, startsHovered: previewHover == index))
                .help(Self.help(d))
        }
    }

    private func rowContent(_ d: Definition, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: theme.space.rowGap) {
            // The name on top, what it means below: a long meaning wraps under the name, not beside it.
            VStack(alignment: .leading, spacing: theme.space.nameGap) {
                // A term's title is the term itself: showing the ID too would repeat it.
                if d.rule != .term {
                    Text(d.id).themed(.id, theme)
                        .lineLimit(theme.limits.idLines).truncationMode(.middle)
                }
                if d.rule == .symbol && d.title.isEmpty {
                    Text(S.noComment).themed(.placeholder, theme)
                } else {
                    Text(d.title).themed(.title, theme).lineLimit(theme.limits.titleLines).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let colors = d.colors, !colors.isEmpty {
                HStack(spacing: theme.space.swatchGap) { ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Swatch(sample: c, theme: theme) } }
            }
            if !d.summary.isEmpty {
                Text(d.summary).themed(.description, theme).lineLimit(theme.limits.descriptionLines).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: theme.space.inlineGap) {
                if let kind = Self.kind(d.rule) {
                    badge(kind, fg: theme.colors.badgeFg, bg: theme.colors.badgeBg)
                }
                if !d.repo.isEmpty { Text(d.repo).themed(.repo, theme) }
                if let location = Self.location(d) {
                    Text(location).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle)
                }
                if isFirst && resolution.fromOtherRepo {
                    badge(S.fromAnotherRepo, fg: theme.colors.originFg, bg: theme.colors.originBg)
                }
            }
            .padding(.top, theme.space.metaGap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func badge(_ text: String, fg: RGBA, bg: RGBA) -> some View {
        Text(text).themed(.badge, theme).foregroundStyle(Color(rgba: fg))
            .padding(.horizontal, theme.space.badgeX).padding(.vertical, theme.space.badgeY)
            .background(Color(rgba: bg), in: theme.shape(theme.radius.badge))
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
        case .vocabulary: S.kindGit
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

/// The band behind a row under the pointer. The row is padded and pulled back by the same margin, so nothing moves.
struct HoverBand: ViewModifier {
    let theme: TooltipTheme
    // `State` used as a plain type: the `@State` macro plugin is missing without Xcode.
    private let hovered: State<Bool>
    init(theme: TooltipTheme, startsHovered: Bool = false) {
        self.theme = theme
        hovered = State(initialValue: startsHovered)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, theme.space.rowPadX).padding(.vertical, theme.space.rowPadY)
            .background(hovered.wrappedValue ? Color(rgba: theme.colors.rowHover) : Color.clear, in: theme.shape(theme.radius.row))
            .padding(.horizontal, -theme.space.rowPadX).padding(.vertical, -theme.space.rowPadY)
            .onHover { hovered.wrappedValue = $0 }
    }
}

/// A colour sample (D29): a rounded square with a hairline so white and black stay visible on any tooltip background.
struct Swatch: View {
    let sample: ColorSample
    let theme: TooltipTheme

    var body: some View {
        HStack(spacing: theme.space.swatchInnerGap) {
            theme.shape(theme.radius.swatch)
                .fill(Color(hex: sample.hex))
                .frame(width: theme.swatchSize, height: theme.swatchSize)
                .overlay(theme.shape(theme.radius.swatch).strokeBorder(Color(rgba: theme.colors.swatchBorder), lineWidth: theme.border.swatch))
            Text(sample.label.isEmpty ? sample.hex : "\(sample.label) \(sample.hex)").themed(.swatch, theme)
        }
    }
}

struct NoticeView: View {
    let text: String
    let theme: TooltipTheme
    var body: some View {
        Text(text).themed(.notice, theme)
            .padding(.horizontal, theme.space.noticeX).padding(.vertical, theme.space.noticeY)
            .frame(maxWidth: theme.width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .themedSurface(theme, fill: theme.colors.noticeSurface, radius: theme.radius.notice, borderWidth: theme.border.notice, shadow: theme.noticeShadow)
    }
}
