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
    /// A range of IDs (D41): the tooltip lists what it spans instead of showing definitions.
    public var range: RangeList?
    /// A tracker key whose commit is still being searched for: the card shows the key now and is replaced by
    /// `Resolver.trackerResolution` when git answers (or closed when it has nothing).
    public var isPending = false

    /// The tooltip shows it (anything else says «not a known reference»).
    public var isShown: Bool { [.exact, .corrected, .ambiguous].contains(kind) && !definitions.isEmpty }

    /// D13: a short ID reached only through OCR correction is shown as "did you mean…?".
    public var isSuggestion: Bool { kind == .corrected && (key?.count ?? 0) < 4 }
}

public struct Resolver: Sendable {
    public let index: RefIndex
    /// Longest first, so `harbor-web` wins over a shorter name inside it (`harbor`).
    let repoNames: [String]
    /// Off: no git command runs inside `resolve`; a tracker key nothing defines stays `undefined` and the caller asks
    /// `trackerResolution` off the main thread (the app), or a highlight pass reads only the cached answers.
    public private(set) var searchesGit = true
    /// The one place a tracker key is searched in a repo's history; replaced by tests to make git slow.
    var commitSearch: @Sendable (String, Repo, TimeInterval) -> Definition? = { RepoRefs.commitCiting($0, repo: $1, timeout: $2) }

