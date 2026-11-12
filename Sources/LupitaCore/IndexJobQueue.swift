import Foundation

/// Decides which index job runs next, one at a time. No threads and no index here: the app asks
/// `next()`, does the work, and calls `finished()`. Kept apart so the ordering rules are testable.
public struct IndexJobQueue: Sendable {
    public enum Job: Equatable, Sendable {
        /// Build everything from the current roots.
        case full
        /// Rescan these repos (sorted by name); `rediscover`: first follow repos that appeared or vanished.
        case repos([Repo], rediscover: Bool)
    }

    public private(set) var isRunning = false
    private var queued: [String: Repo] = [:]
    private var rediscoverQueued = false
    private var fullQueued = false

    public init() {}

    /// A full build is waiting.
    public var fullRequested: Bool { fullQueued }

    public mutating func requestFull() { fullQueued = true }
    public mutating func requestRediscover() { rediscoverQueued = true }
    /// Keyed by name: asking twice for the same repo is one rescan.
    public mutating func request(_ repo: Repo) { queued[repo.name] = repo }

    /// The job to start now, marking the queue as running; nil while one runs or when nothing waits.
    /// A full build goes first and supersedes the queued repo work (what arrives while it runs is
    /// requested again and served afterwards). Repo work needs an index to patch: without one it stays queued.
    public mutating func next(hasIndex: Bool) -> Job? {
        guard !isRunning else { return nil }
        if fullQueued {
            fullQueued = false
            queued = [:]
            rediscoverQueued = false
            isRunning = true
            return .full
        }
        guard hasIndex, rediscoverQueued || !queued.isEmpty else { return nil }
        let job = Job.repos(queued.values.sorted { $0.name < $1.name }, rediscover: rediscoverQueued)
        queued = [:]
        rediscoverQueued = false
        isRunning = true
        return job
    }

    public mutating func finished() { isRunning = false }

    /// A lookup's own rescan may start only when nothing runs and no full build waits (that build is about
    /// to install a fresher index anyway). Marks the queue as running when it says yes.
    public mutating func beginRefresh() -> Bool {
        guard !isRunning, !fullQueued else { return false }
        isRunning = true
        return true
    }
}
