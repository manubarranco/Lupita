import Foundation

/// Which D6 heuristic recognised a definition. Higher weight wins when an ID is
/// defined more than once in the same repo.
public enum DefinitionRule: String, Codable, Sendable, CaseIterable {
    case frontmatter, heading, fileName, listOrColon, tableRow
    /// A heading with no title (`## P1`) or the same ID heading several sections of one
    /// file (`## D034 bloque 2`): a section *about* the ID, not where it is defined.
    case section
    /// Not IDs: looked up on demand in git and on disk, never indexed (D19).
    case commit, branch, file, command

    public var weight: Int {
        switch self {
        case .frontmatter: 100
        case .heading: 90
        case .fileName: 80
        case .listOrColon: 60
        case .tableRow: 40
        case .section: 20
        case .commit, .branch, .file, .command: 0
        }
    }

    /// Weak definitions never beat a real one from another repo.
    public var isWeak: Bool { self == .section }

    /// A repo reference (commit, branch, file, command) rather than an ID definition.
    public var isRepoRef: Bool { [.commit, .branch, .file, .command].contains(self) }
}

/// A definition found on one line (or in a file name), before snippet extraction.
public struct DefinitionHit: Equatable, Sendable {
    public let id: RefID
    public let rule: DefinitionRule
    /// 0-based line index; -1 for file-name definitions.
    public let line: Int
    /// Text right after the ID on the defining line, separators stripped.
    public let title: String
}

public enum DefinitionRules {
    // `## D23 — Title`, `### **Q07**: Title`. The ID must be the first token of the heading.
    static let heading = try! NSRegularExpression(
        pattern: #"^#{1,6}\s+\**\s*([^\s*:—–·|),.]+)\**(?:\s*[—–:\-.·|)]\s*|\s+|$)(.*)$"#)
    // `- **Q07**: text`, `**Q07:** text`, `Q07: text`, `1. D3 — text`. Bold must close right after the ID.
    static let listOrColon = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+]\s+|\d+\.\s+)?(\*\*|__)?([A-Za-z0-9\-]+?)(?::\1|\1\s*[:—–]|\s*[:—–](?=\s))\s*(.*)$"#)
    // `| Q07 | Title | … |`
    static let tableRow = try! NSRegularExpression(
        pattern: #"^\s*\|\s*\**([A-Za-z0-9\-]+?)\**\s*\|\s*([^|]*)\|"#)
    // `| **E8-S6 Regalo de monedas [Could]** |`, `| E10-S2 ✅ Historial |`. Bold, if any, wraps
    // ID and title together: `| **D008** (aside) |` is a mention.
    static let tableTitledCell = try! NSRegularExpression(
        pattern: #"^\s*\|\s*(?:\*\*)?([A-Za-z0-9\-]+?)\s+([^|]+?)\s*\|"#)
    static let frontmatterID = try! NSRegularExpression(
        pattern: #"^id:\s*["']?([A-Za-z0-9\-]+)["']?\s*$"#)
    static let leadingDate = try! NSRegularExpression(
        pattern: #"^\(?\d{4}-\d{2}-\d{2}\)?\s*[—–:\-·|]?\s*"#)

    /// All definitions in a markdown file. Fenced code blocks are ignored (templates live there).
    public static func definitions(fileName: String, lines: [String]) -> [DefinitionHit] {
        var hits: [DefinitionHit] = []
        if let hit = fileNameDefinition(fileName) { hits.append(hit) }

        var inFence = false
        var inFrontmatter = lines.first?.trimmingCharacters(in: .whitespaces) == "---"
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inFrontmatter {
                if i > 0, trimmed == "---" { inFrontmatter = false; continue }
                if let m = match(frontmatterID, trimmed), let id = IDGrammar.parse(m[1]) {
                    hits.append(DefinitionHit(id: id, rule: .frontmatter, line: i, title: ""))
                }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle(); continue }
            if inFence { continue }
            if let hit = lineDefinition(line, index: i) { hits.append(hit) }
        }
        let headingCounts = Dictionary(grouping: hits.filter { $0.rule == .heading }, by: \.id.key).mapValues(\.count)
        return hits.map { hit in
            guard hit.rule == .heading, hit.title.isEmpty || headingCounts[hit.id.key, default: 0] > 1 else { return hit }
            return DefinitionHit(id: hit.id, rule: .section, line: hit.line, title: hit.title)
        }
    }

    /// A single line as a definition, or nil if it only mentions IDs.
    public static func lineDefinition(_ line: String, index: Int = 0) -> DefinitionHit? {
        if line.hasPrefix("#") {
            guard let m = match(heading, line), let id = IDGrammar.parse(m[1]) else { return nil }
            return DefinitionHit(id: id, rule: .heading, line: index, title: cleanTitle(m[2]))
        }
        if let m = match(tableRow, line) {
            guard let id = IDGrammar.parse(m[1]), !isSeparatorRow(line) else { return nil }
            return DefinitionHit(id: id, rule: .tableRow, line: index, title: cleanTitle(m[2]))
        }
        if let m = match(tableTitledCell, line), let id = IDGrammar.parse(m[1]) {
            let title = cleanTitle(m[2].replacingOccurrences(of: "✅", with: "").replacingOccurrences(of: "\\", with: ""))
            guard !title.isEmpty else { return nil }
            return DefinitionHit(id: id, rule: .tableRow, line: index, title: title)
        }
        if let m = match(listOrColon, line), let id = IDGrammar.parse(m[2]) {
            let title = cleanTitle(m[3])
            guard !title.isEmpty else { return nil }
            return DefinitionHit(id: id, rule: .listOrColon, line: index, title: title)
        }
        return nil
    }

    /// `Q07-title.md`, `D23.md`, `E2-S3b-voice-input.md`.
    public static func fileNameDefinition(_ fileName: String) -> DefinitionHit? {
        let base = (fileName as NSString).deletingPathExtension
        guard let first = IDGrammar.tokens(in: base).first, first.range.location == 0 else { return nil }
        let rest = (base as NSString).substring(from: first.range.length)
        guard rest.isEmpty || rest.hasPrefix("-") || rest.hasPrefix("_") || rest.hasPrefix(" ") else { return nil }
        let title = rest.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            .replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return DefinitionHit(id: first.id, rule: .fileName, line: -1, title: title)
    }

    static func cleanTitle(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespaces)
        let ns = t as NSString
        if let m = leadingDate.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) {
            t = ns.substring(from: m.range.length)
        }
        return t.replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " —–:-·|*"))
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        line.allSatisfy { "|-: ".contains($0) }
    }

    static func match(_ regex: NSRegularExpression, _ text: String) -> [String]? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map {
            let r = m.range(at: $0)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
}
