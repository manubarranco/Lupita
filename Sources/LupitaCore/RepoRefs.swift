import Foundation

/// References that are not IDs but point at something in a repo: the repo itself, a commit,
/// a branch, a file or an agent command (D19). Looked up on demand, never indexed: git and the disk are always
/// current, so there is nothing to keep fresh.
public enum RepoRefs {
    /// `e455cf7`, `749e5fd9f2af`: 7-40 lowercase hex characters, at least one digit and one letter.
    static let sha = try! NSRegularExpression(pattern: #"^(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}$"#)
    /// `/meeting`, `/code-review`, `/figma:figma-use`.
    static let command = try! NSRegularExpression(pattern: #"^/[a-z][a-z0-9-]*(?::[a-z0-9-]+)?$"#)
    /// `docs/a.md:12`, `docs/a.md:12:3`, `docs/a.md#L12`: the line is kept, the suffix dropped.
    static let lineSuffix = try! NSRegularExpression(pattern: #"(?::(\d+)(?::\d+)?|#L(\d+)\S*)$"#)
    /// A bare file name (no folder) counts as a path only with one of these extensions.
    static let fileExtensions: Set<String> = [
        "md", "swift", "ts", "tsx", "js", "jsx", "mjs", "py", "json", "html", "css", "scss", "sh",
        "yml", "yaml", "toml", "plist", "txt", "rb", "go", "rs", "kt", "java", "sql", "csv",
    ]
    static let wrappers = CharacterSet(charactersIn: "`\"'“”‘’«»()[]<>*_")
    static let trailing = CharacterSet(charactersIn: ".,;:!?…")

    /// The commit, branch, file or command `raw` names, or nil if it is none of them.
    /// `preferredRepo` is searched first; the others follow, so a hit elsewhere is flagged.
    /// `byName`: the index's markdown files by lowercased name, for a bare `decisions.md` outside the repo root.
    public static func resolve(_ raw: String, repos: [Repo], preferredRepo: String?,
                               byName: [String: [String]] = [:]) -> Resolution? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(wrappers))
        while let last = text.unicodeScalars.last, trailing.contains(last) { text.removeLast() }
        text = text.trimmingCharacters(in: wrappers)
        guard text.count >= 2, text.count <= 300 else { return nil }
        let ordered = repos.sorted { a, b in
            (a.name.caseInsensitiveCompare(preferredRepo ?? "") == .orderedSame ? 0 : 1)
                < (b.name.caseInsensitiveCompare(preferredRepo ?? "") == .orderedSame ? 0 : 1)
        }

        var defs: [Definition] = []
        if let named = repos.first(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame }) {
            defs = [repoInfo(named)]
        } else if matches(command, text) {
            defs = commands(String(text.dropFirst()), repos: ordered)
        } else if matches(sha, text) {
            defs = commits(text, repos: ordered)
        } else {
            let (path, line) = splitLine(text)
            let ext = (path as NSString).pathExtension.lowercased()
            guard path.contains("/") || fileExtensions.contains(ext) else { return nil }
            defs = files(path, line: line, repos: ordered, byName: byName)
            if defs.isEmpty, line == nil, path.contains("/"), !path.hasPrefix("/"), !path.hasPrefix("~") {
                defs = branches(path, repos: ordered)
            }
        }
        guard let first = defs.first else { return nil }
        var r = Resolution(query: text, kind: .exact, key: first.key, definitions: Array(defs.prefix(5)),
                           mentions: nil, alternatives: [])
        if let preferredRepo, repos.contains(where: { $0.name == first.repo }) {
            // `harbor/CLAUDE.md` says which repo it means: that is not "another repo". Nor is a
            // commit or branch: it lives in one repo only, so there is no local meaning to confuse.
            let named = text.lowercased().hasPrefix(first.repo.lowercased() + "/")
            let unique = first.rule == .commit || first.rule == .branch || first.rule == .repo
            r.fromOtherRepo = !named && !unique && first.repo.caseInsensitiveCompare(preferredRepo) != .orderedSame
        }
        return r
    }

