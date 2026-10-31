import Foundation

/// Which way a `§N` found its document (D60).
public enum SectionRoute: String, Sendable {
    /// The sentence names the document: `spec §4.4`, `§3 of data-model`, `[spec](spec.md) §2`.
    case named
    /// The file being read has a heading numbered N.
    case ownFile
    /// The nearest folder going up that holds a document with a heading numbered N.
    case nearby
    /// The window does not say which file it shows: every document of the repo with that heading.
    case repoWide
}

/// Section references, `§4.7`: they point at a numbered heading (`## 4.7 Title`, `### §4.7 Title`) of a document.
/// Few of them name the document, so the reader's own file and its folders say which one it is.
public enum SectionRefs {
    /// `§4.7`, `§ 4`. A trailing `.` ends the sentence; a letter or a further `.N` makes it something else (`§4a`).
    static let tokenRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_§])§\s?(\d{1,3}(?:\.\d{1,3}){0,3})(?![A-Za-z0-9_]|\.\d)"#)
    /// `## 4.7 Title`, `### §4.7. Title`, `## 4. Title`: a heading numbered with a section number.
    static let numberedHeading = try! NSRegularExpression(
        pattern: #"^#{1,6}\s+§?\s?(\d{1,3}(?:\.\d{1,3}){0,3})\.?\s+(\S.*)$"#)
    static let linkBefore = try! NSRegularExpression(pattern: #"\]\(([^)\s#]+?)(?:#[^)\s]*)?\)[\s`*_]*$"#)
    static let wordBefore = try! NSRegularExpression(pattern: #"([A-Za-z][A-Za-z0-9_.\-/]*)(?:['’]s)?[\s`*_)\]"'’,:;]*$"#)
    static let after = try! NSRegularExpression(
        pattern: #"^[)\]`*_]*\s*(?:\(|,)?\s*(?:of|in|from|de|del|en)\s+(?:the\s+|la\s+|el\s+)?[`\[*_]*([A-Za-z][A-Za-z0-9_.\-/]*)"#,
        options: .caseInsensitive)

    /// Words that sit before a `§` without naming a document.
    static let notDocuments: Set<String> = [
        "in", "the", "of", "see", "and", "y", "en", "el", "la", "los", "las", "de", "del", "per", "cf", "to", "at", "from",
        "section", "sections", "sec", "art", "article", "a", "an", "with", "ver", "also", "this", "that", "its", "our",
        "or", "o", "para", "por", "on", "under", "above", "below", "vs", "e", "i", "ie", "eg", "see", "refs", "ref", "per",
        "según", "segun", "como", "al", "su", "sus", "una", "un", "es", "is", "are", "was", "see", "check", "read", "updated",
        "update", "adds", "added", "add", "fix", "fixes", "fixed", "implements", "implement", "covers", "cover", "defines",
        "define", "defined", "described", "per", "lines", "line", "page", "pages", "p", "pp", "chapter", "ch", "part",
    ]

    /// Section tokens of `text` with their UTF-16 ranges (the `§N`; the document is carried in `RefID.document`).
    static func tokens(in text: String, _ ns: NSString) -> [(id: RefID, range: NSRange)] {
        guard ns.range(of: "§").location != NSNotFound else { return [] }
        return tokenRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            let number = ns.substring(with: m.range(at: 1))
            var id = RefID(display: ns.substring(with: m.range), key: "§" + number, prefix: "§", scope: .section)
            id.document = document(before: ns.substring(to: m.range.location), after: ns.substring(from: m.range.location + m.range.length))
            return (id, m.range)
        }
    }

    /// The `§N` id of the word `raw` (as the picker reads it), with the document named before or after it.
    /// `context`: text before the word; `block`: its whole line.
    static func id(for raw: String, context: String?, block: String?) -> RefID? {
        let ns = raw as NSString
        guard let m = tokenRegex.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let number = ns.substring(with: m.range(at: 1))
        var id = RefID(display: ns.substring(with: m.range), key: "§" + number, prefix: "§", scope: .section)
        let word = ns.substring(with: m.range)
        var before = context ?? ""
        var tail = ns.substring(from: m.range.location + m.range.length)
        if let block {
            if let r = block.range(of: before + word) {
                tail = String(block[r.upperBound...])
            } else if let r = block.range(of: word) {
                before = String(block[..<r.lowerBound])
                tail = String(block[r.upperBound...])
            }
        }
        id.document = document(before: before + ns.substring(to: m.range.location), after: tail)
        return id
    }

    /// The document a sentence names around a `§`: the word before it (`spec §4`), a link before it, or `of X` after it.
    static func document(before: String, after tail: String) -> String? {
        let b = before as NSString
        let whole = NSRange(location: 0, length: b.length)
        if let m = linkBefore.firstMatch(in: before, range: whole), let name = normalizeName(b.substring(with: m.range(at: 1))) { return name }
        if let m = wordBefore.firstMatch(in: before, range: whole), let name = normalizeName(b.substring(with: m.range(at: 1))) { return name }
        let t = tail as NSString
        if let m = after.firstMatch(in: tail, range: NSRange(location: 0, length: t.length)),
           let name = normalizeName(t.substring(with: m.range(at: 1))) { return name }
        return nil
    }

    /// `docs/Spec.md` → `spec`; nil for a word that names nothing.
    static func normalizeName(_ raw: String) -> String? {
        var name = (raw.split(separator: "/").last.map(String.init) ?? raw).lowercased()
        if name.hasSuffix(".md") { name = String(name.dropLast(3)) }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
        guard name.count >= 2, name.contains(where: \.isLetter), !notDocuments.contains(name) else { return nil }
        return name
    }

    /// Lowercase letters and digits only, to compare `data-model` with `DATA_MODEL`.
    static func squash(_ s: String) -> String { String(s.lowercased().filter { $0.isLetter || $0.isNumber }) }

    /// Whether `path` is the document called `name`: its file name or one of its folders.
    static func isDocument(_ name: String, path: String) -> Bool {
        let want = squash(name)
        guard !want.isEmpty else { return false }
        let parts = path.split(separator: "/").map(String.init)
        guard let file = parts.last else { return false }
        let base = (file as NSString).deletingPathExtension
        return squash(base) == want || parts.dropLast().contains { squash($0) == want }
    }

    /// Numbered headings of a markdown file: `(0-based line, section number, title)`. Fenced code is skipped.
    static func headings(lines: [String]) -> [(line: Int, number: String, title: String)] {
        var out: [(line: Int, number: String, title: String)] = []
        var inFence = false
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle(); continue }
            guard !inFence, line.hasPrefix("#"), let m = DefinitionRules.match(numberedHeading, line) else { continue }
            let title = DefinitionRules.cleanTitle(m[2])
            if !title.isEmpty { out.append((i, m[1], title)) }
        }
        return out
    }
}

