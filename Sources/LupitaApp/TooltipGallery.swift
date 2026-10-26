import AppKit
import LupitaCore
import SwiftUI

/// Development aid: `LupitaApp --render-tooltips <dir> [repo::]text…` resolves each text against the repos in
/// `~/Repos` and writes one PNG per text and colour scheme (`01-light.png`, `01-dark.png`), all the same size,
/// so `scripts/contact-sheet.swift` can lay them out. It draws the real `TooltipView`; nothing is shown on screen.
@MainActor
enum TooltipGallery {
    static let canvas = CGSize(width: 500, height: 280)

    static func run(_ args: [String]) -> Int32 {
        guard let dir = args.first else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-tooltips <dir> [repo::]text…\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let resolver = Resolver(index: RefIndex.build(roots: ["~/Repos"]))
        var failed = false
        for (n, spec) in args.dropFirst().enumerated() {
            let parts = spec.components(separatedBy: "::")
            let (repo, text) = parts.count == 2 ? (parts[0], parts[1]) : (nil, spec)
            let resolution = resolver.resolve(text, preferredRepo: repo)
            guard !resolution.definitions.isEmpty else {
                FileHandle.standardError.write(Data("nothing for “\(text)”\n".utf8))
                failed = true
                continue
            }
            for scheme in [ColorScheme.light, .dark] {
                let name = String(format: "%02d-%@.png", n + 1, scheme == .light ? "light" : "dark")
                write(TooltipView(resolution: resolution, open: { _ in }), scheme: scheme, to: dir + "/" + name)
            }
            print(String(format: "%02d  %@", n + 1, text))
        }
        return failed ? 2 : 0
    }

