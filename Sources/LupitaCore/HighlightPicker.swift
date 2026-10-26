import CoreGraphics
import Foundation

/// Which OCR words Lupita could explain, for the highlight mode (D39). Only what is cheap to check:
/// indexed IDs, glossary terms and the fixed dictionaries (git/shell commands, error names). Never
/// symbols, commits, branches, files or PRs: they cost a search in the repos for every word.
public enum HighlightPicker {
    /// A box per known word or phrase, in the same coordinates as the words. Phrases of 2 to 4 words
    /// (`fast-forward merge`, `git stash`) give one box.
    public static func marks(words: [OCRWord], resolver: Resolver) -> [CGRect] {
        var marks: [CGRect] = []
        for row in rows(of: words) {
            let block = nearbyText(of: row[0], in: words)
            var i = 0
            while i < row.count {
                if let length = phraseLength(row, at: i, resolver: resolver, block: block) {
                    marks.append(trimmed(row[i..<i + length]))
                    i += length
                } else {
                    if knows(row[i].text, resolver: resolver, block: block, marked: row[i].codeStyled) { marks.append(trimmed(row[i...i])) }
                    i += 1
                }
            }
        }
        return marks
    }

    /// Below this brightness (0...1) a background takes light ink. Same line as the whole-window guess.
    public static let darkBelow = 110.0 / 255

    /// Whether the background under a mark is dark: the median brightness behind the words it covers.
    /// `nil` when none of them was measured, so the caller falls back to the whole window.
    public static func isDark(behind mark: CGRect, words: [OCRWord]) -> Bool? {
        let values = words.filter { $0.box.intersects(mark) }.compactMap(\.background).sorted()
        guard !values.isEmpty else { return nil }
        return values[values.count / 2] < darkBelow
    }

    static let trailing = CharacterSet(charactersIn: ".,;:!?…)]}\"'`*")
    static let leading = CharacterSet(charactersIn: "([{\"'`*")

    /// Words on the same line, left to right.
    static func rows(of words: [OCRWord]) -> [[OCRWord]] {
        var rows: [[OCRWord]] = []
        for word in words.sorted(by: { $0.box.midY < $1.box.midY }) {
            if let first = rows.last?.first, abs(word.box.midY - first.box.midY) <= first.box.height / 2 {
                rows[rows.count - 1].append(word)
            } else {
                rows.append([word])
            }
        }
        return rows.map { $0.sorted { $0.box.minX < $1.box.minX } }
    }

    static func clean(_ text: String) -> String {
        Resolver.latinize(text).trimmingCharacters(in: leading).trimmingCharacters(in: trailing)
    }

    static func closes(_ word: OCRWord) -> Bool {
        word.text.unicodeScalars.last.map(CharacterSet(charactersIn: ".,;:!?…").contains) ?? false
    }

    /// 4 to 2 words from `i` that name a glossary term or a dictionary command, longest first.
    static func phraseLength(_ row: [OCRWord], at i: Int, resolver: Resolver, block: String) -> Int? {
        for length in stride(from: 4, through: 2, by: -1) where i + length <= row.count {
            let slice = row[i..<i + length]
            // A phrase does not close early and does not jump a column gap.
            if slice.dropLast().contains(where: closes) { continue }
            let gapLimit = (slice.first?.box.height ?? 0) * 1.5
            if zip(slice, slice.dropFirst()).contains(where: { $1.box.minX - $0.box.maxX > gapLimit }) { continue }
            let phrase = slice.map { clean($0.text) }.joined(separator: " ")
            if resolver.resolveTerm(phrase) != nil { return length }
            if let command = CodeDictionaries.command(phrase.lowercased()), command.safe { return length }
            if GitVocabulary.knows(phrase, block: block) { return length }
        }
        return nil
    }

    /// The words of the text block around `word` (its row and the rows just above and below), left to
    /// right and top to bottom: the context the git package (D42) needs to tell `push` from `push`.
    public static func nearbyText(of word: OCRWord, in words: [OCRWord]) -> String {
        let near = words.filter { abs($0.box.midY - word.box.midY) <= word.box.height * 2.2 }
        return rows(of: near).map { $0.map(\.text).joined(separator: " ") }.joined(separator: " ")
    }

    static func knows(_ text: String, resolver: Resolver, block: String, marked: Bool = false) -> Bool {
        let word = clean(text)
        guard word.count >= 2 else { return false }
        if let id = IDGrammar.parse(word), resolver.index.definitions[id.key] != nil { return true }
        if resolver.rangeList(word) != nil { return true }
        if resolver.resolveTerm(word) != nil { return true }
        if CodeDictionaries.error(word) != nil { return true }
        if let command = CodeDictionaries.command(word.lowercased()), command.safe { return true }
        return GitVocabulary.knows(word, block: block, marked: marked)
    }

    /// The box of the words without the punctuation OCR glued to the first and last one.
    static func trimmed(_ words: ArraySlice<OCRWord>) -> CGRect {
        var box = words.map(\.box).dropFirst().reduce(words.first!.box) { $0.union($1) }
        if let first = words.first, let last = words.last {
            let lead = first.text.unicodeScalars.prefix { leading.contains($0) }.count
            let tail = last.text.unicodeScalars.reversed().prefix { trailing.contains($0) }.count
            let perFirst = first.box.width / CGFloat(max(first.text.count, 1))
            let perLast = last.box.width / CGFloat(max(last.text.count, 1))
            box.origin.x += perFirst * CGFloat(lead)
            box.size.width = max(0, box.width - perFirst * CGFloat(lead) - perLast * CGFloat(tail))
        }
        return box
    }
}
