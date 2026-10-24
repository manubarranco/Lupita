import Foundation

/// Which repos have coding agents, how many citations in them nothing defines, and whether
/// the Lupita rule is already in their instructions (D21). Read-only: Lupita never writes in
/// a user's repo; it hands the user a prompt for their own agent.
public struct RepoOnboarding: Hashable, Sendable {
    public let repo: Repo
    /// Agent instruction files found, relative to the repo root.
    public let agentFiles: [String]
    /// Mentions of IDs that nothing defines in this repo.
    public let undefinedCitations: Int
    /// The `<!-- lupita -->` marker is in one of the agent files.
    public let ruleInstalled: Bool

    /// Where the rule goes, by the prompt's own rule: `AGENTS.md`, or `CLAUDE.md` if there is none.
    public var instructionsFile: String? {
        ["AGENTS.md", "CLAUDE.md"].first(where: agentFiles.contains)
    }

    public init(repo: Repo, agentFiles: [String], undefinedCitations: Int, ruleInstalled: Bool) {
        self.repo = repo
        self.agentFiles = agentFiles
        self.undefinedCitations = undefinedCitations
        self.ruleInstalled = ruleInstalled
    }

    /// The same row with the rule state read again from disk (cheap: only the agent files).
    public func refreshingRule() -> RepoOnboarding {
        RepoOnboarding(repo: repo, agentFiles: agentFiles, undefinedCitations: undefinedCitations,
                       ruleInstalled: Onboarding.hasRule(in: repo, files: agentFiles))
    }
}

public enum Onboarding {
    public static let marker = "<!-- lupita -->"

    /// Only repos with one of these in their root are listed (D21).
    public static let agentFileNames = ["AGENTS.md", "CLAUDE.md"]

    /// The agent instruction files of a repo, relative to its root.
    public static func agentFiles(in repo: Repo) -> [String] {
        let root = URL(fileURLWithPath: repo.path)
        return agentFileNames.filter { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    /// Whether any of the files carries the marker.
    public static func hasRule(in repo: Repo, files: [String]) -> Bool {
        files.contains { file in
            let url = URL(fileURLWithPath: repo.path).appendingPathComponent(file)
            return (try? String(contentsOf: url, encoding: .utf8))?.contains(marker) == true
        }
    }

    /// Mentions in `repo`'s files of keys that no repo defines for real (weak `.section`
    /// rules do not count): what Lupita cannot explain. A key defined in another repo is
    /// explained, so it does not count. Priority labels (`P0`-`P9`) and ranges (`L0-L3`)
    /// are not references and are left out.
    public static func undefinedCitations(of repo: Repo, in index: RefIndex) -> Int {
        let prefix = repo.name + "/"
        var total = 0
        for (key, mentions) in index.mentions {
            if index.definitions[key]?.contains(where: { !$0.rule.isWeak }) == true { continue }
            if isLabelOrRange(key) { continue }
            total += mentions.byFile.filter { $0.key.hasPrefix(prefix) }.values.reduce(0, +)
        }
        return total
    }

    private static let labelOrRange = try! NSRegularExpression(pattern: #"^(?:P\d|([A-Za-z]+)\d+-\1\d+)$"#, options: [.caseInsensitive])

    static func isLabelOrRange(_ key: String) -> Bool {
        labelOrRange.firstMatch(in: key, range: NSRange(location: 0, length: (key as NSString).length)) != nil
    }

    /// Status of every repo with agent files, most undefined citations first.
    public static func status(of index: RefIndex) -> [RepoOnboarding] {
        index.repos.compactMap { repo in
            let files = agentFiles(in: repo)
            guard !files.isEmpty else { return nil }
            return RepoOnboarding(repo: repo, agentFiles: files,
                                  undefinedCitations: undefinedCitations(of: repo, in: index),
                                  ruleInstalled: hasRule(in: repo, files: files))
        }.sorted { ($1.undefinedCitations, $0.repo.name) < ($0.undefinedCitations, $1.repo.name) }
    }

    /// The block the agent appends to the repo's instructions.
    public static let ruleBlock = """
        <!-- lupita -->
        Define each new decision, question, lesson or story once as `## ID — Title` plus a one-line summary.
        Add each new internal term to the glossary (`docs/glossary.md` if there is none) as `- **term** — definition`.
        Where this repo already has a format for these, keep it.
        <!-- /lupita -->
        """

    /// The prompt the user pastes to their own agent. Always English: agents read it, not the user.
    public static let prompt = """
        Add this block at the end of this repo's agent instructions file (`AGENTS.md`, or `CLAUDE.md` if there is no `AGENTS.md`). Change nothing else. If the block is already there, do nothing.

        \(ruleBlock)
        """

    /// Share of the citations in `repos` that some repo defines for real, as a whole percent.
    /// Same rules as `undefinedCitations`: weak sections do not count, labels and ranges are
    /// not references. `nil` when there is nothing cited.
    public static func explainedPercent(of repos: [Repo], in index: RefIndex) -> Int? {
        let prefixes = Set(repos.map { $0.name + "/" })
        var total = 0, explained = 0
        for (key, mentions) in index.mentions where !isLabelOrRange(key) {
            let n = mentions.byFile.filter { file in prefixes.contains { file.key.hasPrefix($0) } }.values.reduce(0, +)
            total += n
            if index.definitions[key]?.contains(where: { !$0.rule.isWeak }) == true { explained += n }
        }
        guard total > 0 else { return nil }
        return Int((Double(explained) / Double(total) * 100).rounded())
    }
}

/// Dotted-number version comparison (`0.4.0` against `0.3.0`), for "Check for updates".
public enum Versions {
    public static func parse(_ tag: String) -> [Int] {
        let trimmed = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    public static func isNewer(_ remote: String, than installed: String) -> Bool {
        let r = parse(remote), i = parse(installed)
        for k in 0..<max(r.count, i.count) {
            let a = k < r.count ? r[k] : 0, b = k < i.count ? i[k] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// The `tag_name` of a GitHub "latest release" response.
    public static func tag(fromReleaseJSON data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["tag_name"] as? String
    }
}
