import AppKit
import LupitaCore
import SwiftUI

/// «Aspecto» (D55): the live sample of the tooltip over a faux backdrop, the picker of sample states, and the four
/// controls. Every control goes through `AppearanceModel`, which saves it; the real tooltip reads it when it opens.
struct AspectoView: View {
    @ObservedObject var model: AppearanceModel
    /// Fixed for the offscreen renders; nil reads the macOS settings.
    var accessibility: ThemeAccessibility? = nil
    @Environment(\.colorScheme) private var colorScheme

    static let stageWidth: CGFloat = 700
    static let stagePad: CGFloat = 28
    static let contentWidth: CGFloat = 740

    var systemAccessibility: ThemeAccessibility {
        accessibility ?? ThemeAccessibility(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                                            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }

    var theme: TooltipTheme { model.sampleTheme(systemIsDark: colorScheme == .dark, accessibility: systemAccessibility) }
    var state: GalleryState { GalleryStates.all.first { $0.id == model.state } ?? GalleryStates.all[0] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AspectoStage(theme: theme, state: state)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                row(S.appearanceSample) {
                    Picker(S.appearanceSample, selection: Binding(get: { model.state }, set: { model.state = $0 })) {
                        ForEach(GalleryStates.all, id: \.id) { Text($0.label).tag($0.id) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
                Divider().gridCellColumns(2)
                row(S.appearanceTheme) {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(S.appearanceTheme, selection: Binding(get: { model.preferences.themeID }, set: model.setTheme)) {
                            ForEach(TooltipTheme.names, id: \.id) { Text($0.name).tag($0.id) }
                        }.labelsHidden().pickerStyle(.menu).fixedSize()
                        Text(model.blurb).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
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
        .frame(width: Self.contentWidth)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            control().frame(maxWidth: .infinity, alignment: .leading)
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
