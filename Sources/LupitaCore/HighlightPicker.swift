import CoreGraphics
import Foundation

/// Which OCR words Lupita could explain, for the highlight mode (D39). Only what is cheap to check:
/// indexed IDs, glossary terms and the fixed dictionaries (git/shell commands, error names), repo names
/// (D48), files that exist in a repo (D49, a check on disk), and what is told by its shape or one cheap check
/// (D51): colours, local addresses, `PR #12`, CSS tokens, Claude commands and package scripts. Never symbols,
/// commits or branches: they cost a search in the repos for every word.
public enum HighlightPicker {
    /// A box per known word or phrase, in the same coordinates as the words. Phrases of 2 to 4 words
    /// (`fast-forward merge`, `git stash`) give one box.
    public static func marks(words: [OCRWord], resolver: Resolver) -> [CGRect] {
        classified(words: words, resolver: resolver).map(\.box)
    }

    /// Reads the repos' CSS tokens (D51) while the window is read, so the marks do not wait for them:
    /// cold they take tens of milliseconds, warm they are a lookup. Call off the main thread.
    public static func warm(resolver: Resolver) {
        for repo in resolver.index.repos { _ = CodeRefs.Tokens.table(for: repo) }
    }

    // MARK: Second layer: symbols (D53)

    /// The words shaped like code symbols (`build_glyphs`, `ARM_TENSION`, `bakeBowlStemOpen`, `slider()`, or in
    /// a code font) that no first-layer mark covers, by name. Looking one up costs a search through the repos'
    /// source files (about 0.1 s), so these are underlined after the rest, as each lookup comes back.
    public static func symbolCandidates(words: [OCRWord], excluding marks: [Mark]) -> [String: [CGRect]] {
        var out: [String: [CGRect]] = [:]
        for word in words where !marks.contains(where: { $0.box.intersects(word.box) }) {
            let text = CodeRefs.Text(text: clean(word.text), codeMarked: word.codeStyled, before: "")
            guard let name = CodeRefs.Symbols.symbolName(text) else { continue }
            // Only the name itself: `obj.method()` marks the whole word, as the tooltip shows the method.
            out[name, default: []].append(trimmed(ArraySlice([word])))
        }
        return out
    }

    /// Looks the candidates up in parallel and calls `found` with the marks of each name defined in a repo, in
    /// the order the answers come back (on a background thread). `stop` is checked before each lookup, so
    /// letting go of the shortcut drops what has not started.
    /// `near`: the pointer; the names closest to it are looked up first, and past `maxSymbolLookups` the far ones wait.
    public static func findSymbols(_ candidates: [String: [CGRect]], resolver: Resolver, near: CGPoint? = nil,
                                   stop: @escaping @Sendable () -> Bool, found: @escaping @Sendable ([Mark]) -> Void) {
        func distance(_ name: String) -> CGFloat {
            guard let near else { return 0 }
            return candidates[name]?.map { hypot($0.midX - near.x, $0.midY - near.y) }.min() ?? .greatestFiniteMagnitude
        }
        let names = Array(candidates.keys.sorted().sorted { distance($0) < distance($1) }.prefix(maxSymbolLookups))
        let repos = resolver.index.repos
        DispatchQueue.concurrentPerform(iterations: names.count) { i in
            guard !stop() else { return }
            let text = CodeRefs.Text(text: names[i], codeMarked: true, before: "")
            guard CodeRefs.Symbols.resolve(text, repos: repos, preferredRepo: nil) != nil else { return }
            found((candidates[names[i]] ?? []).map { Mark(box: $0, kind: .id) })
        }
    }

    /// A window full of code (an editor) has hundreds of names: past this many the rest stay unmarked.
    public static let maxSymbolLookups = 60

    /// What a mark points at: an ID defined in the repos (solid line) or a term, a word Lupita explains
    /// (dashed line).
    public enum Kind: Sendable { case id, term }

    public struct Mark: Sendable, Equatable {
        public let box: CGRect
        public let kind: Kind
    }

