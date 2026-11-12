import Testing
@testable import LupitaCore

// Which index job runs next: one at a time, a full build supersedes repo work.

@Suite struct IndexJobQueueTests {
    let a = Repo(name: "a", path: "/r/a")
    let b = Repo(name: "b", path: "/r/b")

    @Test func emptyQueueGivesNothing() {
        var queue = IndexJobQueue()
        #expect(queue.next(hasIndex: true) == nil)
        #expect(queue.next(hasIndex: false) == nil)
        #expect(!queue.isRunning)
    }

    @Test func fullRequestRunsEvenWithoutIndex() {
        var queue = IndexJobQueue()
        queue.requestFull()
        #expect(queue.fullRequested)
        #expect(queue.next(hasIndex: false) == .full)
        #expect(queue.isRunning)
        #expect(!queue.fullRequested)
    }

    @Test func repoWorkWaitsForAnIndex() {
        var queue = IndexJobQueue()
        queue.request(a)
        queue.requestRediscover()
        #expect(queue.next(hasIndex: false) == nil)
        #expect(!queue.isRunning)
        #expect(queue.next(hasIndex: true) == .repos([a], rediscover: true))
    }

    @Test func rediscoverAloneIsAJob() {
        var queue = IndexJobQueue()
        queue.requestRediscover()
        #expect(queue.next(hasIndex: true) == .repos([], rediscover: true))
    }

    @Test func fullRequestSupersedesQueuedRepos() {
        var queue = IndexJobQueue()
        queue.request(a)
        queue.requestRediscover()
        queue.requestFull()
        #expect(queue.next(hasIndex: true) == .full)
        queue.finished()
        #expect(queue.next(hasIndex: true) == nil)
    }

    @Test func nothingStartsWhileRunning() {
        var queue = IndexJobQueue()
        queue.request(a)
        #expect(queue.next(hasIndex: true) == .repos([a], rediscover: false))
        queue.request(b)
        queue.requestFull()
        #expect(queue.next(hasIndex: true) == nil)
    }

    @Test func fullRequestDuringAJobRunsAfterIt() {
        var queue = IndexJobQueue()
        queue.request(a)
        _ = queue.next(hasIndex: true)
        queue.requestFull()
        #expect(queue.fullRequested)
        queue.finished()
        #expect(queue.fullRequested)
        #expect(queue.next(hasIndex: true) == .full)
        #expect(!queue.fullRequested)
    }

    @Test func twoFullRequestsWhileRunningCollapseIntoOne() {
        var queue = IndexJobQueue()
        queue.requestFull()
        _ = queue.next(hasIndex: false)
        queue.requestFull()
        queue.requestFull()
        queue.finished()
        #expect(queue.next(hasIndex: true) == .full)
        queue.finished()
        #expect(queue.next(hasIndex: true) == nil)
    }

    @Test func repoRequestedDuringAFullBuildRunsAfterIt() {
        var queue = IndexJobQueue()
        queue.requestFull()
        _ = queue.next(hasIndex: false)
        queue.request(a)
        #expect(queue.next(hasIndex: true) == nil)
        queue.finished()
        #expect(queue.next(hasIndex: true) == .repos([a], rediscover: false))
    }

    @Test func refreshIsRefusedWhileRunning() {
        var queue = IndexJobQueue()
        queue.request(a)
        _ = queue.next(hasIndex: true)
        let started = queue.beginRefresh()
        #expect(!started)
    }

    @Test func refreshIsRefusedWhileAFullBuildWaits() {
        var queue = IndexJobQueue()
        queue.requestFull()
        let started = queue.beginRefresh()
        #expect(!started)
        #expect(!queue.isRunning)
    }

    @Test func refreshMarksRunningAndBlocksOthers() {
        var queue = IndexJobQueue()
        let started = queue.beginRefresh()
        #expect(started)
        #expect(queue.isRunning)
        queue.request(a)
        #expect(queue.next(hasIndex: true) == nil)
        queue.finished()
        #expect(queue.next(hasIndex: true) == .repos([a], rediscover: false))
    }

    @Test func theSameRepoTwiceAppearsOnce() {
        var queue = IndexJobQueue()
        queue.request(a)
        queue.request(a)
        #expect(queue.next(hasIndex: true) == .repos([a], rediscover: false))
    }

    @Test func reposComeSortedByName() {
        var queue = IndexJobQueue()
        queue.request(b)
        queue.request(a)
        #expect(queue.next(hasIndex: true) == .repos([a, b], rediscover: false))
    }
}
