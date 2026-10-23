import Foundation

public struct Resolution: Sendable {
    public enum Kind: String, Sendable {
        case exact
        /// OCR text did not match, but a visual-confusion variant did (D5).
        case corrected
        /// Several variants matched different IDs: shown as candidates, never auto-picked.
        case ambiguous
        /// Looks like an ID but nothing defines it (only mentions, if any).
        case undefined
        /// Not an ID at all.
        case notAnID
    }

    public let query: String
    public let kind: Kind
    /// Matched key (for `exact`/`corrected`).
    public let key: String?
    /// Definitions, preferred repo first.
    public let definitions: [Definition]
    public let mentions: Mentions?
    /// For `ambiguous`: the competing keys.
    public let alternatives: [String]
    /// The preferred repo has no real definition: the first one shown comes from elsewhere.
    /// The tooltip must say so instead of presenting it as the local meaning.
    public var fromOtherRepo = false

    /// D13: a short ID reached only through OCR correction is shown as "did you mean…?".
    public var isSuggestion: Bool { kind == .corrected && (key?.count ?? 0) < 4 }
}

public struct Resolver: Sendable {
    public let index: RefIndex
    /// Longest first, so `harbor-web` wins over a shorter name inside it (`harbor`).
    let repoNames: [String]

    public init(index: RefIndex) {
        self.index = index
        let names = Set(index.repos.map(\.name)).union(index.definitions.values.flatMap { $0.map(\.repo) })
        repoNames = names.sorted { $0.count > $1.count }
    }

    /// Characters OCR commonly confuses. Letters can turn into digits and vice versa.
    static let confusions: [Character: [Character]] = [
        "O": ["0", "D", "Q"], "o": ["0"], "0": ["O", "D"], "D": ["0", "O"], "Q": ["O", "0"],
        "I": ["1", "L"], "l": ["1", "I"], "|": ["1", "I"], "1": ["I", "L", "7"], "L": ["1", "I"],
        "S": ["5"], "s": ["5"], "5": ["S"], "B": ["8"], "8": ["B"], "Z": ["2"], "2": ["Z"],
        "G": ["6"], "6": ["G"], "7": ["1"], "T": ["7"],
    ]
    static let maxSubstitutions = 2

    /// OCR returns look-alike glyphs that are never part of an ID: the slashed zero of
    /// monospaced fonts (`LØ15`) and Cyrillic/Greek capitals identical to Latin ones (`Е9`).
    static let lookAlikes: [Character: Character] = [
        "Ø": "0", "ø": "0",
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P",
        "С": "C", "Т": "T", "Х": "X", "І": "I", "Ј": "J", "Ѕ": "S",
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x",
        "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M",
        "Ν": "N", "Ο": "O", "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X",
    ]

    static func latinize(_ text: String) -> String {
        String(text.map { lookAlikes[$0] ?? $0 })
    }

