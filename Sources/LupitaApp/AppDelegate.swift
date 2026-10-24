import AppKit
import LupitaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = IndexStore()
    let tooltip = TooltipPanel()
    let lens = CursorLens()
    var menu: StatusMenu?
    var trigger: Trigger?
    var onboarding: OnboardingWindow?
    private var inFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu = StatusMenu(store: store) { [weak self] choice in
            HotkeyChoice.current = choice
            self?.installTrigger()
        }
        onboarding = OnboardingWindow(store: store) { [weak self] in self?.menu?.addRoot() }
        menu?.onPrepareRepos = { [weak self] in self?.onboarding?.show() }
        tooltip.onClose = { [weak self] in self?.lens.tooltipClosed() }
        installTrigger()
        // Dev aid: `lupita poke` does what ⌃⌥R does, for automated checks that cannot press keys.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.manubarranco.lupita.lookup"),
                                                            object: nil, queue: .main) { [weak self] note in
            let query = note.userInfo?["query"] as? String, repo = note.userInfo?["repo"] as? String
            let lens = (note.userInfo?["lens"] as? String).flatMap(Double.init)
            let at = (note.userInfo?["at"] as? String).map { $0.split(separator: ",").compactMap { Double($0) } }
            MainActor.assumeIsolated {
                if let lens {
                    self?.lens.begin()
                    Task { try? await Task.sleep(for: .seconds(lens)); self?.lens.end() }
                } else if let query {
                    self?.lookUp(query: query, repo: repo, at: at.flatMap { $0.count == 2 ? NSPoint(x: $0[0], y: $0[1]) : nil })
                } else { self?.lookUp() }
            }
        }
        store.rebuild()
        Permissions.explainIfNeeded()
        // First run: once the first index exists, offer to prepare the repos (D21).
        Task { @MainActor [weak self] in
            while self?.store.index == nil { try? await Task.sleep(for: .milliseconds(300)) }
            self?.onboarding?.showFirstTimeIfNeeded()
        }
    }

    func installTrigger() {
        trigger = nil
        lens.end()
        trigger = makeTrigger(HotkeyChoice.current, hold: { [weak self] down in
            if down { self?.lens.begin() } else { self?.lens.end() }
        }) { [weak self] in self?.lookUp() }
    }

    /// Hotkey pressed: read the text under the cursor, resolve it, show the tooltip.
    func lookUp() {
        // Presses while an OCR pass runs are dropped, not queued.
        guard !inFlight else { return }
        let start = Date()
        let mouse = NSEvent.mouseLocation  // bottom-left origin
        let point = Screen.topLeft(mouse)  // what AX and ScreenCaptureKit use
        lens.keep()
        guard let resolver = store.resolver else {
            notice(S.indexingTryAgain, at: mouse)
            return
        }
        let context = ActiveContext.at(point, resolver: resolver)

        var ax = TextUnderCursor.viaAccessibility(at: point)
        if let text = ax.hit {
            let result = CandidatePicker.pick(line: text.line, cursorOffset: text.offset, resolver: resolver,
                                              preferredRepo: context.repo, fromPath: context.path)
            // AX gave text but no word at the cursor (e.g. offset unknown): let OCR try.
            if let result {
                show(result, at: mouse, method: "ax:\(text.via)", start: start, context: context)
                return
            }
            // Text came back but no word at the offset: record what AX said, to see why.
            ax.diagnostic = "\(text.via) off=\(text.offset) len=\((text.line as NSString).length) “\(text.line.prefix(80))”"
        }
        inFlight = true
        Task {
            defer { inFlight = false }
            let words = (try? await OCR.words(around: point)) ?? []
            let result = CandidatePicker.pick(words: words, cursor: point, resolver: resolver,
                                              preferredRepo: context.repo, fromPath: context.path)
            show(result, at: mouse, method: (words.isEmpty ? "none" : "ocr") + "<\(ax.diagnostic)>",
                 start: start, context: context)
        }
    }

    /// Looks like an ID but nothing defines it: an agent may have just written it. Rescan the
    /// window's repo once (D16) before saying "not known"; the watcher covers the rest.
    private func show(_ result: Resolution?, at mouse: NSPoint?, method: String, start: Date, context: ActiveContext) {
        guard let result, result.kind == .undefined, let repo = context.repo else {
            present(result, at: mouse, method: method, start: start, app: context.bundleID)
            return
        }
        Task {
            if await store.refreshNow(repoNamed: repo),
               let again = store.resolver?.resolve(result.query, preferredRepo: repo, fromPath: context.path),
               again.kind != .undefined {
                present(again, at: mouse, method: method + "+rescan", start: start, app: context.bundleID)
            } else {
                present(result, at: mouse, method: method, start: start, app: context.bundleID)
            }
        }
    }

    /// `mouse == nil`: a `lupita poke --query` check, logged but not shown.
    private func present(_ result: Resolution?, at mouse: NSPoint?, method: String, start: Date, app: String?) {
        if let mouse {
            switch result?.kind {
            case .exact?, .corrected?, .ambiguous?:
                tooltip.show(result!, at: mouse)
                lens.react(found: true, near: tooltip.frame)
            default:
                notice(S.notAReference, at: mouse)
            }
        }
        TriggerLog.append(app: app, method: method, ms: Int(Date().timeIntervalSince(start) * 1000), result: result)
    }

    /// With the lens beside it, the notice closes 2 s after the lens gets there (D18); without
    /// the lens, after about the same time.
    private func notice(_ text: String, at mouse: NSPoint) {
        tooltip.showNotice(text, at: mouse)
        let reacting = lens.react(found: false, near: tooltip.frame) { [weak self] in self?.tooltip.close() }
        if !reacting { tooltip.close(after: 3.5) }
    }

    /// Dev aid: resolve a given text without reading the screen (`lupita poke --query D001 --repo atlas`).
    /// With `at` (`--at 400,600`, Cocoa screen points) the tooltip is shown there, for screenshots.
    func lookUp(query: String, repo: String?, at point: NSPoint? = nil) {
        guard let resolver = store.resolver else { return }
        var context = ActiveContext()
        context.repo = repo
        context.bundleID = "poke"
        show(resolver.resolve(query, preferredRepo: repo), at: point, method: "query", start: Date(), context: context)
    }
}

enum Screen {
    /// Cocoa global coordinates (origin bottom-left of the main screen) → top-left origin.
    static func topLeft(_ p: NSPoint) -> CGPoint {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: height - p.y)
    }
}

/// One line per lookup in ~/Library/Logs/Lupita/lookups.log: the app × method × latency matrix.
/// Only with `Debug.isOn`: it records what was looked up.
enum TriggerLog {
    static func append(app: String?, method: String, ms: Int, result: Resolution?) {
        guard Debug.isOn else { return }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Lupita")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("lookups.log")
        let line = [ISO8601DateFormatter().string(from: Date()), app ?? "?", method, "\(ms)ms",
                    result?.query ?? "-", result?.kind.rawValue ?? "nil", result?.key ?? "-",
                    result?.definitions.first?.repo ?? "-"].joined(separator: "\t") + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