    private static func write<V: View>(_ view: V, scheme: ColorScheme, to path: String) {
        let backdrop = scheme == .light ? Color(white: 0.96) : Color(white: 0.13)
        let framed = ZStack(alignment: .topLeading) {
            backdrop
            view.padding(20)
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    // MARK: Git vocabulary sheet (D42)

    static let vocabularyTerms = ["rebasear", "fast-forward merge", "detached HEAD", "stasheo", "force push", "PR"]

    /// `LupitaApp --render-vocabulary <dir>` writes `git-vocabulary.png`: the cards of six git terms in Spanish
    /// and the menu with the «Git» switch on and off. It needs no repos: the package is a table in code.
    static func runVocabulary(_ dir: String?) -> Int32 {
        guard let dir else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-vocabulary <dir>\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        S.language = "es"
        GitVocabulary.isEnabled = true
        let resolver = Resolver(index: RefIndex())
        var cards: [(String, Resolution)] = []
        for term in vocabularyTerms {
            let resolution = resolver.resolve(term)
            guard !resolution.definitions.isEmpty else {
                FileHandle.standardError.write(Data("nothing for “\(term)”\n".utf8))
                return 2
            }
            cards.append((term, resolution))
        }
        let menus = [menuImage(off: []), menuImage(off: [.terminal])]
        var inline: [(String, NSImage)] = []
        for dark in [false, true] {
            guard let image = inlineCodeImage(dark: dark, resolver: resolver) else { return 4 }
            inline.append((dark ? "Inline code · fondo oscuro" : "Inline code · fondo claro", image))
        }
        let sheet = VocabularySheet(cards: cards, menus: menus, inline: inline)
        for scheme in [ColorScheme.light, .dark] {
            let path = dir + "/git-vocabulary-" + (scheme == .light ? "light" : "dark") + ".png"
            let renderer = ImageRenderer(content: sheet.environment(\.colorScheme, scheme))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return 3 }
            try? png.write(to: URL(fileURLWithPath: path))
            print(path)
        }
        return 0
    }

    /// A line with `main` in an inline-code box and the same word as plain text, read by the real OCR and the real
    /// highlight picker: the underline must appear under the first `main` only (D42).
    private static func inlineCodeImage(dark: Bool, resolver: Resolver) -> NSImage? {
        let w = 360.0, h = 130.0, scale = 2.0
        let drawing = NSImage(size: NSSize(width: w, height: h), flipped: false) { r in
            (dark ? NSColor(white: 0.13, alpha: 1) : .white).setFill(); r.fill()
            let fg = dark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.1, alpha: 1)
            let box = dark ? NSColor(white: 0.25, alpha: 1) : NSColor(white: 0.92, alpha: 1)
            let ink = dark ? NSColor(red: 1, green: 0.6, blue: 0.5, alpha: 1) : NSColor(red: 0.75, green: 0.2, blue: 0.15, alpha: 1)
            let body = NSFont.systemFont(ofSize: 15), mono = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
            for (row, parts) in [[("Ya está en", false), ("main", true), ("y listo", false)],
                                 [("Ya está en", false), ("main", false), ("y listo", false)]].enumerated() {
                var x: CGFloat = 20
                let y = CGFloat(95 - row * 70)
                for (s, code) in parts {
                    let attributes: [NSAttributedString.Key: Any] = [.font: code ? mono : body, .foregroundColor: code ? ink : fg]
                    let size = (s as NSString).size(withAttributes: attributes)
                    if code {
                        box.setFill()
                        NSBezierPath(roundedRect: NSRect(x: x - 4, y: y - 2, width: size.width + 8, height: size.height + 4), xRadius: 4, yRadius: 4).fill()
                    }
                    (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
                    x += size.width + (code ? 12 : 4)
                }
            }
            return true
        }
        var rect = CGRect(x: 0, y: 0, width: w * scale, height: h * scale)
        guard let cg = drawing.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let words = try? OCR.recognize(cg, in: CGRect(x: 0, y: 0, width: w, height: h)) else { return nil }
        print((dark ? "dark " : "light ") + words.map { "\($0.text)\($0.codeStyled ? "[code]" : "")" }.joined(separator: " "))
        let marks = HighlightPicker.marks(words: words, resolver: resolver)
        let out = NSImage(size: NSSize(width: w, height: h))
        out.lockFocus()
        drawing.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        (dark ? NSColor(white: 0.95, alpha: 1) : NSColor(white: 0.1, alpha: 1)).setStroke()
        for m in marks {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: m.minX, y: h - m.maxY - 1)); line.line(to: NSPoint(x: m.maxX, y: h - m.maxY - 1))
            line.lineWidth = 1.2; line.stroke()
        }
        out.unlockFocus()
        print("  marks: \(marks.count)")
        return out
    }

    /// The real menu rows (header, lens, «Explicar términos de:», Git) drawn into an image.
    private static func menuImage(off: Set<TermPackage>) -> NSImage {
        let rows: [NSView] = {
            let header = MenuHeader(title: S.appName)
            let lens = MenuRow(title: S.lens, on: true)
            let title = NSTextField(labelWithString: S.explainTermsOf)
            title.font = .systemFont(ofSize: 11, weight: .semibold)
            title.textColor = .secondaryLabelColor
            title.frame = NSRect(x: MenuRow.inset, y: 0, width: MenuRow.width - MenuRow.inset * 2, height: 22)
            let section = NSView(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: 26))
            title.frame.origin.y = 2
            section.addSubview(title)
            let packages = TermPackage.allCases.map { MenuRow(title: VocabularyPackages.title($0), on: !off.contains($0)) }
            return [header, lens, section] + packages
        }()
        let height = rows.reduce(0) { $0 + $1.frame.height } + 16
        let card = NSView(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: height))
        card.appearance = NSAppearance(named: .aqua)
        var y = height - 8
        for row in rows {
            y -= row.frame.height
            row.frame.origin.y = y
            card.addSubview(row)
        }
        card.layoutSubtreeIfNeeded()
        let rep = card.bitmapImageRepForCachingDisplay(in: card.bounds)!
        card.cacheDisplay(in: card.bounds, to: rep)
        let image = NSImage(size: card.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: Underline sheet (D46)

    /// `LupitaApp --render-underline <dir>` writes `underline.png`: a sentence with an ID, a glossary term and
    /// git words, on a light and a dark background, read by the real OCR and underlined with the real layers.
    static func runUnderline(_ dir: String?) -> Int32 {
        guard let dir else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-underline <dir>\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        S.language = "es"
        GitVocabulary.isEnabled = true
        // A tiny repo on disk with one decisions file and one glossary.
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-underline/atlas")
        try? FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try? "## D023 — Sin dependencias\nNada nuevo.\n\n## Q07 — Qué falta\nAlgo.\n"
            .write(to: repo.appendingPathComponent("decisions.md"), atomically: true, encoding: .utf8)
        try? "- **saldo inicial** — lo que hay al abrir\n".write(to: repo.appendingPathComponent("glossary.md"), atomically: true, encoding: .utf8)
        let index = RefIndex.build(roots: [repo.deletingLastPathComponent().path])
        let resolver = Resolver(index: index)
        let w: CGFloat = 560, h: CGFloat = 162, scale: CGFloat = 2
        let lines = ["Según D023 y Q07, el saldo inicial no cambia.", "Haz un rebase y luego un force push a main.",
                     "En atlas, el <dialog> devuelve HTTP 401 y ENOENT.",
                     "Lee decisions.md y glossary.md:2, no notes.md."]
        var tiles: [NSImage] = []
        for dark in [false, true] {
            let drawing = NSImage(size: NSSize(width: w, height: h), flipped: false) { r in
                (dark ? NSColor(white: 0.12, alpha: 1) : .white).setFill(); r.fill()
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17),
                                                                 .foregroundColor: dark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.1, alpha: 1)]
                for (n, line) in lines.enumerated() { (line as NSString).draw(at: NSPoint(x: 20, y: h - 36 - CGFloat(n) * 36), withAttributes: attributes) }
                return true
            }
            var rect = CGRect(x: 0, y: 0, width: w * scale, height: h * scale)
            guard let cg = drawing.cgImage(forProposedRect: &rect, context: nil, hints: nil),
                  let words = try? OCR.recognize(cg, in: CGRect(x: 0, y: 0, width: w, height: h)) else { return 2 }
            let marks = HighlightPicker.classified(words: words, resolver: resolver)
            print((dark ? "dark: " : "light: ") + marks.map { $0.kind == .id ? "id" : "term" }.joined(separator: " "))
            let out = NSImage(size: NSSize(width: w, height: h), flipped: false) { r in
                drawing.draw(in: r)
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                let ink = HighlightStyle.ink(onDark: dark)
                for mark in marks {
                    let layer = HighlightOverlay.line(mark.kind, ink: ink)
                    // Top-left box → this image's bottom-left space, just under the word.
                    layer.frame = CGRect(x: mark.box.minX, y: h - mark.box.maxY - HighlightStyle.gap - HighlightStyle.thickness,
                                         width: mark.box.width, height: HighlightStyle.thickness)
                    (layer as? CAShapeLayer)?.path = HighlightOverlay.dashPath(width: layer.frame.width)
                    ctx.saveGState()
                    ctx.translateBy(x: layer.frame.minX, y: layer.frame.minY)
                    layer.frame.origin = .zero
                    layer.render(in: ctx)
                    ctx.restoreGState()
                }
                return true
            }
            tiles.append(out)
        }
        let sheet = NSImage(size: NSSize(width: w, height: h * 2), flipped: false) { _ in
            tiles[0].draw(in: NSRect(x: 0, y: h, width: w, height: h))
            tiles[1].draw(in: NSRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        var sheetRect = CGRect(x: 0, y: 0, width: w * scale, height: h * 2 * scale)
        guard let cg = sheet.cgImage(forProposedRect: &sheetRect, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return 2 }
        try? png.write(to: URL(fileURLWithPath: dir + "/underline.png"))
        return 0
    }

    // MARK: Menu sheet (D44)

    /// `LupitaApp --render-menu <dir>` writes `menu-light.png` and `menu-dark.png` (permissions granted as they
    /// are), `menu-permissions.png` (both missing) and `menu-option.png` (⌥ held): the real menu, its folders opened, drawn item by item.
    static func runMenu(_ dir: String?) -> Int32 {
        guard let dir else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-menu <dir>\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let status = StatusMenu(store: IndexStore(), onHotkeyChange: { _ in })
        for (name, dark, missing, option) in [("menu-light", false, false, false), ("menu-dark", true, false, false),
                                              ("menu-permissions", false, true, false), ("menu-option", false, false, true)] {
            let image = menuImage(status.filledForGallery(missingPermissions: missing, option: option), dark: dark)
            guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { return 2 }
            try? png.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
            print(name)
        }
        return 0
    }

    /// Each item as the menu draws it: views as they are, text items as label plus icon, separators as a line.
    private static func menuImage(_ menu: NSMenu, dark: Bool) -> NSImage {
        let rows: [NSView] = menu.items.map { item in
            if let view = item.view { return view }
            let row = NSView(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: item.isSeparatorItem ? 11 : 24))
            if item.isSeparatorItem {
                let line = NSBox(frame: NSRect(x: MenuRow.inset, y: 5, width: MenuRow.width - MenuRow.inset * 2, height: 1))
                line.boxType = .separator
                row.addSubview(line)
                return row
            }
            var x = MenuRow.inset
            if let image = item.image {
                let icon = NSImageView(frame: NSRect(x: x, y: 4, width: 16, height: 16))
                icon.image = image
                icon.contentTintColor = .labelColor
                row.addSubview(icon)
                x += 22
            }
            let label = NSTextField(labelWithString: item.title + (item.submenu != nil ? "  ›" : ""))
            label.font = item.isSectionHeader ? .systemFont(ofSize: 11, weight: .semibold) : .menuFont(ofSize: 0)
            label.textColor = item.isSectionHeader ? .secondaryLabelColor : .labelColor
            label.frame = NSRect(x: x, y: 3, width: MenuRow.width - x - MenuRow.inset, height: 17)
            row.addSubview(label)
            return row
        }
        let height = rows.reduce(0) { $0 + $1.frame.height } + 12
        let card = NSView(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: height))
        card.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        card.wantsLayer = true
        card.layer?.backgroundColor = (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.97, alpha: 1)).cgColor
        var y = height - 6
        for row in rows {
            y -= row.frame.height
            // A menu item keeps hold of its view's frame: draw it inside a holder placed at the row.
            let holder = NSView(frame: NSRect(x: 0, y: y, width: MenuRow.width, height: row.frame.height))
            row.removeFromSuperview()
            row.setFrameOrigin(.zero)
            holder.addSubview(row)
            card.addSubview(holder)
        }
        card.layoutSubtreeIfNeeded()
        let rep = card.bitmapImageRepForCachingDisplay(in: card.bounds)!
        card.cacheDisplay(in: card.bounds, to: rep)
        let image = NSImage(size: card.bounds.size)
        image.addRepresentation(rep)
        return image
    }

}

private struct VocabularySheet: View {
    let cards: [(String, Resolution)]
    let menus: [NSImage]
    let inline: [(String, NSImage)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Vocabulario de git · D42").font(.title3.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(440), spacing: 24, alignment: .topLeading), count: 3), alignment: .leading, spacing: 22) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("«\(card.0)»").font(.caption.monospaced()).foregroundStyle(.secondary)
                        TooltipView(resolution: card.1, open: { _ in })
                    }
                }
            }
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(inline.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.0 + " · «main» subrayado solo en el código").font(.caption.monospaced()).foregroundStyle(.secondary)
                        Image(nsImage: item.1).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    }
                }
            }
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(menus.enumerated()), id: \.offset) { n, image in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(n == 0 ? "Menú · los tres encendidos" : "Menú · Terminal apagado").font(.caption.monospaced()).foregroundStyle(.secondary)
                        Image(nsImage: image).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 1460, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
