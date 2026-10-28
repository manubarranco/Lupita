import AppKit
import LupitaCore
import SwiftUI

/// «Aspecto» (D55): a carousel of the themes, and under it the reader's other settings. One slide per
/// theme, each with its name and a representative card drawn at the chosen size and density; moving to a slide chooses
/// that theme. Every control goes through `AppearanceModel`, which saves it; the real tooltip reads it when it opens.
struct AspectoView: View {
    @ObservedObject var model: AppearanceModel
    /// Fixed for the offscreen renders; nil reads the macOS settings.
    var accessibility: ThemeAccessibility? = nil
    @Environment(\.colorScheme) private var colorScheme
    // `State` used as a plain type: the `@State` macro plugin is missing without Xcode.
    private let indexState = State(initialValue: 0)
    private let dragState = State(initialValue: CGFloat(0))
    private var index: Int { get { indexState.wrappedValue } nonmutating set { indexState.wrappedValue = newValue } }
    private var drag: CGFloat { get { dragState.wrappedValue } nonmutating set { dragState.wrappedValue = newValue } }

    static let stageWidth: CGFloat = 700
    static let stageHeight: CGFloat = 410
    static let stagePad: CGFloat = 28
    static let contentWidth: CGFloat = 740
    /// The window never changes size: stage, dots, the theme's blurb (two lines) and three controls.
    static let contentHeight: CGFloat = 640
    private static let ids = TooltipTheme.ids