    // MARK: - Repos

    /// The repo's own description (README, then CLAUDE.md or AGENTS.md) and where it stands.
    static func repoInfo(_ repo: Repo) -> Definition {
        let docs = ["README.md", "CLAUDE.md", "AGENTS.md"].compactMap { name -> (String, String?)? in
            guard let head = readHead((repo.path as NSString).appendingPathComponent(name)) else { return nil }
            let (title, summary) = markdownHead(head)
            return title.map { ($0, summary) }
        }
        var state: [String] = []
        if let branch = Git.output(repo.path, ["branch", "--show-current"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           !branch.isEmpty {
            state.append(S.onBranch(branch))
        }
        if let date = Git.output(repo.path, ["log", "-1", "--format=%ad", "--date=short"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           !date.isEmpty {
            state.append(S.lastCommit(date))
        }
        if let changes = Git.lines(repo.path, ["status", "--porcelain"]), !changes.isEmpty {
            state.append(S.uncommitted(changes.count))
        }
        let summary = [state.joined(separator: " · "), docs.first?.1 ?? ""].filter { !$0.isEmpty }.joined(separator: "\n")
        return Definition(id: repo.name, key: repo.path, repo: repo.name, path: "", line: 0, rule: .repo,
                          title: docs.first?.0 ?? S.kindRepo, summary: summary, absolutePath: repo.path)
    }

    // MARK: - Commits

    static func commits(_ sha: String, repos: [Repo]) -> [Definition] {
        repos.compactMap { repo -> Definition? in
            guard let fields = Git.fields(repo.path, ["log", "-1", "--format=%H%x1f%s%x1f%ad", "--date=short", sha + "^{commit}", "--"]),
                  fields.count == 3 else { return nil }
            let (full, subject, date) = (fields[0], fields[1], fields[2])
            let main = Git.mainBranch(repo.path)
            let place: String
            if let main, Git.succeeds(repo.path, ["merge-base", "--is-ancestor", full, main]) {
                place = S.inBranch(main)
            } else if let branch = Git.lines(repo.path, ["branch", "--contains", full, "--format=%(refname:short)"])?.first {
                place = S.onlyInBranch(branch)
            } else {
                place = S.inNoBranch
            }
            let pushed = !(Git.lines(repo.path, ["branch", "-r", "--contains", full]) ?? []).isEmpty
            var d = Definition(id: sha, key: full, repo: repo.name, path: "", line: 0, rule: .commit,
                               title: subject, summary: "\(date) · \(place)", absolutePath: repo.path)
            if pushed { d.openURL = Git.webURL(repo.path).map { "\($0)/commit/\(full)" } }
            return d
        }
    }

    // MARK: - Branches

    static func branches(_ name: String, repos: [Repo]) -> [Definition] {
        var live: [Definition] = [], gone: [Definition] = []
        for repo in repos {
            if let d = liveBranch(name, repo: repo) { live.append(d) } else if let d = goneBranch(name, repo: repo) { gone.append(d) }
        }
        return live + gone
    }

    private static func liveBranch(_ name: String, repo: Repo) -> Definition? {
        let ref = ["refs/heads/\(name)", "refs/remotes/origin/\(name)"].first {
            Git.succeeds(repo.path, ["rev-parse", "--verify", "--quiet", $0 + "^{commit}"])
        }
        guard let ref, let fields = Git.fields(repo.path, ["log", "-1", "--format=%H%x1f%s%x1f%ad", "--date=short", ref, "--"]),
              fields.count == 3 else { return nil }
        let (tip, subject, date) = (fields[0], fields[1], fields[2])
        var state = S.lastCommit(date)
        if let main = Git.mainBranch(repo.path), main != name, main != "origin/\(name)" {
            if Git.succeeds(repo.path, ["merge-base", "--is-ancestor", tip, main]) {
                state += " · " + S.mergedInto(main)
            } else if let counts = Git.lines(repo.path, ["rev-list", "--left-right", "--count", "\(main)...\(tip)"])?.first {
                let n = counts.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
                if n.count == 2 { state += " · " + S.ahead(n[1], of: main) }
            }
        }
        var d = Definition(id: name, key: name, repo: repo.name, path: "", line: 0, rule: .branch,
                           title: subject, summary: state, absolutePath: repo.path)
        if ref.hasPrefix("refs/remotes/") { d.openURL = Git.webURL(repo.path).map { "\($0)/tree/\(name)" } }
        return d
    }

    /// A deleted branch survives in the message of the commit that merged it.
    private static func goneBranch(_ name: String, repo: Repo) -> Definition? {
        for extra in [["--merges"], []] {
            let args = ["log", "--all", "-1", "-F", "--grep=\(name)", "--format=%H%x1f%s%x1f%ad", "--date=short"] + extra
            guard let fields = Git.fields(repo.path, args), fields.count == 3 else { continue }
            let summary = extra.isEmpty ? S.branchCitedIn(fields[2], fields[1]) : S.branchMergedOn(fields[2], fields[1])
            var d = Definition(id: name, key: name, repo: repo.name, path: "", line: 0, rule: .branch,
                               title: S.branchDeleted, summary: summary, absolutePath: repo.path)
            if !(Git.lines(repo.path, ["branch", "-r", "--contains", fields[0]]) ?? []).isEmpty {
                d.openURL = Git.webURL(repo.path).map { "\($0)/commit/\(fields[0])" }
            }
            return d
        }
        return nil
    }

    // MARK: - Files

    static func splitLine(_ text: String) -> (String, Int?) {
        let ns = text as NSString
        guard let m = lineSuffix.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return (text, nil) }
        let digits = [1, 2].map { m.range(at: $0) }.first { $0.location != NSNotFound }.map(ns.substring(with:))
        return (ns.substring(to: m.range.location), digits.flatMap { Int($0) })
    }

    /// Whether `raw` names a file or folder in one of `repos`: the same paths `files` tries, checked on disk
    /// only, with no git and no reading (D49: cheap enough for the highlight).
    public static func isFile(_ raw: String, repos: [Repo], byName: [String: [String]] = [:]) -> Bool {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(wrappers))
        while let last = text.unicodeScalars.last, trailing.contains(last) { text.removeLast() }
        text = text.trimmingCharacters(in: wrappers)
        guard text.count >= 2, text.count <= 300 else { return false }
        let (path, _) = splitLine(text)
        guard path.contains("/") || fileExtensions.contains((path as NSString).pathExtension.lowercased()) else { return false }
        return candidates(path, repos: repos, byName: byName).contains { repo, relative in
            let relative = relative.hasSuffix("/") ? String(relative.dropLast()) : relative
            return !relative.isEmpty && FileManager.default.fileExists(atPath: (repo.path as NSString).appendingPathComponent(relative))
        }
    }

    /// The repo-relative paths `raw` could be: inside the repo an absolute path points into, or in every repo,
    /// the one it names first (`harbor/CLAUDE.md`).
    static func candidates(_ raw: String, repos: [Repo], byName: [String: [String]] = [:]) -> [(Repo, String)] {
        var path = raw.hasPrefix("./") ? String(raw.dropFirst(2)) : raw
        path = (path as NSString).expandingTildeInPath
        var candidates: [(Repo, String)] = []
        if path.hasPrefix("/") {
            let real = RepoDiscovery.realPath(path)
            if let repo = repos.first(where: { real.hasPrefix(RepoDiscovery.realPath($0.path) + "/") }) {
                candidates.append((repo, String(real.dropFirst(RepoDiscovery.realPath(repo.path).count + 1))))
            }
        } else {
            for repo in repos where path.lowercased().hasPrefix(repo.name.lowercased() + "/") {
                candidates.append((repo, String(path.dropFirst(repo.name.count + 1))))
            }
            candidates += repos.map { ($0, path) }
            // A bare name (`decisions.md`) anywhere in a repo, in the repos' order (the window's repo first) and,
            // inside a repo, the shallowest first: `memory/decisions.md` before `domains/finance/decisions.md`.
            if !path.contains("/") {
                let paths = (byName[path.lowercased()] ?? []).sorted {
                    ($0.split(separator: "/").count, $0) < ($1.split(separator: "/").count, $1)
                }
                for repo in repos {
                    for full in paths where full.hasPrefix(repo.name + "/") {
                        candidates.append((repo, String(full.dropFirst(repo.name.count + 1))))
                    }
                }
            }
        }
        return candidates
    }

    static func files(_ raw: String, line: Int?, repos: [Repo], byName: [String: [String]] = [:]) -> [Definition] {
        let fm = FileManager.default
        var seen = Set<String>()
        return candidates(raw, repos: repos, byName: byName).compactMap { repo, relative -> Definition? in
            let relative = relative.hasSuffix("/") ? String(relative.dropLast()) : relative
            guard !relative.isEmpty else { return nil }
            let absolute = (repo.path as NSString).appendingPathComponent(relative)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: absolute, isDirectory: &isDir), seen.insert(absolute).inserted else { return nil }
            let (title, summary) = isDir.boolValue ? folderInfo(absolute) : fileInfo(absolute, relative: relative, repo: repo)
            return Definition(id: (relative as NSString).lastPathComponent + (isDir.boolValue ? "/" : ""),
                              key: "\(repo.name)/\(relative)", repo: repo.name, path: relative,
                              line: isDir.boolValue ? 0 : (line ?? 1), rule: .file, title: title, summary: summary,
                              absolutePath: absolute)
        }
    }

    private static func fileInfo(_ absolute: String, relative: String, repo: Repo) -> (String, String) {
        let name = (absolute as NSString).lastPathComponent
        let lastChange = Git.fields(repo.path, ["log", "-1", "--format=%s%x1f%ad", "--date=short", "--", relative])
            .flatMap { $0.count == 2 ? S.lastChange($0[1], $0[0]) : nil }
        if absolute.lowercased().hasSuffix(".md"), let head = readHead(absolute) {
            let (title, summary) = markdownHead(head)
            return (title ?? name, summary ?? lastChange ?? "")
        }
        return (name, lastChange ?? "")
    }

    private static func folderInfo(_ absolute: String) -> (String, String) {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: absolute))?.filter { !$0.hasPrefix(".") } ?? []
        let readme = items.first { $0.lowercased() == "readme.md" }
        if let readme, let head = readHead((absolute as NSString).appendingPathComponent(readme)) {
            let (title, summary) = markdownHead(head)
            return (title ?? S.folder(items.count), summary ?? S.folder(items.count))
        }
        return (S.folder(items.count), "")
    }

    /// The first 8 KB of a text file.
    static func readHead(_ path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8192) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// The first `#` heading and the first line of prose of a markdown file.
    static func markdownHead(_ text: String) -> (title: String?, summary: String?) {
        var lines = text.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---", let end = lines.dropFirst().firstIndex(of: "---") {
            lines.removeSubrange(0...end)
        }
        var title: String?, summary: String?, inFence = false
        for line in lines.prefix(80) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") { inFence.toggle(); continue }
            if inFence || t.isEmpty || t.hasPrefix("<") || t.hasPrefix("![") || t.hasPrefix("|") || t.hasPrefix("---") { continue }
            if t.hasPrefix("#") {
                if title == nil { title = plain(t.drop { $0 == "#" }) }
                continue
            }
            summary = plain(t.hasPrefix(">") ? t.dropFirst() : Substring(t))
            break
        }
        return (title, summary.map { $0.count > 240 ? String($0.prefix(239)) + "…" : $0 })
    }

    /// Markdown emphasis and links reduced to their text.
    static func plain<T: StringProtocol>(_ s: T) -> String {
        String(s).replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*|__|`"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Commands

    /// Claude Code commands and skills: the repo's `.claude` first, then the user's `~/.claude`.
    static func commands(_ name: String, repos: [Repo]) -> [Definition] {
        let name = name.split(separator: ":").last.map(String.init) ?? name
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let places = repos.map { ($0.name, $0.path) } + [("~/.claude", home)]
        var out: [Definition] = []
        for (repoName, root) in places {
            for relative in [".claude/commands/\(name).md", ".claude/skills/\(name)/SKILL.md"] {
                let absolute = (root as NSString).appendingPathComponent(relative)
                guard let head = readHead(absolute) else { continue }
                let (description, fallback) = (frontmatterValue("description", in: head), markdownHead(head).summary)
                out.append(Definition(id: "/" + name, key: absolute, repo: repoName, path: relative, line: 1,
                                      rule: .command, title: description ?? fallback ?? "/" + name, summary: "",
                                      absolutePath: absolute))
            }
        }
        return out
    }

    /// A one-line or folded (`>` / `|`) value from the YAML frontmatter.
    static func frontmatterValue(_ key: String, in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        for (i, line) in lines.enumerated().dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { return nil }
            guard line.hasPrefix(key + ":") else { continue }
            var value = line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            if [">", "|", ">-", "|-"].contains(value) {
                value = lines[(i + 1)...].prefix { $0.hasPrefix(" ") || $0.hasPrefix("\t") }
                    .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            }
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }
}

/// Runs git, read-only, when it is installed (D20). Without the Command Line Tools,
/// `/usr/bin/git` is a stub that opens an install dialog: it is never called then.
enum Git {
    static let executable: String? = {
        let fm = FileManager.default
        if let found = ["/opt/homebrew/bin/git", "/usr/local/bin/git"].first(where: fm.isExecutableFile(atPath:)) { return found }
        guard let dir = run("/usr/bin/xcode-select", ["-p"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              fm.isExecutableFile(atPath: dir + "/usr/bin/git") else { return nil }
        return dir + "/usr/bin/git"
    }()

    static func output(_ repo: String, _ args: [String]) -> String? {
        guard let git = executable else { return nil }
        return run(git, ["-C", repo] + args)
    }

    static func succeeds(_ repo: String, _ args: [String]) -> Bool { output(repo, args) != nil }

    static func lines(_ repo: String, _ args: [String]) -> [String]? {
        output(repo, args).map { $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    }

    /// One line split on the unit separator (`%x1f`).
    static func fields(_ repo: String, _ args: [String]) -> [String]? {
        guard let out = output(repo, args)?.trimmingCharacters(in: .newlines), !out.isEmpty else { return nil }
        return out.components(separatedBy: "\u{1f}")
    }

    /// `main` or `master`, whichever exists locally.
    static func mainBranch(_ repo: String) -> String? {
        ["main", "master"].first { succeeds(repo, ["rev-parse", "--verify", "--quiet", "refs/heads/\($0)"]) }
    }

    /// `https://github.com/owner/repo` from the `origin` remote, when it is on GitHub.
    static func webURL(_ repo: String) -> String? {
        guard var url = output(repo, ["remote", "get-url", "origin"])?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if url.hasPrefix("git@github.com:") { url = "https://github.com/" + url.dropFirst("git@github.com:".count) }
        guard url.hasPrefix("https://github.com/") else { return nil }
        if url.hasSuffix(".git") { url.removeLast(4) }
        return url
    }

    /// stdout when the command exits 0, nil otherwise.
    private static func run(_ executable: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["GIT_OPTIONAL_LOCKS"] = "0"
        env["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
