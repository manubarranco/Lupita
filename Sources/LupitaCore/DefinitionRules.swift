import Foundation

/// Which D6 heuristic recognised a definition. Higher weight wins when an ID is
/// defined more than once in the same repo.
public enum DefinitionRule: String, Codable, Sendable, CaseIterable {
    case frontmatter, heading, fileName, listOrColon, tableRow
    /// A heading with no title (`## P1`) or the same ID heading several sections of one
    /// file (`## D034 bloque 2`): a section *about* the ID, not where it is defined.
    case section
    /// Not IDs: looked up on demand in git and on disk, never indexed (D19).
    case repo, commit, branch, file, command
    /// A glossary term (D22): below every ID definition.
    case term
    /// What agents cite from code (D29): looked up on demand, never indexed.
    case symbol, address, token, color, terminal, error, tag, pullRequest
    /// A term of a vocabulary package (D42): looked up in a fixed table, below the glossary.
    case vocabulary

    public var weight: Int {
        switch self {
        case .frontmatter: 100
        case .heading: 90
        case .fileName: 80
        case .listOrColon: 60
        case .tableRow: 40
        case .section: 20
        case .term: 10
        case .repo, .commit, .branch, .file, .command: 0
        case .symbol, .address, .token, .color, .terminal, .error, .tag, .pullRequest, .vocabulary: 0
        }
    }

    /// Weak definitions never beat a real one from another repo.
    public var isWeak: Bool { self == .section }

    /// A repo reference (repo, commit, branch, file, command) rather than an ID definition.
    public var isRepoRef: Bool { [.repo, .commit, .branch, .file, .command].contains(self) }

