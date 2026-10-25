import Foundation

/// One row of the ID report (D40). Holds only shapes, literal prefixes, file names and
/// counts: never a title, a definition, a line of text or a path. Repos are numbers.
public struct IDReportRow: Codable, Hashable, Identifiable, Sendable {
    public enum Place: String, Codable, Sendable { case heading, table, list, fileName, frontmatter, text }

    /// Letters → `A`, digits → `9`, anything else as written (`E2-S3` → `A9-A9`).
    public let shape: String
    /// The literal prefix (`D`, `ADR`, `§`); empty when there is none (`1.2`).
    public let prefix: String
    public let place: Place
    /// The file name only. A file named after an ID shows the ID's shape (`A99-….md`), because the
    /// rest of such a name is a title.
    public let fileName: String
    /// 1-based, in alphabetical order of the repo names: «repo 1», «repo 2».
    public let repo: Int
    /// Different IDs of this shape written this way in this file.
    public let ids: Int
    /// Times they are cited anywhere (or, for unrecognised tokens, times they appear).
    public let mentions: Int
    /// Whether the shape matches Lupita's ID grammar.
    public let recognised: Bool
    /// Whether Lupita finds a definition for them.
    public let resolved: Bool

    public var id: String { "\(shape)|\(prefix)|\(place.rawValue)|\(fileName)|\(repo)|\(recognised)|\(resolved)" }
}

public enum IDReport {
    /// Unrecognised tokens and undefined IDs are listed only from this many appearances.
    public static let minimumAppearances = 3

    public static func shape(of text: String) -> String {
        String(text.map { c -> Character in
            if c.isNumber, c.isASCII { return "9" }
            if c.isLetter { return "A" }
            return c
        })
    }

    /// The report for an index. Known IDs come from the index; undefined and unrecognised
    /// tokens need one more pass over the repos' markdown files.
    public static func build(index: RefIndex, scanFiles: Bool = true) -> [IDReportRow] {
        let repoNumber = Dictionary(uniqueKeysWithValues:
            index.repos.map(\.name).sorted().enumerated().map { ($1, $0 + 1) })
        var known: [String: Acc] = [:]
        for (key, defs) in index.definitions {
            guard let best = defs.first, let place = place(of: best.rule),
                  let repo = repoNumber[best.repo] else { continue }
            let file = (best.path as NSString).lastPathComponent
            let name = best.rule == .fileName ? shapedFileName(file) : file
            let prefix = IDGrammar.parse(best.id)?.prefix ?? ""
            let shape = shape(of: best.id)
            let k = "\(shape)|\(prefix)|\(place)|\(name)|\(repo)"
            var acc = known[k, default: Acc(shape: shape, prefix: prefix, place: place, fileName: name,
                                            repo: repo, recognised: true, resolved: true)]
            acc.ids += 1
            acc.mentions += index.mentions[key]?.count ?? 0
            known[k] = acc
        }
        var rows = known.values.map(\.row)

        // Cited but never defined.
        var undefined: [String: Acc] = [:]
        for (key, m) in index.mentions where index.definitions[key] == nil && m.count >= minimumAppearances {
            guard let file = m.byFile.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key,
                  let slash = file.firstIndex(of: "/"),
                  let repo = repoNumber[String(file[..<slash])] else { continue }
            let name = (file as NSString).lastPathComponent
            let prefix = IDGrammar.parse(key)?.prefix ?? ""
            let k = "\(shape(of: key))|\(prefix)|\(name)|\(repo)"
            var acc = undefined[k, default: Acc(shape: shape(of: key), prefix: prefix, place: .text,
                                                fileName: name, repo: repo, recognised: true, resolved: false)]
            acc.ids += 1
            acc.mentions += m.count
            undefined[k] = acc
        }
        rows += undefined.values.map(\.row)

        if scanFiles { rows += unrecognised(in: index.repos, numbers: repoNumber) }
        return rows.sorted {
            ($0.resolved ? 0 : 1, -$0.ids, -$0.mentions, $0.id) < ($1.resolved ? 0 : 1, -$1.ids, -$1.mentions, $1.id)
        }
    }

    // MARK: Unrecognised tokens

