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
        var found: [(id: RefID, range: NSRange)] = tokenRegex.matches(in: text, range: whole).compactMap { m in
            let prefix = ns.substring(with: m.range(at: 1))
            guard !stoplist.contains(prefix) else { return nil }
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
            guard !noise.contains(key) else { return nil }
            return (RefID(display: ns.substring(with: range), key: key, prefix: prefix), range)
        }
        found += wordTokens(in: text)
        return found.sorted { $0.range.location < $1.range.location }
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
        for m in adrWordRegex.matches(in: text, range: whole) {
            let number = ns.substring(with: m.range(at: 1))
            out.append((RefID(display: ns.substring(with: m.range), key: "ADR" + number, prefix: "ADR"), m.range))
        }
        for m in adrFileRegex.matches(in: text, range: whole) {
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
