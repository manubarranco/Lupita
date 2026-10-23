import CoreServices
import Foundation
import LupitaCore

/// Watches the root folders with FSEvents (D7) and reports, in batches, which paths changed.
@MainActor
final class Watcher {
    private var stream: FSEventStreamRef?
    private let onChange: ([String]) -> Void
    private var pending: Set<String> = []
    private var flush: Task<Void, Never>?
    /// Changes are grouped: an agent writing 10 files triggers one reindex.
    static let batchDelay: Duration = .milliseconds(1500)

    init(onChange: @escaping ([String]) -> Void) {
        self.onChange = onChange
    }

    func watch(_ roots: [String]) {
        stop()
        let paths = roots.map { RepoDiscovery.realPath(($0 as NSString).expandingTildeInPath) }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<Watcher>.fromOpaque(info).takeUnretainedValue()
            let paths = (unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []).prefix(count)
            MainActor.assumeIsolated { watcher.received(Array(paths)) }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)
        else { WatchLog.append("FSEventStreamCreate failed"); return }
        FSEventStreamSetDispatchQueue(stream, .main)
        if !FSEventStreamStart(stream) { WatchLog.append("FSEventStreamStart failed for \(paths)") }
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func received(_ paths: [String]) {
        pending.formUnion(paths)
        flush?.cancel()
        flush = Task { [weak self] in
            try? await Task.sleep(for: Self.batchDelay)
            guard !Task.isCancelled, let self else { return }
            let batch = Array(self.pending)
            self.pending = []
            self.onChange(batch)
        }
    }
}