    /// The marks with what each one is, so IDs and terms can be underlined differently.
    public static func classified(words: [OCRWord], resolver: Resolver) -> [Mark] {
        var marks: [Mark] = []
        for row in rows(of: words) {
            let block = nearbyText(of: row[0], in: words)
            var i = 0
            while i < row.count {
                // `PR #123`: one solid mark for both words (D51).
                if i + 1 < row.count, clean(row[i].text).uppercased() == "PR", CodeRefs.matches(prNumber, clean(row[i + 1].text)) {
                    marks.append(Mark(box: trimmed(row[i...i + 1]), kind: .id))
                    i += 2
                } else if i + 1 < row.count, row[i].text.hasSuffix(":"), row[i + 1].box.minX - row[i].box.maxX < row[i].box.height,
                          CodeRefs.matches(CodeRefs.Addresses.shape, clean(row[i].text + row[i + 1].text)) {
                    // In a code font OCR reads `localhost:8130` as two words, `localhost:` and `8130`.
                    marks.append(Mark(box: trimmed(row[i...i + 1]), kind: .term))
                    i += 2
                } else if let length = wordIDLength(row, at: i, resolver: resolver) {
                    // `Task 2.3`, `Requirement 3`: one solid mark for the word and its number.
                    marks.append(Mark(box: trimmed(row[i..<i + length]), kind: .id))
                    i += length
                } else if let length = phraseLength(row, at: i, resolver: resolver, block: block) {
                    marks.append(Mark(box: trimmed(row[i..<i + length]), kind: .term))
                    i += length
                } else {
                    let before = row[..<i].map(\.text).joined(separator: " ")
                    if let kind = kind(of: row[i].text, resolver: resolver, block: block, marked: row[i].codeStyled, before: before) {
                        marks.append(Mark(box: trimmed(row[i...i]), kind: kind))
                    }
                    i += 1
                }
            }
        }
        let all = rows(of: words)
        return marks + brokenAcrossLines(all, resolver: resolver, words: words) + wordFormsAcrossLines(all, resolver: resolver)
    }

    /// A row cut into the stretches of text that sit side by side (a sidebar, the chat, a panel): a gap wider than
    /// three line heights starts a new one.
    static func runs(of row: [OCRWord]) -> [[OCRWord]] {
        var out: [[OCRWord]] = []
        for word in row {
            if let last = out.last?.last, word.box.minX - last.box.maxX <= word.box.height * 3 { out[out.count - 1].append(word) }
            else { out.append([word]) }
        }
        return out
    }

    /// The rows right below row `n`: the next few. A sidebar item sits a few points lower than the text beside it, so it can
    /// make a row of its own between two lines of the same paragraph.
    static func rowsBelow(_ rows: [[OCRWord]], _ n: Int) -> [[OCRWord]] {
        Array(rows[min(n + 1, rows.count)..<min(n + 5, rows.count)])
    }

    /// `Requirement` at the end of a line and `3` at the start of the next: one solid mark on each half when the
    /// two make a numbered form with a word that a repo defines. Only between stretches right below each other
    /// that start at the same column (the rows also hold the sidebar and whatever else is on the same screen line).
    static func wordFormsAcrossLines(_ rows: [[OCRWord]], resolver: Resolver) -> [Mark] {
        var marks: [Mark] = []
        for (n, row) in rows.enumerated() {
            for run in runs(of: row) {
                guard let end = run.last, let first = run.first else { continue }
                for next in rowsBelow(rows, n).flatMap({ runs(of: $0) }) {
                    guard let start = next.first, abs(start.box.minX - first.box.minX) <= end.box.height * 3,
                          start.box.minY - end.box.maxY < end.box.height * 1.2, start.box.minY > end.box.minY else { continue }
                    if let halves = wordFormHalves(tail: run, head: next, resolver: resolver) {
                        marks.append(Mark(box: trimmed(ArraySlice(halves.0)), kind: .id))
                        marks.append(Mark(box: trimmed(ArraySlice(halves.1)), kind: .id))
                    }
                }
            }
        }
        return marks
    }

    private static func wordFormHalves(tail: [OCRWord], head: [OCRWord], resolver: Resolver) -> ([OCRWord], [OCRWord])? {
        for t in 1...min(2, tail.count) {
            for h in 1...min(2, head.count) where t + h <= 3 {
                let tailWords = Array(tail.suffix(t)), headWords = Array(head.prefix(h))
                // Words that end a sentence or a phrase do not run on into the next line.
                if tailWords.contains(where: closes) || headWords.dropLast().contains(where: closes) { continue }
                let cleaned = (tailWords + headWords).map { clean($0.text) }
                guard !cleaned.contains(where: \.isEmpty), cleaned[0].first?.isUppercase == true,
                      resolver.resolveWordID(cleaned.joined(separator: " ")) != nil else { continue }
                return (tailWords, headWords)
            }
        }
        return nil
    }