    var systemAccessibility: ThemeAccessibility {
        accessibility ?? ThemeAccessibility(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                                            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }

    /// The theme of a slide: the reader's mode, size and density over that slide's theme.
    func theme(_ id: String) -> TooltipTheme {
        var p = model.preferences
        p.themeID = id
        return p.theme(systemIsDark: colorScheme == .dark, accessibility: systemAccessibility)
    }
    var state: GalleryState { GalleryStates.all.first { $0.id == model.state } ?? GalleryStates.all[0] }

    var body: some View {
        VStack(spacing: 12) {
            stage
            dots
            Text(model.blurb).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .top)
            Divider()
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                row(S.appearanceMode) {
                    Picker(S.appearanceMode, selection: Binding(get: { model.preferences.appearance }, set: model.setAppearance)) {
                        Text(S.modeSystem).tag(ThemePreferences.Appearance.system)
                        Text(S.modeLight).tag(ThemePreferences.Appearance.light)
                        Text(S.modeDark).tag(ThemePreferences.Appearance.dark)
                    }.labelsHidden().pickerStyle(.segmented)
                }
                row(S.appearanceSize) {
                    Picker(S.appearanceSize, selection: Binding(get: { model.preferences.size }, set: model.setSize)) {
                        ForEach(ThemeSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                }
                row(S.appearanceDensity) {
                    Picker(S.appearanceDensity, selection: Binding(get: { model.preferences.density }, set: model.setDensity)) {
                        Text(S.densityCompact).tag(ThemeDensity.compact)
                        Text(S.densityNormal).tag(ThemeDensity.normal)
                        Text(S.densityAiry).tag(ThemeDensity.airy)
                    }.labelsHidden().pickerStyle(.segmented)
                }
            }
        }
        .padding(20)
        .frame(width: Self.contentWidth, height: Self.contentHeight, alignment: .top)
        .onAppear { index = Self.ids.firstIndex(of: model.preferences.themeID) ?? 0 }
        .onChange(of: model.preferences.themeID) { _, id in
            if let i = Self.ids.firstIndex(of: id), i != index { index = i }
        }
    }

    // MARK: The carousel

    private func go(to target: Int, animated: Bool = true) {
        let clamped = min(max(target, 0), Self.ids.count - 1)
        let change = { index = clamped; drag = 0 }
        if animated { withAnimation(.spring(response: 0.4, dampingFraction: 0.86), change) } else { change() }
        model.setTheme(Self.ids[clamped])
    }

    /// A swipe or a drag that ended `dx` points from where it began: past the threshold it turns the page.
    private func finish(_ dx: CGFloat) {
        if dx < -80 { go(to: index + 1) } else if dx > 80 { go(to: index - 1) } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 } }
    }

    private var stage: some View {
        ZStack {
            // Development aid: LUPITA_ASPECTO_BACKDROP=1 puts a faux page behind the cards, to judge a material.
            if ProcessInfo.processInfo.environment["LUPITA_ASPECTO_BACKDROP"] != nil { FauxPage(dark: colorScheme == .dark) }
            HStack(spacing: 0) {
                ForEach(Array(Self.ids.enumerated()), id: \.element) { _, id in
                    AspectoSlide(theme: theme(id), state: state).frame(width: Self.stageWidth, height: Self.stageHeight)
                }
            }
            .frame(width: Self.stageWidth, height: Self.stageHeight, alignment: .leading)
            .offset(x: -CGFloat(index) * Self.stageWidth + drag)
            arrow("chevron.left", S.appearancePrevious, enabled: index > 0, alignment: .leading) { go(to: index - 1) }
            arrow("chevron.right", S.appearanceNext, enabled: index < Self.ids.count - 1, alignment: .trailing) { go(to: index + 1) }
        }
        .frame(width: Self.stageWidth, height: Self.stageHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 6)
            .onChanged { drag = $0.translation.width }
            .onEnded { finish($0.translation.width) })
        .background(CarouselInput(
            onScroll: { dx, ended in
                drag = dx
                if ended { finish(dx) }
            },
            onKey: { key in
                switch key { case .left: go(to: index - 1); case .right: go(to: index + 1) }
            }))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(S.appearanceTheme)
    }

    private func arrow(_ symbol: String, _ label: String, enabled: Bool, alignment: Alignment, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34)
                .background(.regularMaterial, in: Circle()).overlay(Circle().strokeBorder(.separator))
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.25)
        .help(label).accessibilityLabel(label)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private var dots: some View {
        HStack(spacing: 9) {
            ForEach(Array(Self.ids.enumerated()), id: \.element) { i, id in
                let name = TooltipTheme.names.first { $0.id == id }?.name ?? id
                Button { go(to: i) } label: {
                    Circle().fill(i == index ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 8, height: 8).padding(4)
                }
                .buttonStyle(.plain).help(name).accessibilityLabel(name)
            }
        }
        .frame(height: 20)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            control().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One slide: the theme's name over a representative card, centred; scaled down only if a large size would not fit.
private struct AspectoSlide: View {
    let theme: TooltipTheme
    let state: GalleryState
    private let naturalState = State(initialValue: CGSize.zero)
    private var natural: CGSize { get { naturalState.wrappedValue } nonmutating set { naturalState.wrappedValue = newValue } }

    var body: some View {
        let fit = natural.height > 0 ? min(1, (AspectoView.stageHeight - 24) / natural.height) : 1
        VStack(spacing: 16) {
            Text(theme.name).font(.title2.weight(.semibold)).foregroundStyle(.primary)
            state.view(theme).environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
        }
        .background(GeometryReader { geo in Color.clear.onAppear { natural = geo.size }.onChange(of: geo.size) { _, s in natural = s } })
        .scaleEffect(fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Arrow keys and horizontal trackpad swipes over the window, as the carousel's input. A local monitor, because SwiftUI has no
/// two-finger-swipe gesture on macOS. Only events of this window, and (for scrolling) over this view.
private struct CarouselInput: NSViewRepresentable {
    enum Key { case left, right }
    let onScroll: (CGFloat, Bool) -> Void
    let onKey: (Key) -> Void

    func makeNSView(context: Context) -> NSView { Monitor(onScroll: onScroll, onKey: onKey) }
    func updateNSView(_ view: NSView, context: Context) {
        (view as? Monitor)?.onScroll = onScroll
        (view as? Monitor)?.onKey = onKey
    }

    final class Monitor: NSView {
        var onScroll: (CGFloat, Bool) -> Void
        var onKey: (Key) -> Void
        private var token: Any?
        private var accumulated: CGFloat = 0

        init(onScroll: @escaping (CGFloat, Bool) -> Void, onKey: @escaping (Key) -> Void) {
            self.onScroll = onScroll
            self.onKey = onKey
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            if let token { NSEvent.removeMonitor(token); self.token = nil }
            guard window != nil else { return }
            nonisolated(unsafe) let me = self
            token = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak me] event in
                nonisolated(unsafe) let e = event
                let consumed = MainActor.assumeIsolated { me?.handle(e) ?? false }
                return consumed ? nil : event
            }
        }

        /// True when the event was the carousel's and must not go on.
        @MainActor private func handle(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else { return false }
            if event.type == .keyDown {
                switch event.keyCode {
                case 123: onKey(.left); return true
                case 124: onKey(.right); return true
                default: return false
                }
            }
            let point = convert(event.locationInWindow, from: nil)
            guard event.hasPreciseScrollingDeltas, bounds.contains(point) else { return false }
            guard event.momentumPhase == [] else { return true }   // the inertia after the fingers lift must not turn another page
            if event.phase.contains(.began) { accumulated = 0 }
            guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) || accumulated != 0 else { return false }
            accumulated += event.scrollingDeltaX
            let ended = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            onScroll(accumulated, ended)
            if ended { accumulated = 0 }
            return true
        }
    }
}

/// The tooltip (or notice) with its shadow room, over a faux page with a colour band so a material and the shadow can be
/// seen. `backdrop: false` draws the same canvas over nothing, for the shadow-clip measure.
struct AspectoStage: View {
    let theme: TooltipTheme
    let state: GalleryState
    var backdrop = true
    var minHeight: CGFloat = 190

    static func insets(_ theme: TooltipTheme, _ state: GalleryState) -> EdgeInsets {
        theme.insets(of: state.notice != nil ? theme.noticeShadow : theme.containerShadow)
    }

    /// Room between the canvas edge and the tooltip box: at least the pad, and always more than the shadow's reach.
    static func margin(_ inset: CGFloat) -> CGFloat { max(AspectoView.stagePad, inset + 8) }

    var body: some View {
        let ins = Self.insets(theme, state)
        let dark = theme.mode == .dark
        state.view(theme)
            .padding(ins)
            .padding(.leading, Self.margin(ins.leading) - ins.leading)
            .padding(.top, Self.margin(ins.top) - ins.top)
            .padding(.trailing, Self.margin(ins.trailing) - ins.trailing)
            .padding(.bottom, Self.margin(ins.bottom) - ins.bottom)
            .frame(width: AspectoView.stageWidth, alignment: .topLeading)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background {
                if backdrop { FauxPage(dark: dark) }
            }
            .clipShape(RoundedRectangle(cornerRadius: backdrop ? 10 : 0))
            .overlay { if backdrop { RoundedRectangle(cornerRadius: 10).strokeBorder(dark ? Color(white: 0.23) : Color(white: 0.85)) } }
            .environment(\.colorScheme, dark ? .dark : .light)
    }
}

/// Faux text lines and a colour band, as in the contact sheets.
private struct FauxPage: View {
    let dark: Bool
    static let lines: [CGFloat] = [92, 78, 86, 64, 90, 70, 84, 58, 94, 76, 88, 66, 80, 72, 90, 60]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(red: dark ? 0.11 : 0.949, green: dark ? 0.11 : 0.949, blue: dark ? 0.118 : 0.957)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Self.lines.enumerated()), id: \.offset) { i, pct in
                        if i > 0 { Spacer(minLength: 0) }
                        RoundedRectangle(cornerRadius: 4).fill(dark ? Color(white: 0.33) : Color(white: 0.77))
                            .frame(width: (geo.size.width - 40) * pct / 100, height: 7)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                LinearGradient(colors: [Color(red: 0.9, green: 0.28, blue: 0.3), Color(red: 0.96, green: 0.65, blue: 0.14), Color(red: 0.24, green: 0.39, blue: 0.87)],
                               startPoint: .leading, endPoint: .trailing)
                    .opacity(0.85).frame(width: geo.size.width, height: geo.size.height * 0.26).offset(y: geo.size.height * 0.34)
            }
        }
    }
}

/// One window, reused (like the ID report).
@MainActor
final class AspectoWindow {
    private var window: NSWindow?
    private let model = AppearanceModel()

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: AspectoView(model: model))
            host.sizingOptions = [.preferredContentSize]
            let w = NSWindow(contentViewController: host)
            w.title = S.appearanceTitle
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: AspectoView.contentWidth, height: AspectoView.contentHeight))   // before centring: the hosting view sizes itself later
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// For `--show-appearance`: the window's content as an image.
    var snapshot: NSImage? {
        guard let view = window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
