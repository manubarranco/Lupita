import AppKit
import LupitaCore
import SwiftUI

/// Development aid: `LupitaApp --render-tracker-states <dir>` writes `tracker-states-light.png` and `-dark.png`: the card of
/// a tracker key before its commit arrives, filled, and with no commit (the notice), next to an `FR-001` and a `D045` that
/// already worked. Synthetic data: no repo is read, no git runs.
@MainActor
enum TrackerSheet {
    static func run(_ dir: String?) -> Int32 {
        guard let dir else {
            FileHandle.standardError.write(Data("usage: LupitaApp --render-tracker-states <dir>\n".utf8))
            return 1
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        S.language = "es"
        var index = RefIndex()
        index.repos = [.made(name: "atlas", path: "/Users/demo/atlas")]
        let resolver = Resolver(index: index).withoutGit()
        let undefined = resolver.resolve("PLAT-443341", preferredRepo: "atlas")
        let pending = resolver.pendingResolution(for: undefined, preferredRepo: "atlas")
        let commit = Definition.made(id: "PLAT-443341", key: "9f2c1d7a0b3e", repo: "atlas", rule: .commit,
                                     title: "fix crash on save (PLAT-443341)", summary: "2026-10-28 · en la rama main", absolutePath: "/Users/demo/atlas")
        let filled = Resolution.made(query: "PLAT-443341", key: "PLAT443341", definitions: [commit])
        let fr = Resolution.made(query: "FR-001", key: "FR-001", definitions: [
            .made(id: "FR-001", repo: "atlas", path: "docs/spec.md", line: 31, rule: .heading,
                  title: "El usuario ve la definición sin salir de la ventana", summary: "Requisito funcional.", absolutePath: "/Users/demo/atlas/docs/spec.md")])
        let d45 = Resolution.made(query: "D045", key: "D45", definitions: [
            .made(id: "D45", repo: "atlas", path: "docs/decisions.md", line: 244, rule: .heading,
                  title: "Una clave de tracker sin definición enseña su commit", summary: "Se busca en git, con un límite de un segundo.", absolutePath: "/Users/demo/atlas/docs/decisions.md")])
        for scheme in [ColorScheme.light, .dark] {
            let theme = TooltipStyle.current(mode: scheme == .dark ? .dark : .light)
            func card(_ r: Resolution) -> AnyView { AnyView(TooltipView(resolution: r, theme: theme, open: { _ in })) }
            let rows: [(String, AnyView)] = [
                ("PLAT-443341 · antes de rellenarse", card(pending)),
                ("PLAT-443341 · con su commit", card(filled)),
                ("PLAT-443341 · sin commit (se cierra y avisa)", AnyView(NoticeView(text: S.notAReference, theme: theme))),
                ("FR-001 · como siempre", card(fr)),
                ("D045 · como siempre", card(d45)),
            ]
            let sheet = VStack(alignment: .leading, spacing: 18) {
                ForEach(0..<rows.count, id: \.self) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rows[n].0).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        rows[n].1
                    }
                }
            }
            .padding(32)
            .frame(width: 560, alignment: .leading)
            .background(scheme == .light ? Color(white: 0.96) : Color(white: 0.13))
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return 3 }
            let path = dir + "/tracker-states-" + (scheme == .light ? "light" : "dark") + ".png"
            try? png.write(to: URL(fileURLWithPath: path))
            print(path)
        }
        return 0
    }
}
