import Foundation
import LupitaCore

/// Holds the index in memory and keeps it current: a full build at launch, then per-repo
/// rebuilds driven by the file watcher (D7, D16). Work runs off the main thread, one job at a time.
@MainActor
final class IndexStore {
    private(set) var index: RefIndex?
    private(set) var resolver: Resolver?
    private(set) var updatedAt: Date?
    private(set) var isBuilding = false
    var onChange: (() -> Void)?

    /// Last measured rebuild time per repo, to decide whether a rescan fits in a lookup.
    private var rebuildCost: [String: Duration] = [:]
    private lazy var watcher = Watcher { [weak self] paths in self?.filesChanged(paths) }
    private var running = false
    private var queued: [String: Repo] = [:]
    private var rediscoverQueued = false
    private let defaultsKey = "roots"

    /// An install from before D24 never chose folders: it was indexing ~/Repos. Keep it so.
    /// Runs once at launch, before the first-run window can mark onboarding as shown.
    static func migrateLegacyRoots() {
        let defaults = UserDefaults.standard
        if defaults.stringArray(forKey: "roots") == nil, defaults.bool(forKey: "onboardingShown") {
            defaults.set(["~/Repos"], forKey: "roots")
        }
    }

    var roots: [String] {
        get {
            let defaults = UserDefaults.standard
            // Empty on a first run: the user picks the folders (D24).
            return defaults.stringArray(forKey: defaultsKey) ?? []
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey); rebuild() }
    }

    /// Folders and repos the user switched off (D28): kept in the list, left out of the index.
    var disabledRoots: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "disabledRoots") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "disabledRoots") }
    }
    var disabledRepos: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "disabledRepos") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "disabledRepos") }
    }
    private var activeRoots: [String] { roots.filter { !disabledRoots.contains($0) } }

    func setRoot(_ root: String, enabled: Bool) {
        if enabled { disabledRoots.remove(root) } else { disabledRoots.insert(root) }
        rebuild()
    }

    func setRepo(_ path: String, enabled: Bool) {
        if enabled { disabledRepos.remove(path) } else { disabledRepos.insert(path) }
        rebuild()
    }

    /// Several repos at once (a subfolder's switch), with one rebuild.
    func setRepos(_ paths: [String], enabled: Bool) {
        if enabled { disabledRepos.subtract(paths) } else { disabledRepos.formUnion(paths) }
        rebuild()
    }

    /// A folder that was moved: the new path takes its place, its switch and what was off inside it.
    func relocateRoot(_ root: String, to new: String) {
        let oldBase = RepoDiscovery.realPath((root as NSString).expandingTildeInPath)
        let newBase = RepoDiscovery.realPath(new)
        if disabledRoots.remove(root) != nil { disabledRoots.insert(new) }
        disabledRepos = Set(disabledRepos.map { $0 == oldBase || $0.hasPrefix(oldBase + "/") ? newBase + $0.dropFirst(oldBase.count) : $0 })
        roots = Array(Set(roots.map { $0 == root ? new : $0 })).sorted()
    }

    /// Forgets a folder and what was switched off inside it.
    func removeRoot(_ root: String) {
        let base = RepoDiscovery.realPath((root as NSString).expandingTildeInPath)
        disabledRoots.remove(root)
        disabledRepos = disabledRepos.filter { $0 != base && !$0.hasPrefix(base + "/") }
        roots = roots.filter { $0 != root }
    }

    var summary: String {
        guard let index else { return isBuilding ? S.indexing : S.noIndex }
        return S.summary(ids: index.definitions.count, repos: index.repos.count, files: index.fileCount)
    }

    var freshness: String {
        guard let updatedAt else { return "" }
        return S.updated(seconds: Int(Date().timeIntervalSince(updatedAt)))
    }

    /// Full build from the roots, and (re)start watching them.
    func rebuild() {
        isBuilding = true
        notify()
        let roots = activeRoots, excluding = disabledRepos
        watcher.watch(roots)
        Task.detached(priority: .utility) {
            let index = RefIndex.build(roots: roots, excluding: excluding)
            await self.install(index)
            await MainActor.run { self.isBuilding = false; self.notify() }
        }
    }

    /// Rebuilds one repo now and waits for it (lookup miss, D16). Returns false when the repo
    /// is unknown or too slow to rescan inside a lookup.
    func refreshNow(repoNamed name: String, budget: Duration = .milliseconds(300)) async -> Bool {
        // While a watcher job runs it is about to install a fresher index anyway.
        guard !running, let current = index, let repo = current.repos.first(where: { $0.name == name }),
              (rebuildCost[name] ?? .zero) <= budget else { return false }
        running = true
        defer { running = false; drain() }
        let start = ContinuousClock.now
        let fresh = await Task.detached(priority: .userInitiated) { () -> RefIndex in
            var copy = current
            copy.rebuild(repo: repo)
            return copy
        }.value
        rebuildCost[name] = ContinuousClock.now - start
        install(fresh)
        return true
    }

    private func filesChanged(_ paths: [String]) {
        guard let index else { return }
        // A repo appeared or vanished (`.git` created/removed directly under a folder).
        if paths.contains(where: { $0.hasSuffix("/.git") }) { rediscoverQueued = true }
        for path in paths {
            if let repo = index.repos.first(where: { RepoDiscovery.isIndexed(path: path, in: $0) }) {
                queued[repo.name] = repo
            }
        }
        drain()
    }

    /// Runs queued work one job at a time, so concurrent rebuilds never overwrite each other.
    private func drain() {
        guard !running, var index, rediscoverQueued || !queued.isEmpty else { return }
        running = true
        let repos = Array(queued.values), rediscover = rediscoverQueued, roots = activeRoots, excluding = disabledRepos
        queued = [:]
        rediscoverQueued = false
        Task.detached(priority: .utility) {
            var costs: [String: Duration] = [:]
            if rediscover { index.sync(repos: RepoDiscovery.repos(under: roots, excluding: excluding)) }
            for repo in repos where index.repos.contains(repo) {
                let start = ContinuousClock.now
                index.rebuild(repo: repo)
                costs[repo.name] = ContinuousClock.now - start
            }
            await MainActor.run {
                self.rebuildCost.merge(costs) { $1 }
                self.install(index)
                self.running = false
                self.drain()
            }
        }
    }

    static let changed = Notification.Name("LupitaIndexChanged")
    private func notify() {
        onChange?()
        NotificationCenter.default.post(name: Self.changed, object: self)
    }

    private func install(_ index: RefIndex) {
        self.index = index
        resolver = Resolver(index: index)
        updatedAt = Date()
        notify()
    }
}

/// Watcher failures, in ~/Library/Logs/Lupita/watch.log (events themselves are not logged:
/// every file change under the roots would land there).
enum WatchLog {
    static func append(_ line: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Lupita/watch.log")
        let text = ISO8601DateFormatter().string(from: Date()) + " " + line + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(text.utf8)); try? handle.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
