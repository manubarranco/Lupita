import Foundation

public struct Definition: Codable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let repo: String
    /// Path relative to the repo root.
    public let path: String
    /// 1-based; 0 for file-name definitions.
    public let line: Int
    public let rule: DefinitionRule
    public let title: String
    public let summary: String
    /// Absolute path, for "click to open".
    public let absolutePath: String
    /// Where a click goes instead of `absolutePath`: a commit or branch on GitHub (D19).
    public var openURL: String? = nil
    /// Colour samples to paint next to a CSS token or hex colour (D29), one per theme.
    public var colors: [ColorSample]? = nil

    /// Defined in a closed change of OpenSpec (`openspec/changes/archive`): a live definition of the same ID is preferred.
    public var isArchived: Bool { path.split(separator: "/").dropLast().contains("archive") }
}

/// A colour to draw: `hex` is `#RRGGBB` (or `#RRGGBBAA`); `label` says which theme it is for (`light`, `dark`) or is empty.
public struct ColorSample: Codable, Hashable, Sendable {
    public let label: String
    public let hex: String
    public init(label: String, hex: String) {
        self.label = label
        self.hex = hex
    }
}

public struct Mentions: Codable, Sendable {
    /// `repo/path` of each file citing the ID → times cited there. Per file, so one repo
    /// can be reindexed without recounting the others.
    public var byFile: [String: Int] = [:]
    public var count: Int { byFile.values.reduce(0, +) }
    public var files: Set<String> { Set(byFile.keys) }
}

/// The dictionary of defined IDs (D5) plus mention counts (D6).
public struct RefIndex: Codable, Sendable {
    public var repos: [Repo] = []
    /// Normalized key → definitions, best first.
    public var definitions: [String: [Definition]] = [:]
    public var mentions: [String: Mentions] = [:]
    /// Normalized term key (`Glossary.normalize`) → glossary definitions, best first (D22).
    public var terms: [String: [Definition]] = [:]
    /// Repo name → markdown files indexed.
    public var filesPerRepo: [String: Int] = [:]
    /// Lowercased file name → `repo/relative/path` of every markdown file with that name (D49): a bare
    /// `decisions.md` is found wherever it lives, with no search on disk.
    public var markdownByName: [String: [String]] = [:]
    public var fileCount: Int { filesPerRepo.values.reduce(0, +) }
    /// While indexing: repo → task keys a `.md` of it cites as `Task 5` or `Subtask 5.2`. Not saved. A bare `Subtask 1` is
    /// a phase of someone's own work (`ReDoS Subtask 1`), not a line of `tasks.json`.
    var firmTaskCites: [String: Set<String>] = [:]
    /// `repo/path` of a file → the markdown documents it names (`data-model.md`, `docs/spec.md`), as lowercase file stems.
    /// A `§4` with no document in its sentence may take a neighbour only if the reader names that neighbour somewhere.
    public var documentRefs: [String: [String]] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey { case repos, definitions, mentions, terms, filesPerRepo, markdownByName, documentRefs }

