import Foundation
import Testing
@testable import LupitaCore

// The git search for a tracker key runs off the main thread; the card appears once, finished: with the commit, or the notice.

@Suite(.serialized) struct TrackerOffMainTests {
    let root: URL
    let repo: Repo

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-offmain-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("atlas")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        repo = Repo(name: "atlas", path: RepoDiscovery.realPath(dir.path))
        if Git.executable != nil {
            git("init", "-q", "-b", "main")
            try "x\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "fix crash on save (PLAT-443341)")
            git("commit", "-q", "--allow-empty", "-m", "cache me (PLAT-555001)")
        }
    }

    @discardableResult
    func git(_ args: String...) -> String? {
        Git.output(repo.path, ["-c", "user.name=T", "-c", "user.email=t@example.com"] + args)
    }

    func resolver(slowGit: TimeInterval? = nil) -> Resolver {
        var index = RefIndex()
        index.repos = [repo]
        index.rank()
        var r = Resolver(index: index)
        if let slowGit {
            r.commitSearch = { key, repo, timeout in
                Thread.sleep(forTimeInterval: slowGit)   // a `git` that takes this long
                return RepoRefs.commitCiting(key, repo: repo, timeout: timeout)
            }
        }
        return r
    }

    static func seconds(_ body: () -> Void) -> TimeInterval {
        let start = Date()
        body()
        return Date().timeIntervalSince(start)
    }

    @Test func withGitOffResolveDoesNotWaitForGit() {
        let slow = resolver(slowGit: 1.5)
        // Before: with git on the lookup waits for the slow git.
        let before = Self.seconds { _ = slow.resolve("PLAT-443341", preferredRepo: "atlas") }
        #expect(before > 1.4)
        // After: with git off the main thread is free (< 50 ms) and the key comes back as a pending one.
        let fast = slow.withoutGit()
        var result: Resolution?
        let after = Self.seconds {
            result = fast.resolve("PLAT-443341", preferredRepo: "atlas")
            _ = fast.hasTrackerCommit(RefID(display: "PLAT-443341", key: "PLAT443341", prefix: "PLAT"), preferredRepo: "atlas")
        }
        #expect(after < 0.05)
        #expect(result?.kind == .undefined)
        #expect(result.flatMap { fast.pendingTrackerKey($0) }?.display == "PLAT-443341")
    }

    @Test func theCardIsPresentedOnceWithTheCommit() throws {
        guard Git.executable != nil else { return }
        let fast = resolver().withoutGit()
        let undefined = fast.resolve("PLAT-443341", preferredRepo: "atlas")
        let id = try #require(fast.pendingTrackerKey(undefined))
        // With git off nothing is shown for the key: no provisional card, only the key to search for.
        #expect(!undefined.isShown)
        // The one card that is presented has the commit the lookup with git on gives.
        let filled = try #require(resolver().trackerResolution(query: "PLAT-443341", id: id, preferredRepo: "atlas"))
        let direct = resolver().resolve("PLAT-443341", preferredRepo: "atlas")
        #expect(filled.definitions == direct.definitions && filled.isShown)
        #expect(filled.definitions.first?.title == "fix crash on save (PLAT-443341)")
        // From another repo's window it is flagged, as before.
        let other = try #require(resolver().trackerResolution(query: "PLAT-443341", id: id, preferredRepo: "other"))
        #expect(other.fromOtherRepo)
    }

    @Test func aKeyWithoutCommitOrBranchGivesNoCard() throws {
        guard Git.executable != nil else { return }
        let fast = resolver().withoutGit()
        let undefined = fast.resolve("PLAT-12345", preferredRepo: "atlas")
        let id = try #require(fast.pendingTrackerKey(undefined))
        #expect(resolver().trackerResolution(query: "PLAT-12345", id: id, preferredRepo: "atlas") == nil)
    }

    @Test func standardsAndLabelsAreNeverPending() {
        let fast = resolver().withoutGit()
        #expect(fast.pendingTrackerKey(fast.resolve("GPT-4", preferredRepo: "atlas")) == nil)
        #expect(fast.pendingTrackerKey(fast.resolve("FR-004", preferredRepo: "atlas")) == nil)
    }

    @Test func theHighlightReadsTheCacheWithoutGitAndLearnsFromAPassWithGit() throws {
        guard Git.executable != nil else { return }
        // A key no other suite looks up, so its 30-second cache entry starts empty.
        var index = RefIndex(); index.repos = [repo]; index.rank()
        let id = RefID(display: "PLAT-555001", key: "PLAT555001", prefix: "PLAT")
        _ = Resolver.takeUncachedTrackerKeys()
        let fast = Resolver(index: index).withoutGit()
        let cold = Self.seconds { #expect(!fast.hasTrackerCommit(id)) }
        #expect(cold < 0.05)
        #expect(Resolver.takeUncachedTrackerKeys())          // asks for the pass with git
        #expect(Resolver(index: index).hasTrackerCommit(id)) // the pass with git
        #expect(fast.hasTrackerCommit(id))                   // now the cache answers
        #expect(!Resolver.takeUncachedTrackerKeys())
    }
}