    /// - Parameters:
    ///   - preferredRepo: repo name from the active window (D8); its definitions come first.
    ///   - context: surrounding text (the OCR line). A repo named in it beats `preferredRepo`
    ///     ("…`harbor-web` docs/decisions.md D008").
    ///   - fromPath: path of the file being read, relative to `preferredRepo`. Definitions in
    ///     nearby folders win (`domains/billing/…` cites `domains/billing/decisions.md`).
    public func resolve(_ raw: String, preferredRepo: String? = nil, context: String? = nil,
                        fromPath: String? = nil) -> Resolution {
        // A repo named in the text beats one named in the file path (`domains/harbor-log.md`),
        // which beats the window's repo.
        let named = context.flatMap(repoNamed(in:)) ?? fromPath.flatMap(repoNamed(in:)).flatMap { $0 == preferredRepo ? nil : $0 }
        let fromPath = named == nil || named == preferredRepo ? fromPath : nil
        let preferredRepo = named ?? preferredRepo
        // A bar glued to a letter or digit is a misread 1 (`D|` for `D1`), not punctuation.
        let bars = raw.replacingOccurrences(of: #"(?<=[A-Za-z0-9])\|"#, with: "1", options: .regularExpression)
        let query = Self.latinize(bars.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        if let id = IDGrammar.parse(query), let defs = index.definitions[id.key] {
            return result(query, .exact, key: id.key, defs, preferredRepo, fromPath)
        }

        // Fewest substitutions first; stop at the first distance that yields any match.
        for distance in 1...Self.maxSubstitutions {
            let keys = Set(variants(of: query, substitutions: distance).compactMap { variant -> String? in
                guard let key = IDGrammar.parse(variant)?.key, index.definitions[key] != nil else { return nil }
                return key
            })
            if keys.count == 1, let key = keys.first {
                return result(query, .corrected, key: key, index.definitions[key]!, preferredRepo, fromPath)
            }
            if keys.count > 1 {
                let defs = keys.sorted().flatMap { index.definitions[$0]!.prefix(1) }
                return Resolution(query: query, kind: .ambiguous, key: nil, definitions: defs,
                                  mentions: nil, alternatives: keys.sorted())
            }
        }

        // Several look-alikes at once in the number part (`LOoz` → `L002`): read everything after
        // the prefix as digits. Only when exactly one real ID comes out.
        let tailKeys = Set(numericTailReadings(of: query).compactMap { variant -> String? in
            guard let key = IDGrammar.parse(variant)?.key, index.definitions[key] != nil else { return nil }
            return key
        })
        if tailKeys.count == 1, let key = tailKeys.first {
            return result(query, .corrected, key: key, index.definitions[key]!, preferredRepo, fromPath)
        }

        if let id = IDGrammar.parse(query) {
            return Resolution(query: query, kind: .undefined, key: id.key, definitions: [],
                              mentions: index.mentions[id.key], alternatives: [])
        }
        return Resolution(query: query, kind: .notAnID, key: nil, definitions: [], mentions: nil, alternatives: [])
    }

    /// Picks ID candidates out of a line of OCR text and resolves them, nearest to `cursorOffset` first.
    public func resolveLine(_ text: String, cursorOffset: Int? = nil, preferredRepo: String? = nil) -> [Resolution] {
        let words = text.split { $0.isWhitespace || "()[]{},;\"'`".contains($0) }.map(String.init)
        var offset = 0
        var scored: [(Int, Resolution)] = []
        for word in words {
            let start = (text as NSString).range(of: word, range: NSRange(location: offset, length: (text as NSString).length - offset)).location
            offset = start + (word as NSString).length
            let window = (text as NSString).substring(with: NSRange(location: max(0, start - 80), length: min(start, 80) + (word as NSString).length))
            let r = resolve(word, preferredRepo: preferredRepo, context: window)
            guard r.kind == .exact || r.kind == .corrected || r.kind == .ambiguous else { continue }
            scored.append((abs(start - (cursorOffset ?? start)), r))
        }
        return scored.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// How OCR misreads digits. Used on the part after the prefix only.
    static let asDigit: [Character: Character] = [
        "O": "0", "o": "0", "D": "0", "Q": "0", "I": "1", "l": "1", "|": "1", "i": "1", "L": "1",
        "Z": "2", "z": "2", "S": "5", "s": "5", "B": "8", "G": "6", "g": "9", "T": "7",
    ]

    /// Each split into prefix (1-5 uppercase letters) + tail, with the tail read as digits.
    /// The tail needs at least two characters so a lone letter is never turned into a number.
    func numericTailReadings(of text: String) -> [String] {
        let chars = Array(text)
        guard chars.count >= 3, chars.count <= 12 else { return [] }
        var out: [String] = []
        for split in 1...min(5, chars.count - 2) {
            let prefix = chars[..<split]
            guard prefix.allSatisfy({ $0.isUppercase && $0.isASCII }) else { break }
            let tail = chars[split...].map { $0.isNumber ? $0 : (Self.asDigit[$0] ?? $0) }
            guard tail.allSatisfy(\.isNumber) else { continue }
            out.append(String(prefix) + String(tail))
        }
        return out
    }

    func variants(of text: String, substitutions: Int) -> [String] {
        let chars = Array(text)
        var out: [String] = []
        func go(_ i: Int, _ left: Int, _ acc: [Character]) {
            if out.count > 2000 { return }
            if i == chars.count {
                if left == 0 { out.append(String(acc)) }
                return
            }
            go(i + 1, left, acc + [chars[i]])
            if left > 0, let alts = Self.confusions[chars[i]] {
                for alt in alts { go(i + 1, left - 1, acc + [alt]) }
            }
        }
        go(0, substitutions, [])
        return out
    }

    /// Real definitions before weak ones; within each, the preferred repo first, then the
    /// folder nearest to `fromPath`. Weak definitions from other repos are dropped: a `## P1`
    /// section elsewhere says nothing about a `P1` here. `defs` is already ranked.
    private func result(_ query: String, _ kind: Resolution.Kind, key: String, _ defs: [Definition],
                        _ repo: String?, _ fromPath: String?) -> Resolution {
        func isPreferred(_ d: Definition) -> Bool { repo.map { d.repo.caseInsensitiveCompare($0) == .orderedSame } ?? false }
        /// Depth of the definition's folder when it is the reader's folder or one of its parents.
        func nearness(_ d: Definition) -> Int {
            guard let fromPath, isPreferred(d) else { return 0 }
            let mine = fromPath.split(separator: "/").dropLast(), theirs = d.path.split(separator: "/").dropLast()
            return theirs.count <= mine.count && zip(mine, theirs).allSatisfy({ $0 == $1 }) ? theirs.count : 0
        }
        let candidates = repo == nil ? defs : defs.filter { !$0.rule.isWeak || isPreferred($0) }
        let ordered = candidates.enumerated().sorted { a, b in
            let ka = (a.element.rule.isWeak ? 1 : 0, isPreferred(a.element) ? 0 : 1, -nearness(a.element), a.offset)
            let kb = (b.element.rule.isWeak ? 1 : 0, isPreferred(b.element) ? 0 : 1, -nearness(b.element), b.offset)
            return ka < kb
        }.map(\.element)
        guard !ordered.isEmpty else {
            return Resolution(query: query, kind: .undefined, key: key, definitions: [],
                              mentions: index.mentions[key], alternatives: [])
        }
        var r = Resolution(query: query, kind: kind, key: key, definitions: ordered,
                           mentions: index.mentions[key], alternatives: [])
        if repo != nil, let first = ordered.first { r.fromOtherRepo = !isPreferred(first) }
        return r
    }

    /// The longest known repo name that appears as a word in `text`.
    public func repoNamed(in text: String) -> String? {
        let lower = text.lowercased()
        return repoNames.first { name in
            guard name.count >= 4, let r = lower.range(of: name.lowercased()) else { return false }
            let before = r.lowerBound == lower.startIndex ? " " : lower[lower.index(before: r.lowerBound)]
            let after = r.upperBound == lower.endIndex ? " " : lower[r.upperBound]
            return !(before.isLetter || before.isNumber) && !(after.isLetter || after.isNumber)
        }
    }
}
