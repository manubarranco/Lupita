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
    let idReport = IDReportWindow()
    let appearance = AspectoWindow()
    private var inFlight = false
    let highlight = HighlightOverlay()
    /// Held this long, ⌃⌥⌘ is no longer a quick press: it shows what Lupita knows (D39). The window is
    /// read from the moment the keys go down, so the marks show as soon as this ends.
    private static let holdThreshold: Duration = .milliseconds(250)
    private var holdTask: Task<Void, Never>?
    private var holdGeneration = 0
    /// What the OCR read for the marks, kept so the lookup on release does not read the window again.
    /// Dropped when the text may have moved (scroll, another app) and at the next hold.
    private var windowRead: OCR.WindowRead?
    private var currentHold: HoldGeneration?
    private var scrollMonitors: [Any] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        IndexStore.migrateLegacyRoots()
        LoginItem.turnOnOnce()
        VocabularyPackages.apply()
        menu = StatusMenu(store: store) { [weak self] choice in
            HotkeyChoice.current = choice
            self?.installTrigger()
        }
        onboarding = OnboardingWindow(store: store) { [weak self] in self?.menu?.addRoot() }
        menu?.onPrepareRepos = { [weak self] in self?.onboarding?.show() }
        menu?.onIDReport = { [weak self] in self.map { $0.idReport.show(index: $0.store.index) } }
        menu?.onAppearance = { [weak self] in self?.appearance.show() }
        tooltip.onClose = { [weak self] in self?.lens.tooltipClosed() }
        installTrigger()
        // Dev aid: `lupita poke` does what the shortcut does, for automated checks that cannot press keys.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.manubarranco.lupita.lookup"),
                                                            object: nil, queue: .main) { [weak self] note in
            let query = note.userInfo?["query"] as? String, repo = note.userInfo?["repo"] as? String
            let lens = (note.userInfo?["lens"] as? String).flatMap(Double.init)
            let hold = (note.userInfo?["hold"] as? String).flatMap(Double.init)
            let openOnboarding = note.userInfo?["onboarding"] != nil
            let openAbout = note.userInfo?["about"] != nil
            let menuMode = note.userInfo?["menu"] as? String
            let at = (note.userInfo?["at"] as? String).map { $0.split(separator: ",").compactMap { Double($0) } }
            MainActor.assumeIsolated {
                if menuMode == "confirm" {
                    self?.menu?.confirmRemove(self?.store.roots.first ?? "~/Repos", dryRun: true)
                } else if let menuMode {
                    self?.menu?.open(expanding: menuMode == "expand")
                } else if openAbout {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(options: [.applicationVersion: Updater.installedVersion])
                } else if openOnboarding {
                    self?.onboarding?.show()
                } else if let hold {
                    self?.holdChanged(true)
                    Task { try? await Task.sleep(for: .seconds(hold)); self?.holdChanged(false) }
                } else if let lens {
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
            self?.holdChanged(down)
        }) { [weak self] in self?.lookUp() }
    }

    // MARK: Highlight mode (D39)

    private func holdChanged(_ down: Bool) {
        holdGeneration += 1
        holdTask?.cancel()
        holdTask = nil
        if down {
            windowRead = nil
            let generation = holdGeneration
            // Read while waiting: a quick press throws the read away, a hold has it ready.
            let point = Screen.topLeft(NSEvent.mouseLocation)
            let read = Task { try? await OCR.window(at: point) }
            if let resolver = store.resolver { Task.detached(priority: .userInitiated) { HighlightPicker.warm(resolver: resolver) } }
            holdTask = Task { [weak self] in
                try? await Task.sleep(for: Self.holdThreshold)
                guard !Task.isCancelled, let self, generation == holdGeneration else { return }
                showHighlight(generation, read: read)
            }
        } else {
            stopHighlight()
        }
    }

    private func showHighlight(_ generation: Int, read pending: Task<OCR.WindowRead?, Never>) {
        guard let resolver = store.resolver, !inFlight else { return }
        Task { [weak self] in
            let read = await pending.value
            guard let self, generation == holdGeneration, let read else { return }
            let marks = HighlightPicker.classified(words: read.words, resolver: resolver)
            windowRead = read
            if Debug.isOn {
                // Why a form like `(Task 2.3,` is underlined as a bare term: the exact words and boxes OCR gave for its row.
                for row in HighlightPicker.rows(of: read.words) {
                    for (i, w) in row.enumerated() where i + 1 < row.count && w.text.contains("ask") && row[i + 1].text.contains(where: \.isNumber) {
                        VocabularyLog.append(["highlight-row", row.map { "«\($0.text)» \(Int($0.box.minX))-\(Int($0.box.maxX))" }.joined(separator: " ")])
                    }
                }
            }
            highlight.show(marks.map { ($0.box, HighlightPicker.isDark(behind: $0.box, words: read.words) ?? read.isDark, $0.kind) })
            watchForChanges()
            showSymbols(generation, read: read, marks: marks, resolver: resolver)
        }
    }

    /// The second layer (D53): symbols are looked up after the first marks are up, and each one is underlined
    /// as its answer comes back. Letting go, scrolling or switching app stops the lookups not yet started.
    private func showSymbols(_ generation: Int, read: OCR.WindowRead, marks: [HighlightPicker.Mark], resolver: Resolver) {
        let candidates = HighlightPicker.symbolCandidates(words: read.words, excluding: marks)
        guard !candidates.isEmpty else { return }
        let live = HoldGeneration(generation)
        currentHold?.end()
        currentHold = live
        let words = read.words, windowDark = read.isDark, pointer = Screen.topLeft(NSEvent.mouseLocation)
        Task.detached(priority: .userInitiated) {
            HighlightPicker.findSymbols(candidates, resolver: resolver, near: pointer, stop: { !live.isCurrent }) { found in
                Task { @MainActor [weak self] in
                    guard let self, live.isCurrent, self.highlight.showing else { return }
                    self.highlight.add(found.map { ($0.box, HighlightPicker.isDark(behind: $0.box, words: words) ?? windowDark, $0.kind) })
                }
            }
        }
    }

    private func stopHighlight() {
        currentHold?.end()
        scrollMonitors.forEach(NSEvent.removeMonitor)
        scrollMonitors = []
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        highlight.hide()
    }

    /// Scrolling or switching app moves the text from under the marks: they go away without a fade, and
    /// stay away until the shortcut is pressed again.
    private func watchForChanges() {
        let gone: () -> Void = { [weak self] in MainActor.assumeIsolated { self?.windowRead = nil; self?.currentHold?.end(); self?.highlight.hide(animated: false) } }
        scrollMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { _ in gone() } as Any)
        scrollMonitors.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { gone(); return $0 } as Any)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in gone() }
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
        // Pointing at the tooltip itself: read it by OCR (its text is not reachable through AX) and look
        // up in the repo and file of what it shows, so `answered by D006` resolves where Q01 lives.
        if let shown = tooltip.resolution, let frame = tooltip.frame, frame.contains(mouse) {
            var context = ActiveContext()
            context.bundleID = Bundle.main.bundleIdentifier
            context.repo = shown.definitions.first?.repo
            context.path = shown.definitions.first?.path
            inFlight = true
            let keeping = tooltip.windowID
            Task {
                defer { inFlight = false }
                let words = (try? await OCR.words(around: point, keeping: keeping)) ?? []
                let result = CandidatePicker.pick(words: words, cursor: point, resolver: resolver,
                                                  preferredRepo: context.repo, fromPath: context.path)
                show(result, at: mouse, method: (words.isEmpty ? "none" : "ocr") + "<tooltip>",
                     start: start, context: context)
            }
            return
        }
        let context = ActiveContext.at(point, resolver: resolver)

        var ax = TextUnderCursor.viaAccessibility(at: point)
        var axMiss: Resolution?
        if let text = ax.hit {
            let result = CandidatePicker.pick(line: text.line, cursorOffset: text.offset, resolver: resolver,
                                              preferredRepo: context.repo, fromPath: context.path, codeRanges: text.codeRanges)
            // Accessibility answered but nothing was explained: ask OCR too before saying «not known» (D42). AX can
            // give the text without the code box (`main` in inline code has no context), or the text of the
            // wrong word (a static text whose offset is only estimated); OCR sees the screen as it is.
            let word = CandidatePicker.word(in: text.line, cursorOffset: text.offset)
            let ambiguousMiss = result == nil || result?.kind == .notAnID
            axMiss = result
            if Debug.isOn {
                let word = word ?? "?"
                VocabularyLog.append(["ax:\(text.via)", "word=\(word)", "line=“\(text.line.prefix(160))”", "fonts=\(text.fontNote)",
                                      "codeRanges=\(text.codeRanges.count)", GitVocabulary.diagnose(word, block: text.line, marked: !text.codeRanges.isEmpty),
                                      "shown=\(result?.isShown ?? false)", ambiguousMiss ? "→ asking OCR" : "→ answered by AX"])
            }
            // AX gave text but no word at the cursor (e.g. offset unknown): let OCR try.
            if let result, !ambiguousMiss {
                show(result, at: mouse, method: "ax:\(text.via)", start: start, context: context)
                return
            }
            // Text came back but no word at the offset: record what AX said, to see why.
            ax.diagnostic = "\(text.via) off=\(text.offset) len=\((text.line as NSString).length) “\(text.line.prefix(80))”"
        }
        // Released after a hold: the window was already read for the marks.
        let reused = windowRead.flatMap { $0.frame.contains(point) ? $0.words : nil }
        inFlight = true
        Task {
            defer { inFlight = false }
            let words = if let reused { reused } else { (try? await OCR.words(around: point)) ?? [] }
            let result = CandidatePicker.pick(words: words, cursor: point, resolver: resolver,
                                              preferredRepo: context.repo, fromPath: context.path)
            if Debug.isOn, let target = CandidatePicker.word(under: point, in: words) {
                let block = HighlightPicker.nearbyText(of: target, in: words)
                VocabularyLog.append(["ocr\(reused == nil ? "" : "+reused")", "word=\(target.text)", "codeStyled=\(target.codeStyled)",
                                      "block=“\(block.prefix(160))”", GitVocabulary.diagnose(target.text, block: block, marked: target.codeStyled),
                                      "shown=\(result?.isShown ?? false)"])
            }
            // OCR found nothing either: say what AX said (the same «not known», as before).
            show(result?.isShown == true ? result : (axMiss ?? result), at: mouse,
                 method: (words.isEmpty ? "none" : "ocr") + "<\(ax.diagnostic)>", start: start, context: context)
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
        if !reacting { tooltip.close(after: 2) }
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

/// Whether a hold of the shortcut is still the current one, readable from the symbol lookups' threads.
final class HoldGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var ended = false
    let value: Int
    init(_ value: Int) { self.value = value }
    var isCurrent: Bool { lock.lock(); defer { lock.unlock() }; return !ended }
    func end() { lock.lock(); ended = true; lock.unlock() }
}