    /// `§5`, `1.2`, `REQ.12`: they look like references but the grammar does not take them.
    static let looseTokens = try! NSRegularExpression(pattern: [
        #"§\s?\d+(?:\.\d+)*"#,
        #"(?<![A-Za-z0-9_.\-/§])\d{1,3}(?:\.\d{1,3}){1,2}(?![A-Za-z0-9_])(?!\.\d)"#,
        #"(?<![A-Za-z0-9_\-])[A-Z]{1,6}[._/]\d{1,4}(?![A-Za-z0-9_])"#,
    ].joined(separator: "|"))
    private static let codeSpan = try! NSRegularExpression(pattern: #"`[^`]*`|https?://\S+"#)

    static func unrecognised(in repos: [Repo], numbers: [String: Int]) -> [IDReportRow] {
        var found: [String: Acc] = [:]
        for repo in repos {
            guard let number = numbers[repo.name] else { continue }
            for file in RepoDiscovery.markdownFiles(in: repo) {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                var inFence = false
                for line in text.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle(); continue }
                    if inFence { continue }
                    let clean = codeSpan.stringByReplacingMatches(
                        in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: " ")
                    let ns = clean as NSString
                    let place = linePlace(trimmed)
                    for m in looseTokens.matches(in: clean, range: NSRange(location: 0, length: ns.length)) {
                        let token = ns.substring(with: m.range).replacingOccurrences(of: " ", with: "")
                        let prefix = String(token.prefix { !$0.isNumber })
                        let name = file.lastPathComponent
                        let k = "\(shape(of: token))|\(prefix)|\(place)|\(name)|\(number)"
                        var acc = found[k, default: Acc(shape: shape(of: token), prefix: prefix, place: place,
                                                        fileName: name, repo: number, recognised: false, resolved: false)]
                        acc.mentions += 1
                        found[k] = acc
                    }
                }
            }
        }
        return found.values.filter { $0.mentions >= minimumAppearances }.map { var a = $0; a.ids = 0; return a.row }
    }

    static func linePlace(_ trimmed: String) -> IDReportRow.Place {
        if trimmed.hasPrefix("#") { return .heading }
        if trimmed.hasPrefix("|") { return .table }
        if trimmed.range(of: #"^(?:[-*+]|\d+\.)\s"#, options: .regularExpression) != nil { return .list }
        return .text
    }

    // MARK: Helpers

    private struct Acc {
        var shape: String, prefix: String
        var place: IDReportRow.Place
        var fileName: String
        var repo: Int
        var recognised: Bool, resolved: Bool
        var ids = 0, mentions = 0
        var row: IDReportRow {
            IDReportRow(shape: shape, prefix: prefix, place: place, fileName: fileName, repo: repo,
                        ids: ids, mentions: mentions, recognised: recognised, resolved: resolved)
        }
    }

    private static func place(of rule: DefinitionRule) -> IDReportRow.Place? {
        switch rule {
        case .heading, .section: .heading
        case .tableRow: .table
        case .listOrColon: .list
        case .fileName: .fileName
        case .frontmatter: .frontmatter
        default: nil
        }
    }

    /// `Q07-secret-title.md` → `A99-….md`; the title part of a file named after an ID is dropped.
    static func shapedFileName(_ file: String) -> String {
        guard let hit = DefinitionRules.fileNameDefinition(file) else { return file }
        return "\(shape(of: hit.id.display))-….\((file as NSString).pathExtension)"
    }

    // MARK: Markdown file

    /// The file the user saves and sends: plain Markdown, English, one table.
    public static func markdown(rows: [IDReportRow], version: String) -> String {
        var out = """
        # Lupita ID report

        Lupita \(version). Shapes (letters = A, digits = 9), prefixes, file names and counts only.
        No titles, definitions, lines of text or paths. Repos are numbered.

        | Shape | Prefix | Written in | File | Repo | IDs | Mentions | Recognised | Resolves |
        |---|---|---|---|---|---|---|---|---|

        """
        for r in rows {
            let cells = [cell(r.shape), cell(r.prefix), r.place.rawValue, cell(r.fileName), "repo \(r.repo)",
                         r.recognised ? "\(r.ids)" : "-", "\(r.mentions)", r.recognised ? "yes" : "no", r.resolved ? "yes" : "no"]
            out += "| " + cells.joined(separator: " | ") + " |\n"
        }
        return out
    }

    private static func cell(_ text: String) -> String {
        let t = text.replacingOccurrences(of: "|", with: "\\|")
        return t.isEmpty ? "-" : "`\(t)`"
    }
}