    /// The same resolver, without git commands inside `resolve`.
    public func withoutGit() -> Resolver {
        var copy = self
        copy.searchesGit = false
        return copy
    }

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
    static let maxCorrectableLength = 16

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
    ///   - after: the text right after `raw` on its line (the picker splits at `(`: `simplify()` is a call).
    ///   - codeStyled: drawn as inline code (a code box on screen, or a monospaced font): like backticks.
    ///   - block: the text around `raw` (its line, or the lines near it): the git package (D42) needs it to tell
    ///     `push` the git word from `push` the English one.
    public func resolve(_ raw: String, preferredRepo: String? = nil, context: String? = nil,
                        fromPath: String? = nil, after: String? = nil, block: String? = nil, codeStyled: Bool = false) -> Resolution {
        // A repo named in the text beats one named in the file path (`domains/harbor-log.md`),
        // which beats the window's repo.
        let named = context.flatMap(repoNamed(in:)) ?? fromPath.flatMap(repoNamed(in:)).flatMap { $0 == preferredRepo ? nil : $0 }
        let fromPath = named == nil || named == preferredRepo ? fromPath : nil
        let preferredRepo = named ?? preferredRepo
        if let list = rangeList(raw, preferredRepo: preferredRepo, fromPath: fromPath) {
            let defs = list.entries.compactMap(\.definition)
            var r = Resolution(query: raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), kind: .exact,
                               key: defs.first?.key, definitions: defs, mentions: nil, alternatives: [])
            r.range = list
            return r
        }
        if CodeRefs.looksLikeAddress(raw) || CodeRefs.looksLikeCommand(raw),
           let code = CodeRefs.resolve(raw, repos: index.repos, preferredRepo: preferredRepo, before: context, after: after, codeStyled: codeStyled) {
            return code
        }
        // Commits, branches, files and commands never look like IDs: no OCR correction for them.
        if let ref = RepoRefs.resolve(raw, repos: index.repos, preferredRepo: preferredRepo, byName: index.markdownByName) { return ref }
        // A bar glued to a letter or digit is a misread 1 (`D|` for `D1`), not punctuation.
        let bars = raw.replacingOccurrences(of: #"(?<=[A-Za-z0-9])\|"#, with: "1", options: .regularExpression)
        let query = Self.latinize(bars.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        if let id = IDGrammar.parse(query) ?? Self.inheritedID(query, context: context, block: block) {
            let (key, defs) = scopedDefinitions(for: id, preferredRepo: preferredRepo, fromPath: fromPath)
            if !defs.isEmpty { return result(query, .exact, key: key, defs, preferredRepo, fromPath, ownFileFirst: id.scope != .none) }
            // A tracker key no file defines: the commit that cites it (window's repo first, then the other repos).
            if searchesGit, let r = trackerResolution(query: query, id: id, preferredRepo: preferredRepo) { return r }
        }
        // Code (D29) comes after IDs and repo references and before glossary terms: a name that is both a
        // term and a symbol is a term unless the text is shaped like code.
        if let code = CodeRefs.resolve(raw, repos: index.repos, preferredRepo: preferredRepo, before: context, after: after, codeStyled: codeStyled) {
            return code
        }
        // A glossary term (D22) comes after IDs, repo references and code. For text that is not shaped
        // like an ID it also comes before the OCR corrections; ID-shaped text tries the
        // corrections first and falls back to a term only when nothing defines the ID.
        let idShaped = IDGrammar.parse(query) != nil
        if !idShaped, let term = termResolution(raw, preferredRepo: preferredRepo) { return term }

        // A word made only of digits (`002`) is a number, not an ID misread by OCR: no "did you mean D02". It is
        // an ID only inside a list (`FR-001, 002`), which was tried above.
        let digitsOnly = !query.isEmpty && query.allSatisfy { $0.isASCII && $0.isNumber }

        // Fewest substitutions first; stop at the first distance that yields any match.
        // An ID is short: trying every look-alike swap of a long word (`FontBuilder`) found nothing and cost ~0.5 s.
        for distance in 1...Self.maxSubstitutions where query.count <= Self.maxCorrectableLength && !digitsOnly {
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
        let tailKeys = Set((digitsOnly ? [] : numericTailReadings(of: query)).compactMap { variant -> String? in
            guard let key = IDGrammar.parse(variant)?.key, index.definitions[key] != nil else { return nil }
            return key
        })
        if tailKeys.count == 1, let key = tailKeys.first {
            return result(query, .corrected, key: key, index.definitions[key]!, preferredRepo, fromPath)
        }

        if idShaped, let term = termResolution(raw, preferredRepo: preferredRepo) { return term }
        // The git package (D42) is last: it only speaks when nothing else knows the word.
        let marked = codeStyled || raw.contains("`") || (context?.hasSuffix("`") ?? false) || (after?.hasPrefix("`") ?? false)
        if let git = resolveGit(raw, block: block ?? [context, raw, after].compactMap { $0 }.joined(separator: " "), marked: marked) { return git }
        if let id = IDGrammar.parse(query) {
            return Resolution(query: query, kind: .undefined, key: id.key, definitions: [],
                              mentions: index.mentions[id.key], alternatives: [])
        }
        return Resolution(query: query, kind: .notAnID, key: nil, definitions: [], mentions: nil, alternatives: [])
    }

    /// The card for a tracker key some commit cites, or nil. Runs git: never call it on the main thread. The window's
    /// repo comes first; the other repos, flagged, share one second.
    public func trackerResolution(query: String, id: RefID, preferredRepo: String?) -> Resolution? {
        if let commit = trackerCommit(for: id, preferredRepo: preferredRepo) {
            return Resolution(query: query, kind: .exact, key: id.key, definitions: [commit], mentions: nil, alternatives: [])
        }
        if IDGrammar.isTrackerKey(id.display), let commit = trackerCommitElsewhere(for: id, except: preferredRepo) {
            var r = Resolution(query: query, kind: .exact, key: id.key, definitions: [commit], mentions: nil, alternatives: [])
            r.fromOtherRepo = preferredRepo != nil
            return r
        }
        return nil
    }

    /// Whether a pass with git off met a tracker key whose answer is not cached (read once, then cleared): the caller then
    /// repeats the pass with git on, off the main thread, and adds the marks that were missing.
    public static func takeUncachedTrackerKeys() -> Bool { TrackerCache.takeMisses() }

    /// The key to search for when `resolution` is an `undefined` tracker key and git was off; nil for anything else.
    public func pendingTrackerKey(_ resolution: Resolution) -> RefID? {
        guard !searchesGit, resolution.kind == .undefined, let id = IDGrammar.parse(resolution.query),
              IDGrammar.isTrackerKey(id.display), !index.repos.isEmpty else { return nil }
        return id
    }

    /// The card shown at once for a tracker key while git searches: the key and «looking for the commit».
    public func pendingResolution(for resolution: Resolution, preferredRepo: String?) -> Resolution {
        let repo = index.repos.first { $0.name.caseInsensitiveCompare(preferredRepo ?? "") == .orderedSame } ?? index.repos.first
        let d = Definition(id: resolution.query, key: resolution.key ?? resolution.query, repo: repo?.name ?? "", path: "", line: 0,
                           rule: .commit, title: S.lookingForCommit, summary: "\u{A0}", absolutePath  // the blank line keeps the card the size it will have: repo?.path ?? "")
        var r = Resolution(query: resolution.query, kind: .exact, key: resolution.key, definitions: [d], mentions: nil, alternatives: [])
        r.isPending = true
        return r
    }

    /// The latest commit (or branch) of the window's repo that names the tracker key `id`, or nil: no repo, no
    /// commit, or a key that is not shaped like one. A definition in a `.md` always wins over this.
    public func trackerCommit(for id: RefID, preferredRepo: String?) -> Definition? {
        guard let preferredRepo, IDGrammar.isTrackerKey(id.display),
              let repo = index.repos.first(where: { $0.name.caseInsensitiveCompare(preferredRepo) == .orderedSame })
        else { return nil }
        return commitSearch(id.display, repo, RepoRefs.keySearchTimeout)
    }

    /// Whether some repo has a commit (or branch) that names the tracker key: what the highlight needs to underline `PLAT-443341`.
    /// A git search per word on every pass would be slow, so answers are kept for half a minute.
    public func hasTrackerCommit(_ id: RefID, preferredRepo: String? = nil) -> Bool {
        guard IDGrammar.isTrackerKey(id.display) else { return false }
        // Without git, only an answer already known: an unknown key is noted for a later pass off the main thread.
        if !searchesGit { return TrackerCache.cached(id.display) ?? { TrackerCache.noteMiss(); return false }() }
        return TrackerCache.answer(for: id.display) {
            trackerCommit(for: id, preferredRepo: preferredRepo) != nil || trackerCommitElsewhere(for: id, except: preferredRepo) != nil
        }
    }

    /// The commit of any other repo that names the key; the search of all of them shares one second.
    func trackerCommitElsewhere(for id: RefID, except preferredRepo: String?) -> Definition? {
        let deadline = Date().addingTimeInterval(RepoRefs.keySearchTimeout)
        for repo in index.repos where repo.name.caseInsensitiveCompare(preferredRepo ?? "") != .orderedSame {
            guard Date() < deadline else { return nil }
            if let d = commitSearch(id.display, repo, deadline.timeIntervalSinceNow) { return d }
        }
        return nil
    }

    /// A bare number that ends a list with an omitted prefix (`PU-02, 03 y 26` with the pointer on `03`): the ID it
    /// inherits, read from the text before it, or nil.
    static func inheritedID(_ rawWord: String, context: String?, block: String? = nil) -> RefID? {
        let word = IDGrammar.digitsBeforeJunk(rawWord) ?? rawWord
        guard word.count >= 1, word.count <= 4, word.allSatisfy(\.isASCII), word.allSatisfy(\.isNumber) else { return nil }
        func inherited(_ before: String) -> RefID? {
            let text = before + (before.last?.isWhitespace ?? true ? "" : " ") + word
            guard let last = IDGrammar.tokens(in: text).last, last.id.scope == .folder, last.id.display == word,
                  last.range.location + last.range.length == (text as NSString).length else { return nil }
            return last.id
        }
        if let context, let id = inherited(context) { return id }
        // The list is broken across lines (`FR-` / `001, 002`): the text around the word, joined, still has its start.
        guard let block else { return nil }
        let joined = block.replacingOccurrences(of: #"-\s+(?=\d)"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        var from = joined.startIndex
        while let r = joined.range(of: word, range: from..<joined.endIndex) {
            if r.lowerBound > joined.startIndex, joined[joined.index(before: r.lowerBound)] == " ",
               let id = inherited(String(joined[..<r.lowerBound])) { return id }
            from = r.upperBound
        }
        return nil
    }

    /// A numbered form with a word (`Requirement 3`, `Task Group 2`) for `phrase`, or nil. Public so the picker
    /// can try windows of words.
    public func resolveWordID(_ phrase: String, preferredRepo: String? = nil, context: String? = nil,
                              fromPath: String? = nil) -> Resolution? {
        let trimmed = Self.latinize(phrase.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        guard trimmed.contains(" "), let id = IDGrammar.parse(trimmed), id.scope != .none || id.prefix == "ADR" else { return nil }
        let named = context.flatMap(repoNamed(in:)) ?? fromPath.flatMap(repoNamed(in:)).flatMap { $0 == preferredRepo ? nil : $0 }
        let repo = named ?? preferredRepo
        let (key, defs) = scopedDefinitions(for: id, preferredRepo: repo, fromPath: named == nil || named == preferredRepo ? fromPath : nil)
        guard !defs.isEmpty else { return nil }
        return result(trimmed, .exact, key: key, defs, repo, named == nil || named == preferredRepo ? fromPath : nil, ownFileFirst: true)
    }

    /// The definitions a mention of `id` may take, and the key they are under. Forms with a scope take
    /// them from the mention's own repo and, with the file known, only from its folder or above (`.folder`) or from
    /// its first-level folder (`.topFolder`); with no file, all of the repo's, each with its file. A cited
    /// criterion (`Requirement 3.1`) falls back to the form one level up. Other forms: every definition.
    public func scopedDefinitions(for id: RefID, preferredRepo: String?, fromPath: String?) -> (key: String, defs: [Definition]) {
        if id.scope == .none {
            // The same ADR written with another padding is the same ADR.
            let aliases = IDGrammar.adrAliases(of: id.key)
            if aliases.count > 1 {
                let found = aliases.flatMap { index.definitions[$0] ?? [] }
                if !found.isEmpty {
                    return (aliases.first { !(index.definitions[$0] ?? []).isEmpty } ?? id.key, found)
                }
            }
            var key: String? = id.key
            while let k = key {
                if let defs = index.definitions[k], !defs.isEmpty { return (k, defs) }
                key = IDGrammar.parentKey(of: k)
            }
            return (id.key, [])
        }
        var key: String? = id.key
        while let k = key {
            let own = (index.definitions[k] ?? []).filter { d in
                guard let preferredRepo else { return true }
                return d.repo.caseInsensitiveCompare(preferredRepo) == .orderedSame
            }
            let kept: [Definition]
            if let fromPath {
                kept = own.filter { Self.reaches($0.path, from: fromPath, scope: id.scope) }
            } else {
                // The window does not say which file it shows: every definition of the repo is listed, each with
                // its file, instead of picking one that may belong to another spec.
                kept = own
            }
            // A task is defined by its line in `tasks.md`; the headings of reports about it come after.
            if !kept.isEmpty { return (k, k.hasPrefix("TASK ") ? kept.filter(Self.inTasksFile) + kept.filter { !Self.inTasksFile($0) } : kept) }
            key = IDGrammar.parentKey(of: k)
        }
        return (id.key, [])
    }

    static func inTasksFile(_ d: Definition) -> Bool { d.path.split(separator: "/").last?.lowercased() == "tasks.md" }

    /// What the tooltip lists for `id`, in order: scope, then the reader's own file, live before archived, nearest folder.
    public func shownDefinitions(for id: RefID, preferredRepo: String?, fromPath: String?) -> [Definition] {
        let (key, defs) = scopedDefinitions(for: id, preferredRepo: preferredRepo, fromPath: fromPath)
        return defs.isEmpty ? [] : result(id.display, .exact, key: key, defs, preferredRepo, fromPath, ownFileFirst: id.scope != .none).definitions
    }

    /// Folders of framework files that are not the project's own (BMAD ships examples under these).
    static let frameworkFolders: Set<String> = ["bmad", "_bmad", "skills"]

    static func reaches(_ definitionPath: String, from mentionPath: String, scope: IDScope) -> Bool {
        let theirs = definitionPath.split(separator: "/").dropLast(), mine = mentionPath.split(separator: "/").dropLast()
        switch scope {
        case .none: return true
        case .folder:
            return theirs.count <= mine.count && zip(mine, theirs).allSatisfy { $0 == $1 }
        case .topFolder:
            guard theirs.first == mine.first else { return false }
            return frameworkFolders.isDisjoint(with: theirs.map(String.init)) && frameworkFolders.isDisjoint(with: mine.map(String.init))
        }
    }

    /// A glossary term for `phrase` (one to four words), or nil. The repo of the window comes first;
    /// a term from another repo is flagged. Public so the picker can try longer windows (D23).
    public func resolveTerm(_ phrase: String, preferredRepo: String? = nil, context: String? = nil,
                            fromPath: String? = nil) -> Resolution? {
        let named = context.flatMap(repoNamed(in:)) ?? fromPath.flatMap(repoNamed(in:)).flatMap { $0 == preferredRepo ? nil : $0 }
        return termResolution(phrase, preferredRepo: named ?? preferredRepo)
    }

    /// Code made of several words (a command, `PR 123`) for `phrase`, or nil. Public so the picker can try
    /// windows of words (D29).
    public func resolveCode(_ phrase: String, preferredRepo: String? = nil, context: String? = nil) -> Resolution? {
        CodeRefs.resolve(phrase, repos: index.repos, preferredRepo: repoNamed(in: context ?? "") ?? preferredRepo, before: context)
    }

    private func termResolution(_ phrase: String, preferredRepo: String?) -> Resolution? {
        guard !index.terms.isEmpty else { return nil }
        for key in Glossary.lookupKeys(phrase) {
            guard let defs = index.terms[key], !defs.isEmpty else { continue }
            func isPreferred(_ d: Definition) -> Bool { preferredRepo.map { d.repo.caseInsensitiveCompare($0) == .orderedSame } ?? false }
            let ordered = defs.enumerated().sorted { a, b in
                (isPreferred(a.element) ? 0 : 1, a.offset) < (isPreferred(b.element) ? 0 : 1, b.offset)
            }.map(\.element)
            var r = Resolution(query: phrase.trimmingCharacters(in: .whitespacesAndNewlines), kind: .exact, key: key,
                               definitions: ordered, mentions: nil, alternatives: [])
            if preferredRepo != nil, let first = ordered.first { r.fromOtherRepo = !isPreferred(first) }
            return r
        }
        return nil
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
    func result(_ query: String, _ kind: Resolution.Kind, key: String, _ defs: [Definition],
                        _ repo: String?, _ fromPath: String?, ownFileFirst: Bool = false) -> Resolution {
        func isPreferred(_ d: Definition) -> Bool { repo.map { d.repo.caseInsensitiveCompare($0) == .orderedSame } ?? false }
        /// Depth of the definition's folder when it is the reader's folder or one of its parents.
        func nearness(_ d: Definition) -> Int {
            guard let fromPath, isPreferred(d) else { return 0 }
            let mine = fromPath.split(separator: "/").dropLast(), theirs = d.path.split(separator: "/").dropLast()
            return theirs.count <= mine.count && zip(mine, theirs).allSatisfy({ $0 == $1 }) ? theirs.count : 0
        }
        let candidates = repo == nil ? defs : defs.filter { !$0.rule.isWeak || isPreferred($0) }
        // A closed change (`openspec/changes/archive`) loses to a live definition, unless the reader is in the archive too.
        let readingArchive = fromPath?.split(separator: "/").contains("archive") ?? false
        func archived(_ d: Definition) -> Int { d.isArchived && !readingArchive ? 1 : 0 }
        // The reader's own file defines first: a plan that heads `### Task 2` is not about the `Task 2` of its neighbour.
        func ownFile(_ d: Definition) -> Int { ownFileFirst && isPreferred(d) && d.path == fromPath ? 0 : 1 }
        // A task's own line in `tasks.md` beats the headings of reports about it, even from a nearer folder.
        func tasksLine(_ d: Definition) -> Int { key.hasPrefix("TASK ") && Self.inTasksFile(d) ? 0 : 1 }
        let ordered = candidates.enumerated().sorted { a, b in
            func rank(_ x: (offset: Int, element: Definition)) -> [Int] {
                [x.element.rule.isWeak ? 1 : 0, isPreferred(x.element) ? 0 : 1, ownFile(x.element), tasksLine(x.element),
                 archived(x.element), -nearness(x.element), x.offset]
            }
            return rank(a).lexicographicallyPrecedes(rank(b))
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


/// Answers of the tracker-key searches, so the highlight does not run git on every pass.
enum TrackerCache {
    nonisolated(unsafe) private static var answers: [String: (found: Bool, at: Date)] = [:]
    private static let lock = NSLock()
    static let lifetime: TimeInterval = 30
    nonisolated(unsafe) private static var misses = 0

    /// The answer if it is known and fresh.
    static func cached(_ key: String) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        if let hit = answers[key], Date().timeIntervalSince(hit.at) < lifetime { return hit.found }
        return nil
    }
    static func noteMiss() { lock.lock(); misses += 1; lock.unlock() }
    /// Whether a no-git pass met a key with no answer yet since the last call.
    static func takeMisses() -> Bool { lock.lock(); defer { lock.unlock() }; let m = misses > 0; misses = 0; return m }

    static func answer(for key: String, compute: () -> Bool) -> Bool {
        lock.lock()
        if let hit = answers[key], Date().timeIntervalSince(hit.at) < lifetime { lock.unlock(); return hit.found }
        lock.unlock()
        let found = compute()
        lock.lock(); answers[key] = (found, Date()); lock.unlock()
        return found
    }
}
