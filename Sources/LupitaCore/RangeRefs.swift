import Foundation

/// A range of IDs (`D022-D026`, D41): the list of what it spans.
public struct RangeList: Sendable {
    public struct Entry: Sendable {
        /// As it would be written (`D024`); the definition's own text when there is one.
        public let id: String
        /// nil when nothing defines this ID: the line stays, marked «not defined».
        public let definition: Definition?
    }
    public enum Row: Sendable {
        case entry(Entry)
        /// «… N more» between the first three and the last two.
        case more(Int)
    }

    public let entries: [Entry]
    /// What the IDs are, plural: «decisions», or «IDs» when the prefix and file say nothing.
    public let noun: String
    /// Repo and file when every defined ID shares them: shown once at the bottom.
    public let sharedRepo: String?
    public let sharedPath: String?

    public var count: Int { entries.count }
    /// From this many IDs on, the list is shortened.
    public static let longFrom = 7

    public var rows: [Row] {
        guard count >= Self.longFrom else { return entries.map(Row.entry) }
        return entries.prefix(3).map(Row.entry) + [.more(count - 5)] + entries.suffix(2).map(Row.entry)
    }
}

extension Resolver {
    /// More IDs than this between the ends is not a range anyone cites; keeps `D1-D9999` cheap.
    static let maxRangeSpan = 500
    static let rangeEnd = try! NSRegularExpression(pattern: #"^([A-Z]{1,5})(-?)(\d{1,4})$"#)

    /// The list for `raw` when it reads `A-B` or `A–B` and both ends are defined IDs with the same prefix; else nil.
    public func rangeList(_ raw: String, preferredRepo: String? = nil, fromPath: String? = nil) -> RangeList? {
        let text = Self.latinize(raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        guard text.contains(where: { $0 == "-" || $0 == "–" }) else { return nil }
        let chars = Array(text)
        for i in chars.indices where chars[i] == "-" || chars[i] == "–" {
            if let list = rangeList(String(chars[..<i]), String(chars[(i + 1)...]), preferredRepo, fromPath) { return list }
        }
        return nil
    }

    private func parseEnd(_ text: String) -> (prefix: String, hyphen: Bool, digits: String, number: Int)? {
        let ns = text as NSString
        guard let m = Self.rangeEnd.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              !IDGrammar.stoplist.contains(ns.substring(with: m.range(at: 1))),
              let number = Int(ns.substring(with: m.range(at: 3)))
        else { return nil }
        return (ns.substring(with: m.range(at: 1)), m.range(at: 2).length > 0, ns.substring(with: m.range(at: 3)), number)
    }

    private func rangeList(_ from: String, _ to: String, _ preferredRepo: String?, _ fromPath: String?) -> RangeList? {
        guard let a = parseEnd(from), let b = parseEnd(to), a.prefix == b.prefix, a.number < b.number,
              b.number - a.number < Self.maxRangeSpan
        else { return nil }
        func key(_ n: Int) -> String { a.prefix + String(format: "%0\(a.digits.count)d", n) }
        func resolved(_ n: Int) -> Resolution { result(key(n), .exact, key: key(n), index.definitions[key(n)] ?? [], preferredRepo, fromPath) }
        guard let first = resolved(a.number).definitions.first, resolved(b.number).kind == .exact else { return nil }
        // Every ID is read in the repo of the first one, and in its file when it is there.
        func definition(_ n: Int) -> Definition? {
            let defs = (index.definitions[key(n)] ?? []).filter { $0.repo == first.repo && !$0.rule.isWeak || $0 == first }
            return defs.first { $0.path == first.path } ?? defs.first
        }
        guard definition(b.number) != nil else { return nil }
        let entries = (a.number...b.number).map { n in
            RangeList.Entry(id: definition(n)?.id ?? a.prefix + (a.hyphen ? "-" : "") + String(format: "%0\(a.digits.count)d", n),
                            definition: definition(n))
        }
        let defined = entries.compactMap(\.definition)
        let sameRepo = Set(defined.map(\.repo)).count == 1
        let samePath = sameRepo && Set(defined.map(\.path)).count == 1
        return RangeList(entries: entries, noun: S.rangeNoun(prefix: a.prefix, file: first.path),
                         sharedRepo: sameRepo ? first.repo : nil, sharedPath: samePath ? first.path : nil)
    }
}
