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
}
