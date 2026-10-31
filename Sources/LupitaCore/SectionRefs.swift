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
    /// A `§N` that names no document and is not in a file that numbers it may take a neighbouring document of the reader
    /// (`.nearby`). Measured on 77 repos, 3 attempts: 11, 8 and 15 right of 20. Off (D60); the code stays to reopen it with its data.
    public static let readsNeighbours = false
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
        // `§` is C2 A7 in UTF-8; a byte test is far cheaper than `NSString.range(of:)`, which runs on every line of every file.
        guard text.utf8.contains(0xC2) else { return [] }
        return tokenRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            let number = ns.substring(with: m.range(at: 1))
            var id = RefID(display: ns.substring(with: m.range), key: "§" + number, prefix: "§", scope: .section)
            let named = document(before: ns.substring(to: m.range.location), after: ns.substring(from: m.range.location + m.range.length))
            id.document = named.document
            id.citesOther = named.other
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
        let named = document(before: before + ns.substring(to: m.range.location), after: tail)
        id.document = named.document
        id.citesOther = named.other
        return id
    }

    /// `§4.1 /` or `§4–`: an earlier `§` of the same list; the document is named before the first of them.
    static let chainedBefore = try! NSRegularExpression(
        pattern: #"(?:§\s?\d+(?:\.\d+)*\s*(?:[–—\-/,&]|\b(?:and|or|y|e)\b)\s*)+$"#)

    /// The document a sentence names around a `§`: the word before it (`spec §4`), a link before it, or `of X` after it.
    /// `other`: a word that is no document (`RFC 7009 §2.1`, `agent2 §1`, `Open Questions §2`) says the `§` belongs to
    /// something else, so the reader's own file and folders are not asked.
    static func document(before: String, after tail: String) -> (document: String?, other: Bool) {
        var text = before
        if let m = chainedBefore.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
            text = (text as NSString).substring(to: m.range.location)
        }
        let b = text as NSString
        let whole = NSRange(location: 0, length: b.length)
        if let m = linkBefore.firstMatch(in: text, range: whole), let name = normalizeName(b.substring(with: m.range(at: 1))) { return (name, false) }
        if let m = wordBefore.firstMatch(in: text, range: whole) {
            let word = b.substring(with: m.range(at: 1))
            if let name = normalizeName(word) { return (name, true) }
        }
        let t = tail as NSString
        if let m = after.firstMatch(in: tail, range: NSRange(location: 0, length: t.length)),
           let name = normalizeName(t.substring(with: m.range(at: 1))) { return (name, false) }
        // The last word before the `§`, with its punctuation: a number, a capitalised word or an acronym is not a preposition.
        let last = text.trimmingCharacters(in: CharacterSet(charactersIn: " \t`*_)]\"'’,:;(")).split(separator: " ").last.map(String.init) ?? ""
        let bare = last.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let other = !bare.isEmpty && !notDocuments.contains(bare.lowercased())
            && (bare.contains(where: \.isNumber) || bare.first!.isUppercase)
        return (nil, other)
    }

    /// `docs/Spec.md` → `docs/spec.md`, `Spec` → `spec`; nil for a word that names nothing. The extension stays: a name
    /// written with `.md` (or folders) is an exact reference.
    static func normalizeName(_ raw: String) -> String? {
        var name = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".-_/"))
        while name.hasPrefix("./") { name = String(name.dropFirst(2)) }
        let bare = name.hasSuffix(".md") ? String(name.dropLast(3)) : name
        guard bare.count >= 2, bare.contains(where: \.isLetter), !notDocuments.contains(bare) else { return nil }
        return name
    }

    /// Lowercase letters and digits only, to compare `data-model` with `DATA_MODEL`.
    static func squash(_ s: String) -> String { String(s.lowercased().filter { $0.isLetter || $0.isNumber }) }

    /// Whether `path` is the document called `name`: its file name, one of its folders, or (a name with folders) the end
    /// of its path. `design-outline.md` answers to `outline`.
    static func isDocument(_ name: String, path: String) -> Bool {
        var wanted = name
        if wanted.hasSuffix(".md") { wanted = String(wanted.dropLast(3)) }
        if wanted.contains("/") {
            var full = path.lowercased()
            if full.hasSuffix(".md") { full = String(full.dropLast(3)) }
            let want = wanted.hasPrefix("../") ? String(wanted.drop { $0 == "." || $0 == "/" }) : wanted
            return full == want || full.hasSuffix("/" + want)
        }
        let want = squash(wanted)
        guard !want.isEmpty else { return false }
        let parts = path.split(separator: "/").map(String.init)
        guard let file = parts.last else { return false }
        let base = (file as NSString).deletingPathExtension
        if squash(base) == want || parts.dropLast().contains(where: { squash($0) == want }) { return true }
        let words = base.lowercased().split { $0 == "-" || $0 == "_" || $0 == " " }.map(String.init)
        return want.count >= 4 && words.count > 1 && squash(words.last!) == want
    }

    /// The distinct file stems (lowercase) of the `.md` documents `text` names, sorted. One pass over the bytes: a regex
    /// over every file of every repo doubled the time to index.
    static func documentsNamed(in text: String) -> [String] {
        var seen = Set<String>()
        var contiguous = text
        contiguous.makeContiguousUTF8()
        contiguous.utf8.withContiguousStorageIfAvailable { bytes in
            let n = bytes.count
            func isName(_ b: UInt8) -> Bool {
                (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b == 0x5F || b == 0x2D || b == 0x2E
            }
            var i = 3
            while i < n {
                // `.md` ends here at i+3: the byte before `.` ... find it by looking for `md` after a `.`
                if bytes[i - 2] == 0x2E, bytes[i - 1] == 0x6D, bytes[i] == 0x64, i + 1 == n || !(isName(bytes[i + 1]) && bytes[i + 1] != 0x2E) {
                    var j = i - 2
                    while j > 0, isName(bytes[j - 1]) { j -= 1 }
                    while j < i - 2, bytes[j] == 0x2E || bytes[j] == 0x2D { j += 1 }
                    if j < i - 2 { seen.insert(String(decoding: UnsafeBufferPointer(rebasing: bytes[j..<(i - 2)]), as: UTF8.self).lowercased()) }
                }
                i += 1
            }
        }
        return seen.sorted()
    }

    /// The first line of text under a heading, cut short: a section has thousands of them, so no cleaning of markdown here.
    static func firstLine(after index: Int, in lines: [String]) -> String {
        var i = index + 1
        while i < lines.count, i <= index + 6 {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1
            if line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix("```") { break }
            return Snippet.truncate(line)
        }
        return ""
    }

    /// The numbered heading on `line` (`## 4.7 Title`), or nil. The caller has already left fenced code out.
    static func heading(_ line: String) -> (number: String, title: String)? {
        guard line.utf8.first == 0x23, startsNumbered(line.utf8), let m = DefinitionRules.match(numberedHeading, line) else { return nil }
        let title = DefinitionRules.cleanTitle(m[2])
        return title.isEmpty ? nil : (m[1], title)
    }

    /// `#`s, spaces, then a digit or `§`: the only shapes `numberedHeading` accepts.
    static func startsNumbered(_ utf8: String.UTF8View) -> Bool {
        var it = utf8.makeIterator()
        var hashes = 0
        var b = it.next()
        while b == 0x23 { hashes += 1; b = it.next() }
        guard (1...6).contains(hashes), b == 0x20 || b == 0x09 else { return false }
        while b == 0x20 || b == 0x09 { b = it.next() }
        guard let c = b else { return false }
        return (0x30...0x39).contains(c) || c == 0xC2
    }
}

