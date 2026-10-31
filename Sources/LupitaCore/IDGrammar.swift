import Foundation

/// A reference ID as it appears in text, plus its normalized lookup key.
///
/// Grammar: `PREFIX` (1-5 uppercase letters), optional `-`, 1-4 digits, optional
/// lowercase letter, then any number of compound parts `-S3b`.
/// Examples: `D23`, `QL25`, `ADR-004`, `BUG-01`, `E2-S3b`.
public struct RefID: Hashable, Codable, Sendable {
    /// Exactly as written (`ADR-004`).
    public let display: String
    /// Normalized key: no hyphen before the number (`ADR004`, `D001`, `E2-S3b`).
    /// Leading zeros are kept: in real repos `L007` (a lesson) and `L7` (a job level) are
    /// different series, and padded IDs are never cited unpadded (1316 to 0 for `D0nn`).
    public let key: String
    /// Uppercase prefix (`ADR`).
    public let prefix: String
    /// Where a definition has to live to count for this mention. `.none` for every form that has
    /// a prefix and a number of its own (`D23`, `ADR-004`).
    public var scope: IDScope = .none
}

/// How far a definition reaches. Forms with a word and a number (`Requirement 3`, `Task 1.1`) are
/// reused in every spec of a repo, so a mention only takes a definition from its own folder or above.
public enum IDScope: String, Codable, Sendable {
    case none
    /// The definition's folder is the mention's folder or one above it.
    case folder
    /// The definition is in the same first-level folder as the mention, and neither is a framework's own file.
    case topFolder
}

public enum IDGrammar {
    /// Tokens that match the grammar but are never agent references.
    public static let stoplist: Set<String> = [
        "GPL", "LGPL", "AGPL", "BSD", "UTF", "ES", "MP", "IPV", "HTTP", "TLS", "SHA", "MD", "ISO",
    ]

    /// Whole tokens that match the grammar but name an algorithm or a product: `RS256`, `AES-256`,
    /// `K8s`, `DB2`. Listed by key so `RS101` in a requirements table stays an ID.
    public static let noise: Set<String> = Set(
        ["HS", "RS", "PS"].flatMap { p in ["256", "384", "512"].map { p + $0 } }
            + ["AES128", "AES192", "AES256", "S256", "K8s", "DB2"])

