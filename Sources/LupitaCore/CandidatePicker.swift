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
        var best: (range: NSRange, distance: Int, index: Int)?
        var ranges: [NSRange] = []
        var location = 0
        for (n, word) in words(of: line).enumerated() {
            let range = ns.range(of: word, range: NSRange(location: location, length: ns.length - location))
            location = range.location + range.length
            ranges.append(range)
            let distance = cursorOffset < range.location ? range.location - cursorOffset
                : cursorOffset >= range.location + range.length ? cursorOffset - (range.location + range.length) + 1 : 0
            guard distance <= slack, distance < (best?.distance ?? .max) else { continue }
            best = (range, distance, n)
        }
        guard let best else { return nil }
        let tail = ns.substring(with: NSRange(location: best.range.location + best.range.length,
                                              length: min(3, ns.length - best.range.location - best.range.length)))
        let single = resolver.resolve(ns.substring(with: best.range), preferredRepo: preferredRepo,
                                      context: String(ns.substring(with: NSRange(location: max(0, best.range.location - 80), length: min(best.range.location, 80)))),
                                      fromPath: fromPath, after: tail, block: line)
        if !isFound(single) {
            let texts = ranges.map { ns.substring(with: $0) }
            let closing = CharacterSet(charactersIn: ".,;:!?…")
            // `words(of:)` drops commas and semicolons, so look at the character right after each word.
            let closes: (Int) -> Bool = { i in
                let end = ranges[i].location + ranges[i].length
                return end < ns.length && ns.substring(with: NSRange(location: end, length: 1)).unicodeScalars.allSatisfy(closing.contains)
            }
            if let term = longerTerm(texts, at: best.index, closes: closes, resolver: resolver, preferredRepo: preferredRepo, fromPath: fromPath, block: line,
                                     context: { i in String(ns.substring(with: NSRange(location: max(0, ranges[i].location - 80), length: min(ranges[i].location, 80)))) }) {
                return term
            }
        }
        let start = max(0, best.range.location - 80)
        let context = ns.substring(with: NSRange(location: start, length: best.range.location - start))
        return resolver.resolve(ns.substring(with: best.range), preferredRepo: preferredRepo,
                                context: context, fromPath: fromPath, after: tail, block: line)
    }

    /// Max words in a glossary term (D23).
    static let maxTermWords = 4

    /// A single word that resolved to an ID, a repo reference or code: nothing longer should override it.
    /// A glossary term and a word of the git package (D42) can be the start of a longer phrase.
    static func isFound(_ r: Resolution) -> Bool {
        switch r.kind {
        case .exact, .corrected, .ambiguous:
            return !r.definitions.isEmpty && r.definitions.first?.rule != .term && r.definitions.first?.rule != .vocabulary
        case .undefined, .notAnID: return false
        }
    }

    /// Windows of 4 to 2 words that contain the word at `index`, longest first, as glossary terms.
    /// A word that ends in punctuation (`.,;:!?`) closes the phrase: the window cannot go past it.
    static func longerTerm(_ words: [String], at index: Int, closes extra: ((Int) -> Bool)? = nil, resolver: Resolver, preferredRepo: String?,
                           fromPath: String?, block: String, context: (Int) -> String) -> Resolution? {
        let closing = CharacterSet(charactersIn: ".,;:!?…")
        func closes(_ i: Int) -> Bool { (words[i].unicodeScalars.last.map(closing.contains) ?? false) || (extra?(i) ?? false) }
        for length in stride(from: maxTermWords, through: 2, by: -1) {
            for start in stride(from: index, through: index - length + 1, by: -1) {
                let end = start + length - 1
                guard start >= 0, end < words.count else { continue }
                if (start..<end).contains(where: closes) { continue }
                let phrase = words[start...end].joined(separator: " ")
                if let r = resolver.resolveTerm(phrase, preferredRepo: preferredRepo, context: context(start), fromPath: fromPath) {
                    return r
                }
                // Code that is written with spaces (D29): `npm run build`, `git status`, `PR 123`.
                if let r = resolver.resolveCode(phrase, preferredRepo: preferredRepo, context: context(start)) {
                    return r
                }
                // Last: a phrase of the git package (D42), `fast-forward merge`, `detached HEAD`.
                if let r = resolver.resolveGit(phrase, block: block) { return r }
            }
        }
        return nil
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
        func context(_ i: Int) -> String { String(row[..<i].map(\.text).joined(separator: " ").suffix(80)) }
        let block = HighlightPicker.nearbyText(of: nearest, in: words)
        let single = resolver.resolve(target.text, preferredRepo: preferredRepo, context: context(index), fromPath: fromPath, block: block)
        if !isFound(single),
           let term = longerTerm(row.map(\.text), at: index, resolver: resolver, preferredRepo: preferredRepo,
                                 fromPath: fromPath, block: block, context: context) {
            return term
        }
        return resolver.resolve(target.text, preferredRepo: preferredRepo,
                                context: context(index), fromPath: fromPath, block: block)
    }

    /// Splits like the resolver does: whitespace and brackets/quotes, keeping `D001:`-style
    /// punctuation for `Resolver.resolve` to trim.
    static func words(of line: String) -> [String] {
        line.split { $0.isWhitespace || "()[]{},;\"'`*".contains($0) }.map(String.init)
    }
}