extension Resolver {
    /// The headings a `§N` may point at, and how it found them. The sentence names the document: only that one.
    /// Otherwise the reader's own file; otherwise the nearest folder going up with such a heading (several there
    /// are ambiguous, listed together). With no file known, all of the repo's. Nothing numbered N: nothing.
    public func sectionLookup(for id: RefID, preferredRepo: String?, fromPath: String?,
                              neighbours: Bool = SectionRefs.readsNeighbours) -> (key: String, defs: [Definition], route: SectionRoute?) {
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
                    // A document is named and has no such section: it is not the reader's file or its neighbours that are meant.
                    return (id.key, [], nil)
                }
                // `RFC 7009 §2.1`: a § of something that is not a document here.
                if id.citesOther { return (id.key, [], nil) }
                guard let fromPath else { return (k, own, .repoWide) }
                let mine = fromPath.split(separator: "/").dropLast().map(String.init)
                let here = own.filter { $0.path == fromPath }
                if !here.isEmpty { return (k, here, .ownFile) }
                guard neighbours else { key = k.contains(".") ? String(k[..<k.lastIndex(of: ".")!]) : nil; continue }
                // A neighbour counts only if the reader names it somewhere (`data-model.md`, a link): no other evidence ties
                // a bare `§4` to a document that is not its own (measured: without this, 9 of 20 were the wrong document).
                let named = Set((preferredRepo.flatMap { index.documentRefs[$0 + "/" + fromPath] } ?? []))
                for depth in stride(from: mine.count, through: 0, by: -1) {
                    let level = own.filter {
                        $0.path.split(separator: "/").dropLast().map(String.init) == Array(mine.prefix(depth))
                            && named.contains((($0.path as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased())
                    }
                    if !level.isEmpty { return (k, level, .nearby) }
                }
            }
            key = k.contains(".") ? String(k[..<k.lastIndex(of: ".")!]) : nil
        }
        return (id.key, [], nil)
    }
}