    /// Indexes saved before terms existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repos = try c.decode([Repo].self, forKey: .repos)
        definitions = try c.decode([String: [Definition]].self, forKey: .definitions)
        mentions = try c.decode([String: Mentions].self, forKey: .mentions)
        terms = try c.decodeIfPresent([String: [Definition]].self, forKey: .terms) ?? [:]
        filesPerRepo = try c.decode([String: Int].self, forKey: .filesPerRepo)
        markdownByName = try c.decodeIfPresent([String: [String]].self, forKey: .markdownByName) ?? [:]
        documentRefs = try c.decodeIfPresent([String: [String]].self, forKey: .documentRefs) ?? [:]
    }

    public static func build(roots: [String], excluding: Set<String> = []) -> RefIndex {
        build(repos: RepoDiscovery.repos(under: roots, excluding: excluding))
    }

    public static func build(repos: [Repo]) -> RefIndex {
        var index = RefIndex()
        index.repos = repos
        for repo in repos { index.indexFiles(of: repo) }
        index.rank()
        return index
    }

    /// Replaces one repo's part of the index with a fresh scan; the other repos are untouched.
    public mutating func rebuild(repo: Repo) {
        remove(repoNamed: repo.name)
        if !repos.contains(repo) { repos.append(repo) }
        indexFiles(of: repo)
        rank()
    }

    /// Follows the repos found under the roots: drops vanished ones, indexes new ones.
    public mutating func sync(repos current: [Repo]) {
        for gone in repos where !current.contains(gone) { remove(repoNamed: gone.name) }
        let added = current.filter { !repos.contains($0) }
        repos = current
        for repo in added { indexFiles(of: repo) }
        if !added.isEmpty { rank() }
    }

    private mutating func remove(repoNamed name: String) {
        repos.removeAll { $0.name == name }
        filesPerRepo[name] = nil
        firmTaskCites[name] = nil
        for key in Array(documentRefs.keys) where key.hasPrefix(name + "/") { documentRefs[key] = nil }
        for key in Array(markdownByName.keys) {
            let kept = markdownByName[key]!.filter { !$0.hasPrefix(name + "/") }
            markdownByName[key] = kept.isEmpty ? nil : kept
        }
        for key in Array(definitions.keys) {
            let kept = definitions[key]!.filter { $0.repo != name }
            definitions[key] = kept.isEmpty ? nil : kept
        }
        for key in Array(terms.keys) {
            let kept = terms[key]!.filter { $0.repo != name }
            terms[key] = kept.isEmpty ? nil : kept
        }
        let prefix = name + "/"
        for key in Array(mentions.keys) {
            var m = mentions[key]!
            m.byFile = m.byFile.filter { !$0.key.hasPrefix(prefix) }
            mentions[key] = m.byFile.isEmpty ? nil : m
        }
    }

    private mutating func indexFiles(of repo: Repo) {
        var count = 0
        let files = RepoDiscovery.files(in: repo)
        for file in files.markdown {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            count += 1
            let (relative, absolute) = RepoDiscovery.paths(of: file, in: repo)
            add(text: text, fileName: file.lastPathComponent, repo: repo.name,
                relativePath: relative, absolutePath: absolute)
        }
        filesPerRepo[repo.name] = count
        for file in files.structured {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let (relative, absolute) = RepoDiscovery.paths(of: file, in: repo)
            addStructured(text: text, fileName: file.lastPathComponent, repo: repo.name, relativePath: relative, absolutePath: absolute)
        }
    }

    /// Indexes one JSON, YAML or TOML file (D60), after the `.md` files of its repo: an object with an ID and a title
    /// defines that ID only if a `.md` of the repo cites it and no `.md` of the repo defines it. Exposed for tests.
    public mutating func addStructured(text: String, fileName: String, repo: String, relativePath: String, absolutePath: String,
                                       everything: Bool = StructuredFiles.readsEverything) {
        for c in StructuredFiles.candidates(fileName: fileName, text: text, everything: everything) {
            guard c.key.hasPrefix("TASK ") ? firmTaskCites[repo]?.contains(c.key) == true
                    : (mentions[c.key]?.byFile.keys.contains { $0.hasPrefix(repo + "/") }) == true,
                  !(definitions[c.key] ?? []).contains(where: { $0.repo == repo && $0.rule != .structured }) else { continue }
            definitions[c.key, default: []].append(Definition(
                id: c.display, key: c.key, repo: repo, path: relativePath, line: c.line, rule: .structured,
                title: c.title, summary: c.summary, absolutePath: absolutePath))
        }
    }

    /// Indexes one file's content. Exposed for tests.
    public mutating func add(text: String, fileName: String, repo: String, relativePath: String, absolutePath: String) {
        markdownByName[fileName.lowercased(), default: []].append(repo + "/" + relativePath)
        let named = SectionRefs.documentsNamed(in: text)
        if !named.isEmpty { documentRefs[repo + "/" + relativePath] = named }
        let lines = text.components(separatedBy: .newlines)
        let hits = DefinitionRules.definitions(fileName: fileName, lines: lines,
                                               folder: relativePath.split(separator: "/").dropLast().last.map(String.init) ?? "")
        var definedOnLine: [Int: String] = [:]
        for hit in hits {
            let (title, summary) = Snippet.build(for: hit, lines: lines)
            definitions[hit.id.key, default: []].append(Definition(
                id: hit.id.display, key: hit.id.key, repo: repo, path: relativePath, line: hit.line + 1,
                rule: hit.rule, title: title, summary: summary, absolutePath: absolutePath))
            if hit.line >= 0 { definedOnLine[hit.line] = hit.id.key }
        }
        for hit in Glossary.terms(fileName: fileName, lines: lines) {
            for name in hit.names {
                let key = Glossary.normalize(name)
                guard !key.isEmpty else { continue }
                let d = Definition(id: name, key: key, repo: repo, path: relativePath, line: hit.line + 1,
                                   rule: .term, title: name, summary: Snippet.truncate(hit.definition),
                                   absolutePath: absolutePath)
                if !(terms[key] ?? []).contains(where: { $0.repo == repo && $0.path == relativePath && $0.line == d.line }) {
                    terms[key, default: []].append(d)
                }
            }
        }
        var inFence = false
        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { inFence.toggle(); continue }
            if inFence { continue }
            if let h = SectionRefs.heading(line) {
                let key = "§" + h.number
                definitions[key, default: []].append(Definition(
                    id: key, key: key, repo: repo, path: relativePath, line: i + 1, rule: .heading,
                    title: h.title, summary: SectionRefs.firstLine(after: i, in: lines), absolutePath: absolutePath))
            }
            var skipDefinition = definedOnLine[i]
            for token in IDGrammar.tokens(in: line) {
                if token.id.key == skipDefinition { skipDefinition = nil; continue }
                if token.id.key.hasPrefix("TASK "), token.id.display.hasPrefix("Task") || token.id.key.contains(".") {
                    firmTaskCites[repo, default: []].insert(token.id.key)
                }
                mentions[token.id.key, default: Mentions()].byFile["\(repo)/\(relativePath)", default: 0] += 1
            }
        }
    }

    /// Orders each ID's definitions: strongest rule, then the file that is the prefix's
    /// "home" (most definitions of that prefix), then path.
    public mutating func rank() {
        var density: [String: Int] = [:]  // "repo/path|prefix" → count
        for defs in definitions.values {
            for d in defs { density[densityKey(d), default: 0] += 1 }
        }
        rankTerms()
        pruneWordFormMentions()
        for (key, defs) in definitions {
            definitions[key] = defs.sorted {
                if $0.isArchived != $1.isArchived { return !$0.isArchived }
                if $0.rule.weight != $1.rule.weight { return $0.rule.weight > $1.rule.weight }
                let a = density[densityKey($0)] ?? 0, b = density[densityKey($1)] ?? 0
                if a != b { return a > b }
                return ($0.repo, $0.path, $0.line) < ($1.repo, $1.path, $1.line)
            }
        }
    }

    /// `Task 3` and `Epic 2` are written in every document and mean something only where the same repo defines
    /// them: mentions of a form with a word that no file of the mentioning repo defines are dropped.
    private mutating func pruneWordFormMentions() {
        for key in Array(mentions.keys) where key.contains(" ") {
            // `Requirement 3.1` shows `Requirement 3`: its mentions count wherever a parent form is defined.
            var repos = Set<String>()
            var k: String? = key
            while let current = k { repos.formUnion((definitions[current] ?? []).map(\.repo)); k = IDGrammar.parentKey(of: current) }
            var m = mentions[key]!
            m.byFile = m.byFile.filter { file, _ in file.firstIndex(of: "/").map { repos.contains(String(file[..<$0])) } ?? false }
            mentions[key] = m.byFile.isEmpty ? nil : m
        }
    }

    private mutating func rankTerms() {
        for (key, defs) in terms {
            terms[key] = defs.sorted { ($0.repo, $0.path, $0.line) < ($1.repo, $1.path, $1.line) }
        }
    }

    private func densityKey(_ d: Definition) -> String {
        "\(d.repo)/\(d.path)|\(IDGrammar.tokens(in: d.id).first?.id.prefix ?? d.id)"
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: url)
    }

    public static func load(from url: URL) throws -> RefIndex {
        try JSONDecoder().decode(RefIndex.self, from: Data(contentsOf: url))
    }
}
