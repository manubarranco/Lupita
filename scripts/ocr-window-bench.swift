#!/usr/bin/env swift
// Spike (explore/highlight): how long does Vision take to read a whole window?
// Same configuration as Sources/LupitaApp/OCR.swift (es-ES + en-US, no language correction),
// run in .accurate and .fast on full-window captures and on a ~1000×400 crop around a point.
//
//   swift scripts/ocr-window-bench.swift capture1.png capture2.png …   (timings)
//   swift scripts/ocr-window-bench.swift --ids                          (are IDs read exactly?)
//
// Captures: `screencapture -x -o -l <windowID> out.png` (Retina size). Reports median of 5 runs.
import Foundation
import Vision
import ImageIO
import CoreText
import CoreGraphics

let runs = 5
let idPattern = try! NSRegularExpression(pattern: #"^[A-Z]{1,3}\d{1,3}(-[A-Z]\d{1,2})?[.,:;)]?$"#)

func load(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func read(_ image: CGImage, _ level: VNRequestTextRecognitionLevel) throws -> (seconds: Double, words: [String]) {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level
    request.recognitionLanguages = ["es-ES", "en-US"]
    request.usesLanguageCorrection = false
    let start = DispatchTime.now()
    try VNImageRequestHandler(cgImage: image).perform([request])
    let t = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e9
    var words: [String] = []
    for o in request.results ?? [] {
        if let c = o.topCandidates(1).first { words += c.string.split(whereSeparator: \.isWhitespace).map(String.init) }
    }
    return (t, words)
}

func median(_ v: [Double]) -> Double { v.sorted()[v.count / 2] }

func bench(_ label: String, _ image: CGImage) {
    for (name, level) in [("accurate", VNRequestTextRecognitionLevel.accurate), ("fast", .fast)] {
        do {
            _ = try read(image, level) // warm-up, not counted
            var times: [Double] = [], words: [String] = []
            for _ in 0..<runs { let r = try read(image, level); times.append(r.seconds); words = r.words }
            let ids = words.filter { idPattern.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
            print("| \(label) | \(image.width)×\(image.height) | \(name) | \(String(format: "%.2f", median(times))) | \(words.count) | \(ids.count) | \(ids.prefix(8).joined(separator: " ")) |")
        } catch { print("| \(label) | error: \(error) |") }
    }
}

print("| Capture | Pixels | Level | Median s (of \(runs)) | Words | ID-shaped | Sample IDs |")
print("|---|---|---|---|---|---|---|")
for path in CommandLine.arguments.dropFirst() where !path.hasPrefix("--") {
    guard let image = load(path) else { print("| \(path) | cannot read |"); continue }
    let name = (path as NSString).lastPathComponent
    bench(name + " (window)", image)
    // Crop ~1000×400 pt (2000×800 px at Retina) around the window's centre.
    let w = min(2000, image.width), h = min(800, image.height)
    if let crop = image.cropping(to: CGRect(x: (image.width - w) / 2, y: (image.height - h) / 2, width: w, height: h)) {
        bench(name + " (crop 1000×400 pt)", crop)
    }
}

// Reading IDs: no real capture has to contain them, so draw some (Retina, 13 pt, light and dark)
// and check which come back exactly. Run with: swift scripts/ocr-window-bench.swift --ids
func renderIDs(dark: Bool, size: CGFloat) -> CGImage {
    let lines = ["Per D23 we keep L04 and E2-S3 before QL25 ships.", "See D6, D14, E2-S4 and Q01 in the glossary; D006 answers it.",
                 "Blocked by QL25 (E2-S3), then rebase onto main and re-run L04."]
    let scale: CGFloat = 2, w = 1100, h = 120
    let ctx = CGContext(data: nil, width: Int(CGFloat(w) * scale), height: Int(CGFloat(h) * scale), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.setFillColor(dark ? CGColor(gray: 0.12, alpha: 1) : CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
    for (i, line) in lines.enumerated() {
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): dark ? CGColor(gray: 0.92, alpha: 1) : CGColor(gray: 0.1, alpha: 1)]
        let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attrs))
        ctx.textPosition = CGPoint(x: 12, y: CGFloat(h) - 30 - CGFloat(i) * (size + 12))
        CTLineDraw(ctLine, ctx)
    }
    return ctx.makeImage()!
}
if CommandLine.arguments.contains("--ids") {
    let expected = ["D23", "L04", "E2-S3", "QL25", "D6", "D14", "E2-S4", "Q01", "D006", "QL25", "E2-S3", "L04"]
    print("\n| Text | Size | Level | IDs read exactly |\n|---|---|---|---|")
    for dark in [false, true] { for size: CGFloat in [11, 13, 15] {
        let img = renderIDs(dark: dark, size: size)
        for (name, level) in [("accurate", VNRequestTextRecognitionLevel.accurate), ("fast", .fast)] {
            let words = (try? read(img, level).words) ?? []
            let clean = words.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()")) }
            var pool = clean, hit = 0
            for e in expected { if let i = pool.firstIndex(of: e) { pool.remove(at: i); hit += 1 } }
            let missed = expected.filter { e in !clean.contains(e) }
            print("| \(dark ? "dark" : "light") | \(Int(size)) pt | \(name) | \(hit)/\(expected.count)\(missed.isEmpty ? "" : " (missing: \(Set(missed).sorted().joined(separator: " ")))") |")
        }
    } }
}
