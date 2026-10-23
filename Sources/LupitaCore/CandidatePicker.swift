import CoreGraphics
import Foundation

/// A word recognised by OCR, with its box in screen points (top-left origin).
public struct OCRWord: Sendable, Equatable {
    public let text: String
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}

/// Picks the reference the user is pointing at. Only the word under the cursor counts:
/// pointing at a normal word must not pop up an ID that happens to sit further along the line.
public enum CandidatePicker {
    /// Characters of slack around the cursor when matching a word (AX offsets can land on a space).
    static let slack = 1
    /// Max horizontal distance, in points, from the cursor to an OCR word box. Real pointing
    /// lands in the gap between words; 12 pt missed 5 of 24 real lookups.
    static let maxDistance: CGFloat = 24
    /// Max vertical distance to a row when the cursor sits between two lines.
    static let maxRowGap: CGFloat = 10

    /// Text from the Accessibility API: a line and the cursor's UTF-16 offset in it.
    public static func pick(line: String, cursorOffset: Int, resolver: Resolver,
                            preferredRepo: String? = nil, fromPath: String? = nil) -> Resolution? {
        let ns = line as NSString
        var best: (range: NSRange, distance: Int)?
        var location = 0
        for word in words(of: line) {
            let range = ns.range(of: word, range: NSRange(location: location, length: ns.length - location))
            location = range.location + range.length
            let distance = cursorOffset < range.location ? range.location - cursorOffset
                : cursorOffset >= range.location + range.length ? cursorOffset - (range.location + range.length) + 1 : 0
            guard distance <= slack, distance < (best?.distance ?? .max) else { continue }
            best = (range, distance)
        }
        guard let best else { return nil }
        let start = max(0, best.range.location - 80)
        let context = ns.substring(with: NSRange(location: start, length: best.range.location - start))
        return resolver.resolve(ns.substring(with: best.range), preferredRepo: preferredRepo,
                                context: context, fromPath: fromPath)
    }

    /// Words from OCR: the one under (or nearest to) the cursor on the cursor's row.
    public static func pick(words: [OCRWord], cursor: CGPoint, resolver: Resolver,
                            preferredRepo: String? = nil, fromPath: String? = nil) -> Resolution? {
        // The row under the cursor, or else the nearest row within `maxRowGap`.
        func rowGap(_ w: OCRWord) -> CGFloat {
            cursor.y < w.box.minY ? w.box.minY - cursor.y : cursor.y > w.box.maxY ? cursor.y - w.box.maxY : 0
        }
        guard let nearest = words.min(by: { rowGap($0) < rowGap($1) }), rowGap(nearest) <= maxRowGap else { return nil }
        let row = words.filter { abs($0.box.midY - nearest.box.midY) <= nearest.box.height / 2 }
            .sorted { $0.box.minX < $1.box.minX }
        func distance(_ w: OCRWord) -> CGFloat {
            cursor.x < w.box.minX ? w.box.minX - cursor.x : cursor.x > w.box.maxX ? cursor.x - w.box.maxX : 0
        }
        guard let target = row.min(by: { distance($0) < distance($1) }), distance(target) <= maxDistance,
              let index = row.firstIndex(of: target)
        else { return nil }
        let context = row[..<index].map(\.text).joined(separator: " ").suffix(80)
        return resolver.resolve(target.text, preferredRepo: preferredRepo,
                                context: String(context), fromPath: fromPath)
    }

    /// Splits like the resolver does: whitespace and brackets/quotes, keeping `D001:`-style
    /// punctuation for `Resolver.resolve` to trim.
    static func words(of line: String) -> [String] {
        line.split { $0.isWhitespace || "()[]{},;\"'`*".contains($0) }.map(String.init)
    }
}
