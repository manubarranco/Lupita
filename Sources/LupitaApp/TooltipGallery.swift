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
        let menus = [menuImage(gitOn: true), menuImage(gitOn: false)]
        let sheet = VocabularySheet(cards: cards, menus: menus)
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

    /// The real menu rows (header, lens, «Explicar términos de:», Git) drawn into an image.
    private static func menuImage(gitOn: Bool) -> NSImage {
        let rows: [NSView] = {
            let header = MenuHeader(title: S.appName)
            header.update([S.summary(ids: 1240, repos: 14, files: 380), S.updated(seconds: 42)])
            let lens = MenuRow(title: S.lens, on: true)
            let title = NSTextField(labelWithString: S.explainTermsOf)
            title.font = .systemFont(ofSize: 11, weight: .semibold)
            title.textColor = .secondaryLabelColor
            title.frame = NSRect(x: MenuRow.inset, y: 0, width: MenuRow.width - MenuRow.inset * 2, height: 22)
            let section = NSView(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: 26))
            title.frame.origin.y = 2
            section.addSubview(title)
            let git = MenuRow(title: S.gitPackage, on: gitOn)
            return [header, lens, section, git]
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
}

private struct VocabularySheet: View {
    let cards: [(String, Resolution)]
    let menus: [NSImage]

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
                ForEach(Array(menus.enumerated()), id: \.offset) { n, image in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(n == 0 ? "Menú · Git encendido" : "Menú · Git apagado").font(.caption.monospaced()).foregroundStyle(.secondary)
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