extension Resolver {
    /// The headings a `§N` may point at, and how it found them. The sentence names the document: only that one.
    /// Otherwise the reader's own file; otherwise the nearest folder going up with such a heading (several there
    /// are ambiguous, listed together). With no file known, all of the repo's. Nothing numbered N: nothing.
    public func sectionLookup(for id: RefID, preferredRepo: String?, fromPath: String?) -> (key: String, defs: [Definition], route: SectionRoute?) {
        var key: String? = id.key
        while let k = key {
            let own = (index.definitions[k] ?? []).filter { d in
                guard let preferredRepo else { return true }
                return d.repo.caseInsensitiveCompare(preferredRepo) == .orderedSame
            }
            if !own.isEmpty {
                if let name = id.document {
                    let named = own.filter { SectionRefs.isDocument(name, path: $0.path) }
                    if !named.isEmpty { return (k, named, .named) }
                }
                guard let fromPath else { return (k, own, .repoWide) }
                let mine = fromPath.split(separator: "/").dropLast().map(String.init)
                let here = own.filter { $0.path == fromPath }
                if !here.isEmpty { return (k, here, .ownFile) }
                for depth in stride(from: mine.count, through: 0, by: -1) {
                    let level = own.filter { $0.path.split(separator: "/").dropLast().map(String.init) == Array(mine.prefix(depth)) }
                    if !level.isEmpty { return (k, level, .nearby) }
                }
            }
            key = k.contains(".") ? String(k[..<k.lastIndex(of: ".")!]) : nil
        }
        return (id.key, [], nil)
    }
}
