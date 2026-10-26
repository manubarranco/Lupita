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
    /// - Parameter keeping: one of our own windows to read anyway (the tooltip, to look up what it cites).
    static func words(around point: CGPoint, keeping: CGWindowID? = nil) async throws -> [OCRWord] {
        guard CGPreflightScreenCaptureAccess() else { return [] }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.contains(point) }) else { return [] }

        let rect = CGRect(x: point.x - strip.width / 2, y: point.y - strip.height / 2,
                          width: strip.width, height: strip.height).intersection(display.frame)
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier && $0.windowID != keeping }
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

    /// What the highlight mode reads (D39): the whole window under the pointer.
    struct WindowRead {
        let words: [OCRWord]
        /// The window in global top-left coordinates (what the words' boxes use).
        let frame: CGRect
        /// The window is mostly dark: the marks need light ink.
        let isDark: Bool
    }

    /// The frontmost normal window under `point`, not ours, read whole with the same Vision settings.
    static func window(at point: CGPoint) async throws -> WindowRead? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        // CGWindowList is ordered front to back; ScreenCaptureKit's list is not.
        let order = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        guard let id = order.first(where: { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0, (info[kCGWindowOwnerPID as String] as? Int32) != me,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) })
            else { return false }
            return bounds.contains(point)
        }).flatMap({ $0[kCGWindowNumber as String] as? CGWindowID }) else { return nil }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == id }) else { return nil }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return WindowRead(words: try recognize(image, in: window.frame), frame: window.frame, isDark: isMostlyDark(image))
    }

    /// Average brightness of the image, from an 8×8 reduction.
    static func isMostlyDark(_ image: CGImage) -> Bool {
        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: 8, height: 8))
            return true
        }
        guard drawn else { return false }
        var sum = 0
        for i in stride(from: 0, to: pixels.count, by: 4) { sum += Int(pixels[i]) * 3 + Int(pixels[i + 1]) * 6 + Int(pixels[i + 2]) }
        return Double(sum) / 10 / 64 < 110
    }

    static func recognize(_ image: CGImage, in rect: CGRect) throws -> [OCRWord] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES", "en-US"]
        // Language correction "fixes" IDs into words (QL25 → QLS): off.
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])

        // The pixels, to tell words drawn on an inline-code box from plain text (D42).
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
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
                let measure = drawn ? pixels.withUnsafeBufferPointer { buffer in
                    CodeBox.measure(pixels: buffer, width: width, height: height, box: CGRect(
                        x: box.minX * CGFloat(width), y: (1 - box.maxY) * CGFloat(height),
                        width: box.width * CGFloat(width), height: box.height * CGFloat(height)))
                } : nil
                words.append(OCRWord(text: String(word), box: global, codeStyled: measure.map(CodeBox.isCodeStyled) ?? false,
                                     background: measure?.behind))
            }
        }
        return words
    }
}