    /// The last group is a `.N` suffix (`REQ-3.1`): kept only after a hyphen and when no further `.N` follows
    /// (`REL-0.9.1` is a version), see `tokens(in:)`.
    static let tokenRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_\-])([A-Z]{1,5})(-?)(\d{1,4})([a-z]?)((?:-[A-Z]{1,3}\d{1,4}[a-z]?)*)(\.\d{1,3})?(?![A-Za-z0-9_])"#
    )

    /// A word and a number: `Requirement 3`, `Story 2.3`, `Epic 2`, `Property 7`, `Decision 4`, `Task Group 2`,
    /// `Task 1.1`, `Subtask 5.2`. Groups: word, number (up to three parts).
    static let wordRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_\-])(Requirements?|Story|Epics?|Propert(?:y|ies)|Decision|Task Group|Subtask|Task) #?(\d{1,3}(?:\.\d{1,3}){0,2})(?![\d_]|\.[A-Za-z0-9])(?![A-Za-z_])"#
    )

    /// A task in a checklist, `- [ ] 1.1 Create the table` or `- [x]* 2. Wire it`: the number alone is the token.
    static let taskLineRegex = try! NSRegularExpression(
        pattern: #"^\s*[-*+]\s+\[[ xX]\]\*?\s+(\d{1,3}(?:\.\d{1,3}){0,2})\.?(?=\s|$)"#
    )

    /// BMAD's key of a story, `2-3-user-login` (epic 2, story 3). `3-3a-slug` is another story than 3.3 and has no key here.
    static let storyKeyRegex = try! NSRegularExpression(
        pattern: #"(?<![\w.\-])(\d{1,2})-(\d{1,2})-[a-z][a-z0-9\-]*"#
    )

    /// An ADR written with a space, `ADR 7`: the key is the one of `ADR7`. `ADR-0007` and `ADR007` are read by the prefix grammar.
    static let adrWordRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_\-])ADR (\d{1,4})(?![A-Za-z0-9_]|\.\d)"#
    )

    /// The name of an ADR file as it is cited, `0007-use-foo.md`: the key is the one of `ADR0007`.
    static let adrFileRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_\-])(\d{4})-[A-Za-z0-9][A-Za-z0-9_\-]*\.md(?![A-Za-z0-9_])"#
    )

    /// The word of a numbered form → the word in its key. A subtask is a task.
    static let wordKeys: [String: String] = [
        "Requirement": "REQUIREMENT", "Requirements": "REQUIREMENT", "Story": "STORY", "Epic": "EPIC", "Epics": "EPIC",
        "Property": "PROPERTY", "Properties": "PROPERTY", "Decision": "DECISION", "Task Group": "TASK GROUP",
        "Subtask": "TASK", "Task": "TASK",
    ]

    /// All IDs in `text`, with their UTF-16 ranges.
    public static func tokens(in text: String) -> [(id: RefID, range: NSRange)] {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var found: [(id: RefID, range: NSRange)] = []
        for m in tokenRegex.matches(in: text, range: whole) {
            let prefix = ns.substring(with: m.range(at: 1))
            guard !stoplist.contains(prefix) else { continue }
            let hyphen = ns.substring(with: m.range(at: 2))
            let number = ns.substring(with: m.range(at: 3))
            let letter = ns.substring(with: m.range(at: 4))
            let compound = ns.substring(with: m.range(at: 5))
            var range = m.range
            var suffix = ""
            if m.range(at: 6).location != NSNotFound {
                let after = m.range.location + m.range.length
                let versionLike = after + 1 < ns.length && ns.character(at: after) == 0x2E
                    && (0x30...0x39).contains(ns.character(at: after + 1))
                if !hyphen.isEmpty, letter.isEmpty, compound.isEmpty, !versionLike {
                    suffix = ns.substring(with: m.range(at: 6))
                } else {
                    range.length -= m.range(at: 6).length
                }
            }
            let key = prefix + number + letter + compound + suffix
            guard !noise.contains(key) else { continue }
            found.append((RefID(display: ns.substring(with: range), key: key, prefix: prefix), range))
            if letter.isEmpty, compound.isEmpty, suffix.isEmpty, range.length == m.range.length {
                found += inheritedTokens(in: ns, prefix: prefix, number: number, after: range)
            }
        }
        found += trackerTokens(in: text, ns: ns, existing: found)
        found += wordTokens(in: text)
        return found.sorted { $0.range.location < $1.range.location }
    }

    /// A tracker key as Jira or Linear write it, `PLAT-443341`, `ACME-527`: 2 to 10 letters, a hyphen and up to six
    /// digits, with no other hyphenated part after it (`ABC-2026-10-20` is a date), no `.N` (`LIC-2.0`) and no `%`
    /// before it. A prefix with digits (`R1-4`) is not a key.
    static let trackerRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_%\-])([A-Z]{2,10})-(\d{1,6})(?![A-Za-z0-9_]|-[A-Za-z0-9]|\.\d)"#
    )

    /// Prefixes that are standards, products or licences, not trackers.
    static let notTrackers: Set<String> = ["GPT", "SHA", "CVE", "UTF", "ISO", "HTTP", "TLS", "RFC", "AES", "RSA", "MD", "IPV", "BSD"]

    /// `PLAT-4433` as the tracker key it is when written with a hyphen, or false.
    public static func isTrackerKey(_ display: String) -> Bool {
        let ns = display as NSString
        guard let m = trackerRegex.firstMatch(in: display, range: NSRange(location: 0, length: ns.length)), m.range.length == ns.length else { return false }
        let prefix = ns.substring(with: m.range(at: 1)), digits = ns.substring(with: m.range(at: 2))
        // Same shape the scanner reads: no zero first, and a long word needs three digits (`ACCEPT-01`, `FR-004` are not keys).
        return !notTrackers.contains(prefix) && !stoplist.contains(prefix) && digits.first != "0" && !(prefix.count >= 6 && digits.count < 3)
    }

    /// Keys the prefix grammar does not read (a prefix over five letters or a number over four digits). A hand-written
    /// scan: every line of every file goes through here at indexing time, and a regular expression on each was too slow.
    private static func trackerTokens(in text: String, ns: NSString, existing: [(id: RefID, range: NSRange)]) -> [(id: RefID, range: NSRange)] {
        let n = ns.length
        guard n >= 4 else { return [] }
        func isUpper(_ c: unichar) -> Bool { c >= 0x41 && c <= 0x5A }
        func isDigit(_ c: unichar) -> Bool { c >= 0x30 && c <= 0x39 }
        func isWordish(_ c: unichar) -> Bool { isUpper(c) || isDigit(c) || (c >= 0x61 && c <= 0x7A) || c == 0x5F }
        var out: [(id: RefID, range: NSRange)] = []
        var i = 1
        while i < n - 1 {
            defer { i += 1 }
            guard ns.character(at: i) == 0x2D, isUpper(ns.character(at: i - 1)), isDigit(ns.character(at: i + 1)) else { continue }
            var start = i
            while start > 0, isUpper(ns.character(at: start - 1)), i - start < 11 { start -= 1 }
            let letters = i - start
            guard letters >= 2, letters <= 10 else { continue }
            if start > 0 {
                let before = ns.character(at: start - 1)
                if isWordish(before) || before == 0x25 || before == 0x2D { continue }
            }
            var end = i + 1
            while end < n, isDigit(ns.character(at: end)), end - (i + 1) < 7 { end += 1 }
            let digits = end - (i + 1)
            guard digits <= 6 else { continue }
            // A tracker's numbers do not start with a zero, and a long word with a short number is a label of the
            // document (`NOTIFY-3`, `BLOCKING-4`, `ACCEPT-01`), not a key: the keys in git have three or more digits.
            if ns.character(at: i + 1) == 0x30 || (letters >= 6 && digits < 3) { continue }
            if end < n {
                let after = ns.character(at: end)
                if isWordish(after) { continue }
                if after == 0x2D, end + 1 < n, isWordish(ns.character(at: end + 1)) { continue }
                if after == 0x2E, end + 1 < n, isDigit(ns.character(at: end + 1)) { continue }
            }
            let range = NSRange(location: start, length: end - start)
            let prefix = ns.substring(with: NSRange(location: start, length: letters))
            guard !notTrackers.contains(prefix), !stoplist.contains(prefix),
                  !existing.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) else { continue }
            out.append((RefID(display: ns.substring(with: range), key: prefix + ns.substring(with: NSRange(location: i + 1, length: digits)),
                              prefix: prefix), range))
            i = end
        }
        return out
    }

    /// What follows an ID in a list that omits the prefix: `PU-02, 03 y 26`, `FR-004/006`.
    static let listContinuation = try! NSRegularExpression(
        pattern: #"(?:\s*,\s*(?:(?:y|and|&)\s+)?|\s*/\s*|\s+(?:y|and)\s+|\s*&\s*)(\d{1,4})(?![A-Za-z0-9_\-]|\.\d)"#
    )

    /// The numbers that follow `prefix number` in a list take its prefix when they have the same width and the
    /// separator is `,`, `/`, `y`, `and` or `&`. A lone digit needs two of them (`C5, 1` is not a list), and `L120, 121`
    /// are lines. They are scoped to a folder like the forms with a word: a bare number is only an ID where it is defined.
    private static func inheritedTokens(in ns: NSString, prefix: String, number: String, after: NSRange) -> [(id: RefID, range: NSRange)] {
        let end = after.location + after.length
        guard end < ns.length else { return [] }
        let next = ns.character(at: end)
        guard next == 0x2C || next == 0x2F || next == 0x26 || next == 0x20 else { return [] }
        if prefix == "L", number.first != "0" { return [] }
        guard listContinuation.firstMatch(in: ns as String, options: .anchored, range: NSRange(location: end, length: ns.length - end)) != nil
        else { return [] }
        let before = ns.substring(to: after.location).lowercased()
        if before.range(of: #"(?:lines?|l[ií]neas?|ln\.?|l\.|:)\s*$"#, options: .regularExpression) != nil { return [] }
        var out: [(id: RefID, range: NSRange)] = []
        var cursor = end
        while cursor < ns.length,
              let m = listContinuation.firstMatch(in: ns as String, options: .anchored, range: NSRange(location: cursor, length: ns.length - cursor)) {
            let digits = ns.substring(with: m.range(at: 1))
            guard digits.count == number.count else { break }
            out.append((RefID(display: digits, key: prefix + digits, prefix: prefix, scope: .folder), m.range(at: 1)))
            cursor = m.range.location + m.range.length
        }
        return number.count == 1 && out.count < 2 ? [] : out
    }

    /// The forms with a word or a position instead of a prefix: `Requirement 3`, `- [ ] 1.1`, `2-3-slug`.
    private static func wordTokens(in text: String) -> [(id: RefID, range: NSRange)] {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var out: [(id: RefID, range: NSRange)] = []
        for m in wordRegex.matches(in: text, range: whole) {
            let word = ns.substring(with: m.range(at: 1))
            guard let key = wordKeys[word] else { continue }
            let id = RefID(display: ns.substring(with: m.range), key: key + " " + ns.substring(with: m.range(at: 2)),
                           prefix: key, scope: .folder)
            out.append((id, m.range))
        }
        if let m = taskLineRegex.firstMatch(in: text, range: whole) {
            let number = ns.substring(with: m.range(at: 1))
            out.append((RefID(display: number, key: "TASK " + number, prefix: "TASK", scope: .folder), m.range(at: 1)))
        }
        for m in (ns.range(of: "ADR ").location == NSNotFound ? [] : adrWordRegex.matches(in: text, range: whole)) {
            let number = ns.substring(with: m.range(at: 1))
            out.append((RefID(display: ns.substring(with: m.range), key: "ADR" + number, prefix: "ADR"), m.range))
        }
        for m in (ns.range(of: ".md").location == NSNotFound ? [] : adrFileRegex.matches(in: text, range: whole)) {
            let number = ns.substring(with: m.range(at: 1))
            out.append((RefID(display: ns.substring(with: m.range), key: "ADR" + number, prefix: "ADR"), m.range))
        }
        for m in storyKeyRegex.matches(in: text, range: whole) {
            let key = "STORY " + ns.substring(with: m.range(at: 1)) + "." + ns.substring(with: m.range(at: 2))
            out.append((RefID(display: ns.substring(with: m.range), key: key, prefix: "STORY", scope: .topFolder), m.range))
        }
        return out
    }

    static let adrKey = try! NSRegularExpression(pattern: #"^ADR(\d{1,4})$"#)

    /// Every way a repo writes the same ADR number (`ADR7`, `ADR07`, `ADR007`, `ADR0007`), the key itself first.
    /// An ADR is cited as `ADR-0007`, `ADR007` or `ADR 7` and defined by `0007-use-foo.md` or a heading with
    /// another padding: the number is what they share.
    public static func adrAliases(of key: String) -> [String] {
        guard let m = adrKey.firstMatch(in: key, range: NSRange(location: 0, length: (key as NSString).length)),
              let n = Int((key as NSString).substring(with: m.range(at: 1))) else { return [key] }
        var out = [key]
        for width in 1...4 {
            let alias = "ADR" + String(repeating: "0", count: max(0, width - String(n).count)) + String(n)
            if !out.contains(alias) { out.append(alias) }
        }
        return out
    }

    static let suffixedKey = try! NSRegularExpression(pattern: #"^([A-Z]{1,5}\d{1,4})\.\d{1,3}$"#)

    /// `Requirement 3.1` cites a criterion of requirement 3; `Task 1.1.2`, a part of task 1.1; `FR-1.2` was read
    /// as `FR-1` before the `.N` suffix existed, and still shows it when nothing defines `FR-1.2`. The key one
    /// level up, or nil when there is none.
    public static func parentKey(of key: String) -> String? {
        if let m = suffixedKey.firstMatch(in: key, range: NSRange(location: 0, length: (key as NSString).length)) {
            return (key as NSString).substring(with: m.range(at: 1))
        }
        guard key.hasPrefix("REQUIREMENT ") || key.hasPrefix("STORY ") || key.hasPrefix("TASK "),
              let dot = key.lastIndex(of: "."), key.filter({ $0 == "." }).count >= (key.hasPrefix("REQUIREMENT ") ? 1 : 2)
        else { return nil }
        return String(key[..<dot])
    }

    /// Parses `text` as a single ID (whole string, surrounding punctuation trimmed).
    public static func parse(_ text: String) -> RefID? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let first = tokens(in: trimmed).first,
              first.range.location == 0, first.range.length == (trimmed as NSString).length
        else { return nil }
        return first.id
    }
}
