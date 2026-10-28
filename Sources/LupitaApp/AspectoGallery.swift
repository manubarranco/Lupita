import AppKit
import LupitaCore
import SwiftUI

/// Development aids for the «Aspecto» window: `--render-appearance <dir>`, `--selftest-appearance <dir>`, `--show-appearance <png>`.
@MainActor
enum AspectoGallery {
    static let sizes = ThemeSize.allCases
    static let densities: [(ThemeDensity, String)] = [(.compact, "compacta"), (.normal, "normal"), (.airy, "amplia")]
    static let modes: [(ThemePreferences.Appearance, String)] = [(.light, "claro"), (.dark, "oscuro")]

    static func isolatedDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "lupita-aspecto-render-\(UUID().uuidString)")!
        return d
    }

    static var noAccessibility: ThemeAccessibility { ThemeAccessibility() }

    static func model(theme: String, mode: ThemePreferences.Appearance, size: ThemeSize, density: ThemeDensity, state: String = "definition") -> AppearanceModel {
        let m = AppearanceModel(defaults: isolatedDefaults(), state: state)
        m.setTheme(theme); m.setAppearance(mode); m.setSize(size); m.setDensity(density)
        return m
    }

    static func scheme(_ mode: ThemePreferences.Appearance) -> ColorScheme { mode == .dark ? .dark : .light }

    // MARK: Drawing

    static func cgImage<V: View>(_ view: V, scale: CGFloat, opaque: Bool = true) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.cgImage
    }

    static func writePNG(_ image: CGImage?, to path: String) {
        guard let image, let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    /// The window's content drawn with AppKit itself (`ImageRenderer` cannot draw the native pickers): the view in an
    /// offscreen window, never shown, captured at 2x.
    static func windowImage(_ m: AppearanceModel) -> CGImage? {
        let host = NSHostingView(rootView: windowContent(m))
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: m.preferences.appearance == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let scale = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep.cgImage
    }

    /// The window's content, as the window shows it.
    static func windowContent(_ m: AppearanceModel) -> some View {
        AspectoView(model: m, accessibility: noAccessibility)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme(m.preferences.appearance))
    }

    static func raw(_ image: CGImage) -> Data? { image.dataProvider?.data as Data? }

    // MARK: --render-appearance

    static func run(_ args: [String]) -> Int32 {
        guard let dir = args.first else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-appearance <dir>\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        S.language = "es"
        guard let state = GalleryStates.all.first(where: { $0.id == "definition" }) else { return 1 }
        var entries: [[String: Any]] = []
        var shadowViolations = 0, textViolations = 0, count = 0
        for id in TooltipTheme.ids {
            for (mode, modeName) in modes {
                for size in sizes {
                    for (density, densityName) in densities {
                        let m = model(theme: id, mode: mode, size: size, density: density)
                        let theme = m.sampleTheme(systemIsDark: false, accessibility: noAccessibility)
                        let r = ThemeGallery.measure(theme, state)
                        // The sample canvas alone over nothing: any visible pixel on its edge is a shadow the canvas would cut.
                        let canvas = AspectoStage(theme: theme, state: state, backdrop: false)
                        let canvasSize = NSHostingView(rootView: canvas).fittingSize
                        let edge = cgImage(canvas, scale: 2, opaque: false).map(ThemeGallery.edgePixels) ?? -1
                        let name = "aspecto-\(id)-\(modeName)-\(size.rawValue)-\(densityName).png"
                        writePNG(windowImage(m), to: dir + "/" + name)
                        count += 1
                        let shadowBad = r.shadowClipPixels != 0 || edge != 0
                        let textBad = r.widthOverflow > 0.5 || r.heightOverflow > 0.5
                        shadowViolations += shadowBad ? 1 : 0
                        textViolations += textBad ? 1 : 0
                        entries.append(["file": name, "theme": id, "mode": modeName, "size": size.rawValue, "density": densityName, "state": state.id,
                                        "sample": [canvasSize.width, canvasSize.height], "tooltip": [r.box.width, r.box.height],
                                        "tokenWidth": theme.width, "shadowInsets": [r.insets.top, r.insets.leading, r.insets.bottom, r.insets.trailing],
                                        "shadowClipPixels": r.shadowClipPixels, "canvasEdgePixels": edge,
                                        "widthOverflow": r.widthOverflow, "heightOverflow": r.heightOverflow])
                    }
                }
            }
        }
        for (mode, modeName) in modes {
            sheet(dir + "/aspecto-tamaños-\(modeName).png", mode: mode, title: "Aspecto · tamaños · \(modeName) · densidad normal",
                  columns: sizes.map { ($0.rawValue, $0, ThemeDensity.normal) })
            sheet(dir + "/aspecto-densidad-\(modeName).png", mode: mode, title: "Aspecto · densidad · \(modeName) · tamaño M",
                  columns: densities.map { ($0.1, ThemeSize.m, $0.0) })
        }
        let report: [String: Any] = ["captures": count, "shadowClipViolations": shadowViolations, "textClipViolations": textViolations,
                                     "note": "sample: size of the sample canvas (pt); shadowClipPixels: non-transparent pixels on the edge of the panel (tooltip + shadow insets, +8 pt margin) and canvasEdgePixels: on the edge of the sample canvas, both drawn over nothing; widthOverflow/heightOverflow: points the content's ideal size exceeds the width of the token / the height under that width.",
                                     "results": entries]
        if let json = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? json.write(to: URL(fileURLWithPath: dir + "/appearance-report.json"))
        }
        print("captures: \(count) · shadow violations: \(shadowViolations) · text violations: \(textViolations)")
        return shadowViolations + textViolations == 0 ? 0 : 3
    }

    /// Rows = the seven themes, columns as given, each cell the sample canvas (real tooltip over the faux page).
    private static func sheet(_ path: String, mode: ThemePreferences.Appearance, title: String, columns: [(String, ThemeSize, ThemeDensity)]) {
        guard let state = GalleryStates.all.first(where: { $0.id == "definition" }) else { return }
        var rows: [(String, [TooltipTheme], CGFloat)] = []
        for (id, name) in TooltipTheme.names {
            let themes = columns.map { model(theme: id, mode: mode, size: $0.1, density: $0.2).sampleTheme(systemIsDark: false, accessibility: noAccessibility) }
            let height = themes.map { NSHostingView(rootView: AspectoStage(theme: $0, state: state)).fittingSize.height }.max() ?? 190
            rows.append((name, themes, height))
        }
        let dark = mode == .dark
        let view = VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 26, weight: .semibold))
            HStack(spacing: 16) {
                Color.clear.frame(width: 110, height: 1)
                ForEach(columns.map(\.0), id: \.self) { Text($0).font(.system(size: 14, weight: .semibold)).frame(width: AspectoView.stageWidth, alignment: .leading) }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 16) {
                    Text(row.0).font(.system(size: 14, weight: .medium)).frame(width: 110, alignment: .leading)
                    ForEach(Array(row.1.enumerated()), id: \.offset) { _, theme in
                        AspectoStage(theme: theme, state: state, minHeight: row.2)
                    }
                }
            }
        }
        .padding(32)
        .background(dark ? Color(white: 0.07) : Color(white: 0.97))
        .foregroundStyle(dark ? Color.white : Color.black)
        .environment(\.colorScheme, scheme(mode))
        writePNG(cgImage(view, scale: 1), to: path)
        print(path)
    }

    // MARK: --selftest-appearance

    /// Changes each of the four controls of the model and checks the sample, the real tooltip's reading and the real
    /// tooltip's pixels all follow. Exit code ≠ 0 if any check fails.
    static func selftest(_ args: [String]) -> Int32 {
        let dir = args.first
        if let dir { try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
        S.language = "es"
        let defaults = isolatedDefaults()
        let m = AppearanceModel(defaults: defaults)
        let accessibility = NSWorkspaceAccessibility.current
        guard let state = GalleryStates.all.first(where: { $0.id == "definition" }) else { return 1 }

        /// The real tooltip as it would open now: its theme comes from the saved defaults, as `TooltipPanel.show` reads it.
        func realCapture() -> (CGImage?, TooltipTheme) {
            let theme = TooltipStyle.current(defaults: defaults)
            return (cgImage(AspectoStage(theme: theme, state: state), scale: 1), theme)
        }
        var (previous, _) = realCapture()
        var previousSample = m.sampleTheme(systemIsDark: false, accessibility: accessibility)
        if let dir { writePNG(previous, to: dir + "/real-0-inicial.png") }

        let steps: [(String, () -> Void)] = [
            ("tema → terminal", { m.setTheme("terminal") }),
            ("modo → oscuro", { m.setAppearance(.dark) }),
            ("tamaño → XL", { m.setSize(.xl) }),
            ("densidad → amplia", { m.setDensity(.airy) }),
        ]
        var failed = false
        print("control               muestra cambia   tooltip lee = muestra   píxeles del tooltip real cambian")
        for (n, step) in steps.enumerated() {
            step.1()
            let sample = m.sampleTheme(systemIsDark: false, accessibility: accessibility)
            let (image, read) = realCapture()
            let sampleChanged = sample != previousSample
            let sameAsReal = read == sample
            let pixelsChanged = image.flatMap(raw) != previous.flatMap(raw) && image != nil
            let ok = sampleChanged && sameAsReal && pixelsChanged
            failed = failed || !ok
            let label = step.0.padding(toLength: 20, withPad: " ", startingAt: 0)
            print("\(label)  \(sampleChanged ? "sí" : "NO")               \(sameAsReal ? "sí" : "NO")                      \(pixelsChanged ? "sí" : "NO")   \(ok ? "" : "FALLA")")
            if let dir { writePNG(image, to: dir + "/real-\(n + 1)-\(step.0.split(separator: " ").first!)-\(step.0.split(separator: " ").last!).png") }
            previous = image
            previousSample = sample
        }
        // «Reabrir»: a new model on the same store sees the last choices.
        let again = AppearanceModel(defaults: defaults)
        let kept = again.preferences == m.preferences && again.preferences == ThemePreferences(themeID: "terminal", appearance: .dark, size: .xl, density: .airy)
        print("sobrevive a reabrir: \(kept ? "sí" : "NO")")
        failed = failed || !kept
        print(failed ? "FALLO" : "OK: 4 controles × 3 comprobaciones + reabrir")
        return failed ? 4 : 0
    }

    // MARK: --show-appearance

    /// Opens the real window, waits 3 s, saves what it shows (`cacheDisplay` of its content) and quits.
    static func show(_ path: String?) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = AspectoWindow()
        window.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                if let path, let image = window.snapshot, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    writePNG(cg, to: path)
                    print("window: \(path) \(cg.width)x\(cg.height)")
                } else { print("window: no snapshot") }
                NSApp.terminate(nil)
            }
        }
        app.run()
    }
}

/// The macOS accessibility settings, as the real tooltip reads them.
@MainActor
enum NSWorkspaceAccessibility {
    static var current: ThemeAccessibility {
        ThemeAccessibility(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                           increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }
}
