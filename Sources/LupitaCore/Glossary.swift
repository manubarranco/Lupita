import Foundation

/// A term and its definition found on one line (or heading), before the index builds a `Definition`.
public struct TermHit: Equatable, Sendable {
    /// The term and its aliases, cleaned (`Mesa / Mesa de Trazo` gives two names).
    public let names: [String]
    /// 0-based line index.
    public let line: Int
    public let definition: String
}

/// Glossary terms (D22, D23): `- **term** — definition` and friends, in glossary files.
public enum Glossary {
    /// File names (lowercased) containing one of these are glossaries.
    static let fileMarkers = ["glossary", "glosario", "nomenclatura", "terminolog"]

    /// Whether the generic pattern (`- **term** — definition` in any `.md`) is indexed too.
    /// Off: it did not reach the 95 % precision bar (D22). Tests and the CLI can turn it on.
    nonisolated(unsafe) public static var looseTerms = false

    public static func isGlossaryFile(_ fileName: String) -> Bool {
        let lower = fileName.lowercased()
        return lower.hasSuffix(".md") && fileMarkers.contains { lower.contains($0) }
    }

    // `- **term** — def`, `**term**: def`, `- **term** *(canónico)* — def`, `- **term**: def`
    static let boldEntry = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+]\s+)?\*\*([^*]+?)\*\*(?:\s*\*?\([^)]*\)\*?)?\s*(?:[—–:]|\s-\s)\s*(.+)$"#)
    // `**term:** def`
    static let boldColonInside = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+]\s+)?\*\*([^*]+?):\*\*\s*(.+)$"#)
    // `| **term** | def |`
    static let tableEntry = try! NSRegularExpression(
        pattern: #"^\s*\|\s*\*\*([^*|]+)\*\*\s*\|\s*([^|]+?)\s*\|?\s*$"#)
    // `### term`, `### term — def`
    static let headingEntry = try! NSRegularExpression(pattern: #"^(#{3,6})\s+(.+?)\s*$"#)
    // The generic pattern, strict: `- **term** — def` at the start of the line.
    static let looseEntry = try! NSRegularExpression(pattern: #"^- \*\*([^*]+?)\*\* — (.+)$"#)

    public static func terms(fileName: String, lines: [String]) -> [TermHit] {
        let glossary = isGlossaryFile(fileName)
        guard glossary || looseTerms else { return [] }
        var hits: [TermHit] = [], headings: [TermHit] = []
        var inFence = false
        var inFrontmatter = lines.first?.trimmingCharacters(in: .whitespaces) == "---"
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inFrontmatter {
                if i > 0, trimmed == "---" { inFrontmatter = false }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle(); continue }
            if inFence || trimmed.isEmpty { continue }
            guard let hit = entry(line, index: i, lines: lines, glossary: glossary) else { continue }
            if glossary, line.hasPrefix("#") { headings.append(hit) } else { hits.append(hit) }
        }
        // Headings are terms only in a glossary that has no list or table entries: otherwise
        // they are its sections (`### Anatomy`).
        return hits.isEmpty ? headings : hits
    }

    static func entry(_ line: String, index: Int, lines: [String], glossary: Bool) -> TermHit? {
        func hit(_ raw: String, _ definition: String) -> TermHit? {
            let names = cleanNames(raw)
            let text = Snippet.clean(definition)
            guard !names.isEmpty, !text.isEmpty else { return nil }
            return TermHit(names: names, line: index, definition: text)
        }
        guard glossary else {
            guard let m = DefinitionRules.match(looseEntry, line) else { return nil }
            return hit(m[1], m[2])
        }
        if let m = DefinitionRules.match(tableEntry, line) { return hit(m[1], m[2]) }
        if let m = DefinitionRules.match(boldColonInside, line) { return hit(m[1], continued(m[2], from: index, lines: lines)) }
        if let m = DefinitionRules.match(boldEntry, line) { return hit(m[1], continued(m[2], from: index, lines: lines)) }
        if let m = DefinitionRules.match(headingEntry, line) {
            let level = m[1].count
            var title = m[2], inline = ""
            for separator in [" — ", " – ", ": "] {
                if let r = title.range(of: separator) {
                    inline = String(title[r.upperBound...])
                    title = String(title[..<r.lowerBound])
                    break
                }
            }
            let body = inline.isEmpty ? Snippet.body(lines, from: index + 1, stopAtLevel: level) : inline
            return hit(title, body)
        }
        return nil
    }

    /// The definition plus up to two indented continuation lines.
    static func continued(_ first: String, from index: Int, lines: [String]) -> String {
        let indent = lines[index].prefix { $0 == " " || $0 == "\t" }.count
        var parts = [first]
        var i = index + 1
        while i < lines.count, parts.count < 3 {
            let line = lines[i]
            let lead = line.prefix { $0 == " " || $0 == "\t" }.count
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty, lead > indent,
                  !line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") else { break }
            parts.append(line.trimmingCharacters(in: .whitespaces))
            i += 1
        }
        return parts.joined(separator: " ")
    }

    /// `Mesa / Mesa de Trazo`, `plumilla *(canónico)*`, `` `Relief` ``, `esqueleto [?]`: the names to index.
    static func cleanNames(_ raw: String) -> [String] {
        var text = raw
        text = text.replacingOccurrences(of: #"\*?\([^)]*\)\*?"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "[?]", with: "").replacingOccurrences(of: "`", with: "")
        var seen = Set<String>()
        return text.components(separatedBy: " / ").compactMap { part -> String? in
            let name = part.trimmingCharacters(in: CharacterSet(charactersIn: " :*_\t"))
            let words = name.split(separator: " ")
            guard name.count >= 2, name.count <= 60, words.count <= 6, name.contains(where: \.isLetter),
                  IDGrammar.parse(name) == nil else { return nil }
            return seen.insert(normalize(name)).inserted ? name : nil
        }
    }

    // MARK: - Keys (D23)

    static let articles: Set<String> = ["el", "la", "los", "las", "the"]

    /// The lookup key of a term, the same when indexing and when looking up: lowercase, no
    /// accents, no backticks, no leading article, simple plural removed from the last word.
    public static func normalize(_ text: String) -> String {
        var words = fold(text).split(separator: " ").map(String.init)
        if words.count > 1, articles.contains(words[0]) { words.removeFirst() }
        guard let last = words.last else { return "" }
        words[words.count - 1] = singular(last)
        return words.joined(separator: " ")
    }

    /// Keys to try when looking up `text`: the normalized one, then the one for plurals in
    /// `-es` (`ciudades` gives `ciudad`, while `remates` gives `remate` already).
    public static func lookupKeys(_ text: String) -> [String] {
        let primary = normalize(text)
        var keys = [primary]
        let folded = fold(text)
        if folded.hasSuffix("es"), folded.count > 4 {
            let alt = normalize(String(folded.dropLast(2)))
            if alt != primary { keys.append(alt) }
        }
        return keys.filter { !$0.isEmpty }
    }

    static func fold(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "`", with: "")
        t = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        t = t.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return t.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// `remates` → `remate`; `census`, `glass`, `mesas` handled: only a lone trailing `s` after a
    /// letter that is not `s`/`u`/`i`, in words of 4+ letters.
    static func singular(_ word: String) -> String {
        guard word.count >= 4, word.hasSuffix("s") else { return word }
        let before = word[word.index(word.endIndex, offsetBy: -2)]
        guard !"suiy".contains(before) else { return word }
        return String(word.dropLast())
    }
}
