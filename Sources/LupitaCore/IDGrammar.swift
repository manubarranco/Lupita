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
}

public enum IDGrammar {
    /// Tokens that match the grammar but are never agent references.
    public static let stoplist: Set<String> = [
        "GPL", "LGPL", "AGPL", "BSD", "UTF", "ES", "MP", "IPV", "HTTP", "TLS", "SHA", "MD", "ISO",
    ]

    static let tokenRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_\-])([A-Z]{1,5})(-?)(\d{1,4})([a-z]?)((?:-[A-Z]{1,3}\d{1,4}[a-z]?)*)(?![A-Za-z0-9_])"#
    )

    /// All IDs in `text`, with their UTF-16 ranges.
    public static func tokens(in text: String) -> [(id: RefID, range: NSRange)] {
        let ns = text as NSString
        return tokenRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let prefix = ns.substring(with: m.range(at: 1))
            guard !stoplist.contains(prefix) else { return nil }
            let number = ns.substring(with: m.range(at: 3))
            let letter = ns.substring(with: m.range(at: 4))
            let compound = ns.substring(with: m.range(at: 5))
            let id = RefID(
                display: ns.substring(with: m.range),
                key: prefix + number + letter + compound,
                prefix: prefix
            )
            return (id, m.range)
        }
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
