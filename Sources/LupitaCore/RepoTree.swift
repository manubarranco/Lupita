import Foundation

/// The repos of a folder as the menu shows them: a subfolder that holds repos is its own row with
/// its own switch, and a folder with a single repo inside collapses into that repo's row
/// (`Archived › old-site`), so there is nothing to open for one repo.
public indirect enum RepoNode: Equatable, Sendable {
    case repo(Repo, title: String)
    case folder(path: String, title: String, children: [RepoNode])

    public var title: String {
        switch self {
        case .repo(_, let title), .folder(_, let title, _): title
        }
    }

    /// Every repo at or under this node.
    public var repos: [Repo] {
        switch self {
        case .repo(let repo, _): [repo]
        case .folder(_, _, let children): children.flatMap(\.repos)
        }
    }

    func titled(_ title: String) -> RepoNode {
        switch self {
        case .repo(let repo, _): .repo(repo, title: title)
        case .folder(let path, _, let children): .folder(path: path, title: title, children: children)
        }
    }
}

/// On, off or some of each: what a folder's switch shows.
public enum SwitchState: Sendable {
    case on, off, mixed
}

public enum RepoTree {
    /// Separates the folders of a collapsed row's title.
    public static let separator = " › "

    /// The rows under `root`, from the repos `RepoDiscovery` found there. When the root is itself the
    /// repo, that repo is the only row.
    public static func build(root: String, repos: [Repo]) -> [RepoNode] {
        let base = RepoDiscovery.realPath((root as NSString).expandingTildeInPath)
        var top = Dir()
        for repo in repos {
            guard repo.path != base else { return [.repo(repo, title: repo.name)] }
            guard repo.path.hasPrefix(base + "/") else { continue }
            let parts = repo.path.dropFirst(base.count + 1).split(separator: "/").map(String.init)
            top.insert(repo, at: parts[...])
        }
        return top.nodes(at: base)
    }

    /// All on, all off, or mixed. No repos reads as on: there is nothing switched off.
    public static func state(of repos: [Repo], disabled: Set<String>) -> SwitchState {
        let off = repos.filter { disabled.contains($0.path) }.count
        if off == 0 { return .on }
        return off == repos.count ? .off : .mixed
    }

    private struct Dir {
        var repos: [String: Repo] = [:]
        var dirs: [String: Dir] = [:]

        mutating func insert(_ repo: Repo, at parts: ArraySlice<String>) {
            guard let first = parts.first else { return }
            if parts.count == 1 { repos[first] = repo; return }
            dirs[first, default: Dir()].insert(repo, at: parts.dropFirst())
        }

        func nodes(at path: String) -> [RepoNode] {
            let names = Set(repos.keys).union(dirs.keys).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return names.compactMap { name in
                if let repo = repos[name] { return .repo(repo, title: name) }
                guard let dir = dirs[name] else { return nil }
                let children = dir.nodes(at: path + "/" + name)
                if children.count == 1 { return children[0].titled(name + RepoTree.separator + children[0].title) }
                return .folder(path: path + "/" + name, title: name, children: children)
            }
        }
    }
}