    /// A word split at the end of a line with a hyphen (`fast-` / `forward`): both halves are marked when the
    /// joined word is known (D51). Only between rows right below each other, and the stretch that continues it
    /// starts where the stretch that ends in the hyphen starts (the row also holds a sidebar or a panel that
    /// would otherwise be taken for the next word). A list that omits the prefix (`FR-` / `001, 002 y 003`) marks
    /// the numbers that follow the first too.
    static func brokenAcrossLines(_ rows: [[OCRWord]], resolver: Resolver, words: [OCRWord]) -> [Mark] {
        var marks: [Mark] = []
        for (n, row) in rows.enumerated() {
            var pairs: [(end: OCRWord, head: [OCRWord])] = []
            for run in runs(of: row) {
                guard let end = run.last, let first = run.first else { continue }
                for next in rowsBelow(rows, n).flatMap({ runs(of: $0) }) {
                    guard let start = next.first, abs(start.box.minX - first.box.minX) <= end.box.height * 3 else { continue }
                    pairs.append((end, next))
                }
            }
            if let end = row.last, let next = rows.indices.contains(n + 1) ? rows[n + 1].first : nil { pairs.append((end, [next])) }
            var done = Set<CGFloat>()
            for (end, head) in pairs {
                guard let start = head.first, end.text.hasSuffix("-"), !end.text.hasSuffix("--"),
                      start.box.minY - end.box.maxY < end.box.height * 1.2, start.box.minY > end.box.minY,
                      done.insert(end.box.minX).inserted else { continue }
                let joined = clean(end.text) + clean(start.text)
                let block = nearbyText(of: end, in: words) + " " + nearbyText(of: start, in: words)
                guard let kind = kind(of: joined, resolver: resolver, block: block, marked: end.codeStyled) else { continue }
                marks.append(Mark(box: trimmed([end][...]), kind: kind))
                marks.append(Mark(box: trimmed(head[0...0]), kind: kind))
                // `FR-` / `001, 002 y 003`: the numbers after the first inherit the prefix.
                var written = end.text + head[0].text
                for word in head.dropFirst() {
                    let cleaned = clean(word.text)
                    defer { written += " " + word.text }
                    guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isASCII && $0.isNumber }) else { continue }
                    if let id = Resolver.inheritedID(cleaned, context: written + " ", block: nil), resolver.index.definitions[id.key] != nil {
                        marks.append(Mark(box: trimmed([word][...]), kind: .id))
                    }
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

    static let trailing = CharacterSet(charactersIn: ".,;:!?…)]}\"'`*»”’")
    static let leading = CharacterSet(charactersIn: "([{\"'`*«“‘")

    /// Words on the same line, left to right.
    public static func rows(of words: [OCRWord]) -> [[OCRWord]] {
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

    /// 3 to 2 words from `i` that are a numbered form with a word (`Task Group 2`, `Requirement 3`) some repo defines.
    static func wordIDLength(_ row: [OCRWord], at i: Int, resolver: Resolver) -> Int? {
        for length in stride(from: 3, through: 2, by: -1) where i + length <= row.count {
            let slice = row[i..<i + length]
            if slice.dropLast().contains(where: closes) { continue }
            let gapLimit = (slice.first?.box.height ?? 0) * 1.5
            if zip(slice, slice.dropFirst()).contains(where: { $1.box.minX - $0.box.maxX > gapLimit }) { continue }
            guard let first = slice.first, clean(first.text).first?.isUppercase == true else { continue }
            if resolver.resolveWordID(slice.map { clean($0.text) }.joined(separator: " ")) != nil { return length }
        }
        return nil
    }

    /// 4 to 2 words from `i` that name a glossary term or a dictionary command, longest first.
    static func phraseLength(_ row: [OCRWord], at i: Int, resolver: Resolver, block: String) -> Int? {
        for length in stride(from: 4, through: 2, by: -1) where i + length <= row.count {
            let slice = row[i..<i + length]
            // A phrase does not close early and does not jump a column gap.
            if slice.dropLast().contains(where: closes) { continue }
            let gapLimit = (slice.first?.box.height ?? 0) * 1.5
            if zip(slice, slice.dropFirst()).contains(where: { $1.box.minX - $0.box.maxX > gapLimit }) { continue }
            let cleaned = slice.map { clean($0.text) }
            // A word that cleans to nothing (a lone `(` or `**`) is no part of a phrase: `( Task` is not the term `Task`
            // starting one word early, which also hid the `Task 2.3` that follows.
            if cleaned.contains(where: \.isEmpty) { continue }
            let phrase = cleaned.joined(separator: " ")
            if resolver.resolveTerm(phrase) != nil { return length }
            // `npm run build`: a script that exists in a repo's package.json, or a known package command.
            let parts = phrase.split(separator: " ")
            // A word that cleans to nothing (a lone `-` or `|`) leaves fewer parts than words.
            guard parts.count == length else { continue }
            if CodeDictionaries.managers.contains(parts[0].lowercased()), length == (["run", "run-script"].contains(parts[1]) ? 3 : 2),
               CodeRefs.Commands.resolve(CodeRefs.Text(text: phrase, codeMarked: false, before: ""), repos: resolver.index.repos, preferredRepo: nil) != nil {
                return length
            }
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
        kind(of: text, resolver: resolver, block: block, marked: marked) != nil
    }

    /// `before`: the words to the left on the same line, the hint a bare `401` needs (`HTTP 401`).
    static func kind(of text: String, resolver: Resolver, block: String, marked: Bool = false, before: String = "") -> Kind? {
        let word = clean(text)
        guard word.count >= 2 else { return nil }
        if let found = known(word, resolver: resolver, block: block, marked: marked, before: before) { return found }
        // OCR misreads one of a pair of «» as a letter: the opening one as `k` (`kstashear»`), the closing one as
        // `s` (`«stashears`). With only one of the pair read, the letter on the other end is retried without it.
        let opens = text.contains("«"), closes = text.contains("»")
        if closes, !opens, word.first == "k" || word.first == "K" {
            return known(String(word.dropFirst()), resolver: resolver, block: block, marked: marked, before: before)
        }
        if opens, !closes, word.last == "s" {
            return known(String(word.dropLast()), resolver: resolver, block: block, marked: marked, before: before)
        }
        return nil
    }

    static let colour = try! NSRegularExpression(pattern: #"^#(?:[0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#)
    static let prNumber = try! NSRegularExpression(pattern: #"^#\d{1,6}$"#)

    private static func known(_ word: String, resolver: Resolver, block: String, marked: Bool, before: String) -> Kind? {
        guard word.count >= 2 else { return nil }
        let repos = resolver.index.repos
        // `002` in `FR-001, 002`, even when the list wraps to the next line: an ID defined somewhere.
        if IDGrammar.parse(word) == nil, let id = Resolver.inheritedID(word, context: before, block: block),
           resolver.index.definitions[id.key] != nil { return .id }
        // A tracker key no file defines is underlined when some repo has a commit that cites it.
        if let id = IDGrammar.parse(word), IDGrammar.isTrackerKey(id.display), resolver.index.definitions[id.key] == nil,
           resolver.hasTrackerCommit(id) { return .id }
        if let id = IDGrammar.parse(word), IDGrammar.adrAliases(of: id.key).contains(where: { resolver.index.definitions[$0] != nil }) { return .id }
        if resolver.rangeList(word) != nil { return .id }
        // A repo name points at a place, like an ID. A plain lowercase name (`app`, `nib`) needs its exact case, so
        // it does not mark every «app»; any other (`LiOS`, `vector-ui-studio`) any case, as OCR reads `LiOS` as `LioS`.
        if word.count >= 3, resolver.index.repos.contains(where: { repo in
            repo.name.allSatisfy(\.isLowercase) ? repo.name == word : repo.name.caseInsensitiveCompare(word) == .orderedSame
        }) { return .id }
        // A file or folder of a repo (`docs/decisions.md`, `CLAUDE.md:12`): also a place. Checked on disk only (D49).
        if RepoRefs.isFile(word, repos: resolver.index.repos, byName: resolver.index.markdownByName) { return .id }
        if resolver.resolveTerm(word) != nil { return .term }
        // Error names, HTML tags (`<dialog>`) and HTTP statuses with their hint: fixed tables, as cheap as a term.
        let code = CodeRefs.Text(text: word, codeMarked: marked, before: before)
        if CodeRefs.Errors.resolve(code, repos: [], preferredRepo: nil) != nil { return .term }
        if let command = CodeDictionaries.command(word.lowercased()), command.safe { return .term }
        if GitVocabulary.knows(word, block: block, marked: marked) { return .term }
        return byShape(word, repos: repos, before: before)
    }

    /// D51: what the tooltip explains from its shape (a colour, a local address: always an answer, dashed) or
    /// after one cheap check of something in the repos (a token's declaration, a command's file: solid).
    /// `PR #12` needs the word before; a bare `#12` could be anything.
    static func byShape(_ word: String, repos: [Repo], before: String) -> Kind? {
        if CodeRefs.matches(prNumber, word), CodeRefs.matches(CodeRefs.prWord, before) { return .id }
        if CodeRefs.matches(colour, word), !word.dropFirst().allSatisfy(\.isNumber) { return .term }
        if CodeRefs.matches(CodeRefs.Addresses.shape, word) { return .term }
        if let g = CodeRefs.groups(CodeRefs.Tokens.tokenName, word) {
            return CodeRefs.Tokens.token(g[1], repos: repos) != nil ? .id : nil
        }
        if CodeRefs.matches(RepoRefs.command, word) {
            return RepoRefs.commands(String(word.dropFirst()), repos: repos).isEmpty ? nil : .id
        }
        return nil
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
