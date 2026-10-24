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
    public var fileCount: Int { filesPerRepo.values.reduce(0, +) }

    public init() {}

    private enum CodingKeys: String, CodingKey { case repos, definitions, mentions, terms, filesPerRepo }

    /// Indexes saved before terms existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repos = try c.decode([Repo].self, forKey: .repos)
        definitions = try c.decode([String: [Definition]].self, forKey: .definitions)
        mentions = try c.decode([String: Mentions].self, forKey: .mentions)
        terms = try c.decodeIfPresent([String: [Definition]].self, forKey: .terms) ?? [:]
        filesPerRepo = try c.decode([String: Int].self, forKey: .filesPerRepo)
    }

    public static func build(roots: [String]) -> RefIndex {
        build(repos: RepoDiscovery.repos(under: roots))
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
        for file in RepoDiscovery.markdownFiles(in: repo) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            count += 1
            let (relative, absolute) = RepoDiscovery.paths(of: file, in: repo)
            add(text: text, fileName: file.lastPathComponent, repo: repo.name,
                relativePath: relative, absolutePath: absolute)
        }
        filesPerRepo[repo.name] = count
    }

    /// Indexes one file's content. Exposed for tests.
    public mutating func add(text: String, fileName: String, repo: String, relativePath: String, absolutePath: String) {
        let lines = text.components(separatedBy: .newlines)
        let hits = DefinitionRules.definitions(fileName: fileName, lines: lines)
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
            var skipDefinition = definedOnLine[i]
            for token in IDGrammar.tokens(in: line) {
                if token.id.key == skipDefinition { skipDefinition = nil; continue }
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
        for (key, defs) in definitions {
            definitions[key] = defs.sorted {
                if $0.rule.weight != $1.rule.weight { return $0.rule.weight > $1.rule.weight }
                let a = density[densityKey($0)] ?? 0, b = density[densityKey($1)] ?? 0
                if a != b { return a > b }
                return ($0.repo, $0.path, $0.line) < ($1.repo, $1.path, $1.line)
            }
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
