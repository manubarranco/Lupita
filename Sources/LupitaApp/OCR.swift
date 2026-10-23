import CoreGraphics
import ScreenCaptureKit
import Vision
import LupitaCore

/// Fallback when an app exposes no text (D3): capture a strip around the cursor and read it
/// with Vision, locally. Nothing leaves the Mac.
enum OCR {
    static let strip = CGSize(width: 600, height: 80)

    /// - Parameter point: cursor in global top-left coordinates.
    /// - Returns: recognised words with boxes in the same coordinates.
    static func words(around point: CGPoint) async throws -> [OCRWord] {
        guard CGPreflightScreenCaptureAccess() else { return [] }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.contains(point) }) else { return [] }

        let rect = CGRect(x: point.x - strip.width / 2, y: point.y - strip.height / 2,
                          width: strip.width, height: strip.height).intersection(display.frame)
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config = SCStreamConfiguration()
        config.sourceRect = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return try recognize(image, in: rect)
    }

    static func recognize(_ image: CGImage, in rect: CGRect) throws -> [OCRWord] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES", "en-US"]
        // Language correction "fixes" IDs into words (QL25 → QLS): off.
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])

        var words: [OCRWord] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            var searchStart = text.startIndex
            for word in text.split(whereSeparator: \.isWhitespace) {
                guard let range = text.range(of: word, range: searchStart..<text.endIndex) else { continue }
                searchStart = range.upperBound
                guard let box = try? candidate.boundingBox(for: range)?.boundingBox else { continue }
                // Vision: normalized, bottom-left origin → global top-left points.
                let global = CGRect(x: rect.minX + box.minX * rect.width,
                                    y: rect.minY + (1 - box.maxY) * rect.height,
                                    width: box.width * rect.width, height: box.height * rect.height)
                words.append(OCRWord(text: String(word), box: global))
            }
        }
        return words
    }
}
