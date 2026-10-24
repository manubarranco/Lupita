// Draws the app icon (Lupita at rest, looking straight ahead) from the numbers in
// docs/brand/guide.md and writes Resources/AppIcon.icns. CoreGraphics + iconutil only.
//
//   swift scripts/make-icon.swift            # writes Resources/AppIcon.icns
//   swift scripts/make-icon.swift out.png    # also writes the 1024 px PNG, to look at
import AppKit
import CoreGraphics
import Foundation

let ink = CGColor(red: 0x1f / 255, green: 0x1f / 255, blue: 0x1d / 255, alpha: 1)
let surface = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

/// One square PNG of `px` pixels: the macOS plate (824/1024 of the canvas, rounded, soft
/// shadow) with Lupita at rest on it, the lens variant (filled disc, stroke 8).
func render(_ px: Int) -> Data {
    let s = CGFloat(px) / 1024
    let cg = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Work top-down like the SVGs.
    cg.translateBy(x: 0, y: CGFloat(px))
    cg.scaleBy(x: s, y: -s)

    // Plate: Apple's grid, 824 × 824 at (100, 100), corner radius 185.
    let plate = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                       cornerWidth: 185, cornerHeight: 185, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 12), blur: 28,
                 color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
    cg.addPath(plate)
    cg.setFillColor(surface)
    cg.fillPath()
    cg.restoreGState()

    // Lupita: bounding box -42…56 units (centre at 7, 7), drawn 5.6 px per unit so it keeps
    // well over the guide's clear space inside the plate.
    let unit: CGFloat = 5.6
    cg.translateBy(x: 512 - 7 * unit, y: 512 - 7 * unit)
    cg.scaleBy(x: unit, y: unit)
    cg.setLineCap(.round)
    cg.setLineWidth(8)
    cg.setFillColor(surface)
    cg.fillEllipse(in: CGRect(x: -38, y: -38, width: 76, height: 76))
    cg.setStrokeColor(ink)
    cg.strokeEllipse(in: CGRect(x: -38, y: -38, width: 76, height: 76))
    cg.move(to: CGPoint(x: 28, y: 28))
    cg.addLine(to: CGPoint(x: 52, y: 52))
    cg.strokePath()
    cg.setFillColor(ink)
    for x: CGFloat in [-14, 4] {
        cg.addPath(CGPath(roundedRect: CGRect(x: x, y: -11, width: 10, height: 22),
                          cornerWidth: 5, cornerHeight: 5, transform: nil))
    }
    cg.fillPath()

    let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
if CommandLine.arguments.count > 1 {
    try render(1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print("Resources/AppIcon.icns")
