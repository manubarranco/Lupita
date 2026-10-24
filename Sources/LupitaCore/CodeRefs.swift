import Foundation

/// What agents cite from code (D29): symbols, local addresses, CSS tokens and colours, terminal
/// commands, errors and HTML tags, PRs. Like D19 it is looked up when the user points, never indexed
/// and never with a language model (D26), so there is nothing to keep fresh.
/// The order of the types is a priority: if time runs short, the ones at the bottom are cut first.
public enum CodeRefs {
    /// What surrounds the pointed text. Code is recognised partly by its surroundings: `slider` alone is a
    /// word, `` `slider` `` and `slider()` are code.
    struct Text {
        /// The pointed text without wrappers and trailing punctuation (`var(--accent)` stays whole).
        let text: String
        /// Between backticks, or called like a function: the writer meant code.
        let codeMarked: Bool
        /// Up to 80 characters before, for the types that need a hint from the sentence (`HTTP 401`).
        let before: String
    }

    static let wrappers = CharacterSet(charactersIn: "`\"'“”‘’«»[]{}*")
    static let trailing = CharacterSet(charactersIn: ".,;:!?…")

    /// The code reference `raw` names, or nil. `before` / `after` are the text around it on its line.
    public static func resolve(_ raw: String, repos: [Repo], preferredRepo: String?,
                               before: String? = nil, after: String? = nil) -> Resolution? {
        guard let text = normalize(raw, before: before ?? "", after: after ?? "") else { return nil }
        let ordered = order(repos, preferredRepo)
        var defs: [Definition]?
        // 6 PRs, 5 errors and tags, 4 commands are cheap or exact: they run first when they match exactly,
        // but the priority above decides what gets built and what is cut.
        defs = defs ?? Errors.resolve(text, repos: ordered, preferredRepo: preferredRepo)
        defs = defs ?? Symbols.resolve(text, repos: ordered, preferredRepo: preferredRepo)
        defs = defs ?? Addresses.resolve(text, repos: ordered, preferredRepo: preferredRepo)
        defs = defs ?? Tokens.resolve(text, repos: ordered, preferredRepo: preferredRepo)
        defs = defs ?? Commands.resolve(text, repos: ordered, preferredRepo: preferredRepo)
        guard let found = defs, let first = found.first else { return nil }
        var r = Resolution(query: text.text, kind: .exact, key: first.key, definitions: Array(found.prefix(5)),
                           mentions: nil, alternatives: [])
        if let preferredRepo, repos.contains(where: { $0.name.caseInsensitiveCompare(preferredRepo) == .orderedSame }) {
            let home = first.repo.components(separatedBy: " · ").first ?? first.repo
            r.fromOtherRepo = (first.rule == .symbol || first.rule == .token || (first.rule == .terminal && !first.repo.isEmpty)) && home.caseInsensitiveCompare(preferredRepo) != .orderedSame
        }
        return r
    }

    /// `localhost:8130`, `http://127.0.0.1:8131/x.html`: checked before repo references, which would
    /// otherwise treat a URL as a branch name and ask git about it in every repo.
    public static func looksLikeAddress(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(wrappers))
        return matches(Addresses.shape, text.trimmingCharacters(in: trailing))
    }

    /// `npm run build`, `git status`: a known tool and at least one argument. Checked before repo references,
    /// which would take `git checkout a/b` for a branch name and ask git about it in every repo.
    public static func looksLikeCommand(_ raw: String) -> Bool {
        let tokens = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(wrappers)).split(whereSeparator: \.isWhitespace)
        guard tokens.count >= 2, let first = tokens.first.map(String.init) else { return false }
        return CodeDictionaries.managers.contains(first) || first == "git"
    }

    static func normalize(_ raw: String, before: String, after: String) -> Text? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var marked = text.contains("`") || before.hasSuffix("`") || after.hasPrefix("`")
        text = text.trimmingCharacters(in: wrappers)
        while let last = text.unicodeScalars.last, trailing.contains(last) { text.removeLast() }
        text = text.trimmingCharacters(in: wrappers)
        guard !text.isEmpty, text.count <= 300 else { return nil }
        // `simplify` followed by `(` in the line (the picker splits words at parentheses).
        if after.hasPrefix("(") { marked = true }
        return Text(text: text, codeMarked: marked, before: String(before.suffix(80)))
    }

    /// The window's repo first, then the rest in their given order.
    static func order(_ repos: [Repo], _ preferredRepo: String?) -> [Repo] {
        guard let preferredRepo else { return repos }
        return repos.filter { $0.name.caseInsensitiveCompare(preferredRepo) == .orderedSame }
            + repos.filter { $0.name.caseInsensitiveCompare(preferredRepo) != .orderedSame }
    }

    static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    static func groups(_ regex: NSRegularExpression, _ text: String) -> [String]? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
    }
}
