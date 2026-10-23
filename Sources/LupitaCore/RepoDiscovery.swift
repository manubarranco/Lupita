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

    public static func repos(under roots: [String]) -> [Repo] {
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
        return found
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
        walkForMarkdown(URL(fileURLWithPath: repo.path), isRoot: true, into: &files)
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

    private static func walkForMarkdown(_ dir: URL, isRoot: Bool, into files: inout [URL]) {
        let fm = FileManager.default
        if !isRoot, fm.fileExists(atPath: dir.appendingPathComponent(".git").path) { return }
        guard let items = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return }
        for item in items {
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                guard !isSkipped(item.lastPathComponent) else { continue }
                walkForMarkdown(item, isRoot: false, into: &files)
            } else if item.pathExtension.lowercased() == "md" {
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
    /// or hidden folder. Used by the file watcher to ignore noise.
    public static func isIndexed(path: String, in repo: Repo) -> Bool {
        guard path.lowercased().hasSuffix(".md"), path.hasPrefix(repo.path + "/") else { return false }
        let folders = path.dropFirst(repo.path.count + 1).split(separator: "/").dropLast()
        return !folders.contains { $0.hasPrefix(".") || isSkipped(String($0)) }
    }

    static func isSkipped(_ name: String) -> Bool {
        skippedDirs.contains(name) || name.hasSuffix("-worktrees") || name == "worktrees"
    }
}
