import Foundation

public struct Repo: Hashable, Codable, Sendable {
    public let name: String
    public let path: String
}

/// Finds git repos under registered roots (D8) and the markdown files inside them.
public enum RepoDiscovery {
    /// Directory names never descended into. Hidden directories are skipped too.
    public static let skippedDirs: Set<String> = [
        "node_modules", ".build", "build", "dist", "DerivedData", "Pods", "venv",
        "archive", "archived", "vendor",
    ]

    /// Hidden folders of spec frameworks that are indexed anyway (D043). A closed list: every
    /// other hidden folder (`.git`, caches, editors) is still skipped.
    public static let frameworkHiddenDirs: Set<String> = [".kiro", ".taskmaster", ".specify"]

    /// Whether the walk enters folder `name` found under `parents` (folder names from the repo
    /// root down to its parent). `archive` is entered only as `openspec/changes/archive`, where
    /// OpenSpec keeps closed changes; elsewhere it stays skipped. Does not apply to the root.
    static func entersDirectory(_ name: String, under parents: [String]) -> Bool {
        if name == "archive" { return parents.suffix(2) == ["openspec", "changes"] }
        if name.hasPrefix(".") { return frameworkHiddenDirs.contains(name) }
        return !isSkipped(name)
    }

    /// `excluding`: repo paths the user switched off; they are found but left out.
    public static func repos(under roots: [String], excluding: Set<String> = []) -> [Repo] {
        var found: [Repo] = []
        for root in roots {
            // Real paths: FSEvents reports them, and relative paths need them.
            let url = URL(fileURLWithPath: realPath((root as NSString).expandingTildeInPath))
            let before = found.count
            walkForRepos(url, into: &found)
            // A plain folder with no git repo inside (notes, an example project) is one repo.
            if found.count == before, FileManager.default.fileExists(atPath: url.path) {
                found.append(Repo(name: url.lastPathComponent, path: url.path))
            }
        }
        // A repo reachable from two roots (`~/Repos` and `~/Repos/app`) is one repo: indexed twice, every definition showed twice.
        var seen = Set<String>()
        found = found.filter { seen.insert(realPath($0.path)).inserted }
        return excluding.isEmpty ? found : found.filter { !excluding.contains($0.path) }
    }

    /// Folders where people usually keep their repos, relative to the home folder.
    public static let candidateFolders = [
        "Repos", "repos", "code", "Code", "dev", "Developer", "Projects", "projects",
        "GitHub", "Documents/GitHub", "src",
    ]

    /// Candidate folders that exist under `home`, with how many git repos they hold (looking
    /// at most two levels down, so it stays fast). Folders with no repos are left out.
    public static func candidateRoots(home: String = NSHomeDirectory()) -> [(path: String, repos: Int)] {
        var seen = Set<String>()
        return candidateFolders.compactMap { name in
            let path = home + "/" + name
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue,
                  seen.insert(realPath(path).lowercased()).inserted else { return nil }
            let n = repoCount(in: URL(fileURLWithPath: path), depth: 2)
            return n > 0 ? (path, n) : nil
        }
    }

    static func repoCount(in dir: URL, depth: Int) -> Int {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path, isDirectory: &isDir) {
            return isDir.boolValue ? 1 : 0
        }
        guard depth > 0 else { return 0 }
        return subdirectories(of: dir).reduce(0) { $0 + repoCount(in: $1, depth: depth - 1) }
    }

    /// The path with every symlink resolved, as FSEvents reports it (`/tmp/x` → `/private/tmp/x`).
    /// Not `URL.resolvingSymlinksInPath()`: that one strips `/private` and goes the other way.
    public static func realPath(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return (path as NSString).standardizingPath }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// `file`'s path relative to `repo` (both with symlinks resolved), and its real absolute path.
    public static func paths(of file: URL, in repo: Repo) -> (relative: String, absolute: String) {
        let base = realPath(repo.path)
        let absolute = realPath(file.path)
        let relative = absolute.hasPrefix(base + "/") ? String(absolute.dropFirst(base.count + 1)) : file.lastPathComponent
        return (relative, absolute)
    }

    /// Markdown files of a repo, without descending into nested repos or worktrees.
    public static func markdownFiles(in repo: Repo) -> [URL] {
        var files: [URL] = []
        walkForMarkdown(URL(fileURLWithPath: repo.path), parents: nil, into: &files)
        return files.sorted { $0.path < $1.path }
    }

    private static func walkForRepos(_ dir: URL, into found: inout [Repo]) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let gitPath = dir.appendingPathComponent(".git").path
        // A `.git` *file* means a worktree or submodule: skip, its content duplicates the main repo.
        if fm.fileExists(atPath: gitPath, isDirectory: &isDir) {
            if isDir.boolValue { found.append(Repo(name: dir.lastPathComponent, path: dir.path)) }
            return
        }
        for child in subdirectories(of: dir) { walkForRepos(child, into: &found) }
    }

    /// `parents`: folder names from the repo root down to `dir`'s parent; nil for the root itself.
    private static func walkForMarkdown(_ dir: URL, parents: [String]?, into files: inout [URL]) {
        let fm = FileManager.default
        if parents != nil, fm.fileExists(atPath: dir.appendingPathComponent(".git").path) { return }
        // Hidden entries are listed: the closed list of framework folders lives among them.
        guard let items = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []
        ) else { return }
        for item in items {
            let name = item.lastPathComponent
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let chain = parents.map { $0 + [dir.lastPathComponent] } ?? []
                guard entersDirectory(name, under: chain) else { continue }
                walkForMarkdown(item, parents: chain, into: &files)
            } else if !name.hasPrefix("."), item.pathExtension.lowercased() == "md" {
                files.append(item)
            }
        }
    }

    private static func subdirectories(of dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        return items.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && !isSkipped($0.lastPathComponent)
        }.sorted { $0.path < $1.path }
    }

    /// Whether a changed file would be indexed: a `.md` inside `repo`, not under a skipped
    /// or hidden folder (bar the closed list of D043). Used by the file watcher to ignore noise.
    public static func isIndexed(path: String, in repo: Repo) -> Bool {
        guard path.lowercased().hasSuffix(".md"), path.hasPrefix(repo.path + "/") else { return false }
        let parts = path.dropFirst(repo.path.count + 1).split(separator: "/").map(String.init)
        guard let file = parts.last, !file.hasPrefix(".") else { return false }
        let folders = parts.dropLast()
        return folders.enumerated().allSatisfy { i, name in
            entersDirectory(name, under: Array(folders.prefix(i)))
        }
    }

    static func isSkipped(_ name: String) -> Bool {
        skippedDirs.contains(name) || name.hasSuffix("-worktrees") || name == "worktrees"
    }
}