    /// A code reference (symbol, local address, CSS token, colour, terminal command, error, tag or PR; D29).
    public var isCode: Bool { [.symbol, .address, .token, .color, .terminal, .error, .tag, .pullRequest].contains(self) }
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
        pattern: #"^#{1,6}\s+\**\s*((?:[^\s*:—–·|),.]|\.(?=\d))+)\**(?:\s*[—–:\-.·|)]\s*|\s+|$)(.*)$"#)
    // `- **Q07**: text`, `**Q07:** text`, `Q07: text`, `1. D3 — text`. Bold must close right after the ID.
    static let listOrColon = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+]\s+|\d+\.\s+)?(\*\*|__)?([A-Za-z0-9\-.]+?)(?::\1|\1\s*[:—–]|\s*[:—–](?=\s))\s*(.*)$"#)
    // `| Q07 | Title | … |`
    static let tableRow = try! NSRegularExpression(
        pattern: #"^\s*\|\s*\**([A-Za-z0-9\-.]+?)\**\s*\|\s*([^|]*)\|"#)
    // `| **E8-S6 Regalo de monedas [Could]** |`, `| E10-S2 ✅ Historial |`. Bold, if any, wraps
    // ID and title together: `| **D008** (aside) |` is a mention.
    static let tableTitledCell = try! NSRegularExpression(
        pattern: #"^\s*\|\s*(?:\*\*)?([A-Za-z0-9\-.]+?)\s+([^|]+?)\s*\|"#)
    // `- [x] T001 [P] [US1] Crear modelo de Foo` (spec-kit tasks): the ID is the first token after
    // the box; the bracketed tags after it are not part of the title.
    static let task = try! NSRegularExpression(
        pattern: #"^\s*[-*+]\s+\[[ xX]\]\s+\**([A-Za-z0-9\-]+?)\**\s+(?:\[[^\]]*\]\s*)*(.+)$"#)
    // `### User Story 1 - Crear Foo (Priority: P1)` (spec-kit) defines `US1`, which tasks and plans cite.
    static let userStory = try! NSRegularExpression(
        pattern: #"^#{1,6}\s+User Story\s+(\d{1,4})\s*[-—–:·]\s*(.*?)\s*(?:\(Priority:\s*P\d+\))?\s*$"#)
    // `### Requirement 3: Title`, `## Epic 2 - Title`, `#### Task Group 1`: a heading that starts with a word and
    // a number defines that form. The title may be empty: the heading is the definition. `Task 2.FIX` is another
    // thing and `Requirements 12.1-12.6` a range: neither defines `Task 2` or `Requirement 12.1`.
    static let wordHeading = try! NSRegularExpression(
        pattern: #"^#{1,6}\s+\**\s*(Requirements?|Story|Epics?|Propert(?:y|ies)|Decision|Task Group|Subtask|Task) #?(\d{1,3}(?:\.\d{1,3}){0,2})(?![\d]|\.\d|[-–]\d)\**\s*(?:(?:[:—–\-·|)]|\.(?=\s|$))\s*|\s+|$)(.*)$"#)
    // `- [ ] 1.1 Create the table`, `- [x]* 2. Wire it`: a task of a `tasks.md`.
    static let taskLine = try! NSRegularExpression(
        pattern: #"^\s*[-*+]\s+\[[ xX]\]\*?\s+(\d{1,3}(?:\.\d{1,3}){0,2})\.?\s+(.+)$"#)
    static let frontmatterID = try! NSRegularExpression(
        pattern: #"^id:\s*["']?([A-Za-z0-9\-]+)["']?\s*$"#)
    static let leadingDate = try! NSRegularExpression(
        pattern: #"^\(?\d{4}-\d{2}-\d{2}\)?\s*[—–:\-·|]?\s*"#)

    /// All definitions in a markdown file. Fenced code blocks are ignored (templates live there).
    public static func definitions(fileName: String, lines: [String]) -> [DefinitionHit] {
        var hits: [DefinitionHit] = []
        if let hit = fileNameDefinition(fileName) { hits.append(hit) }
        let isTasksFile = fileName.lowercased() == "tasks.md"

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
            else if isTasksFile, let hit = taskDefinition(line, index: i) { hits.append(hit) }
        }
        let headingCounts = Dictionary(grouping: hits.filter { $0.rule == .heading }, by: \.id.key).mapValues(\.count)
        return hits.map { hit in
            // `### Requirement 3` with no title is still where requirement 3 is defined.
            let titleless = hit.title.isEmpty && hit.id.scope == .none
            guard hit.rule == .heading, titleless || headingCounts[hit.id.key, default: 0] > 1 else { return hit }
            return DefinitionHit(id: hit.id, rule: .section, line: hit.line, title: hit.title)
        }
    }

    /// A single line as a definition, or nil if it only mentions IDs.
    public static func lineDefinition(_ line: String, index: Int = 0) -> DefinitionHit? {
        if line.hasPrefix("#") {
            if let m = match(userStory, line), let id = IDGrammar.parse("US" + m[1]) {
                return DefinitionHit(id: id, rule: .heading, line: index, title: cleanTitle(m[2]))
            }
            if let m = match(wordHeading, line), let id = IDGrammar.parse(m[1] + " " + m[2]) {
                return DefinitionHit(id: id, rule: .heading, line: index, title: cleanTitle(m[3]))
            }
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
        if let m = match(task, line), let id = IDGrammar.parse(m[1]) {
            return DefinitionHit(id: id, rule: .listOrColon, line: index, title: cleanTitle(m[2]))
        }
        if let m = match(listOrColon, line), let id = IDGrammar.parse(m[2]) {
            let title = cleanTitle(m[3])
            guard !title.isEmpty else { return nil }
            return DefinitionHit(id: id, rule: .listOrColon, line: index, title: title)
        }
        return nil
    }

    /// `- [ ] 1.1 Create the table` in a `tasks.md`: defines `Task 1.1`.
    static func taskDefinition(_ line: String, index: Int) -> DefinitionHit? {
        guard let m = match(taskLine, line), let id = IDGrammar.parse("Task " + m[1]) else { return nil }
        return DefinitionHit(id: id, rule: .listOrColon, line: index, title: cleanTitle(m[2]))
    }

    /// `Q07-title.md`, `D23.md`, `E2-S3b-voice-input.md`. A file called `STORY-2.1-HANDOFF-REPORT.md` is a report
    /// about a story, not the story: IDs with a `.N` suffix are not defined by file names.
    public static func fileNameDefinition(_ fileName: String) -> DefinitionHit? {
        let base = (fileName as NSString).deletingPathExtension
        guard let first = IDGrammar.tokens(in: base).first, first.range.location == 0, first.id.scope == .none,
              !first.id.key.contains(".")
        else { return nil }
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
