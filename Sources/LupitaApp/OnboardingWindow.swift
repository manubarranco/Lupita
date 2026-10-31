import AppKit
import Combine
import LupitaCore
import SwiftUI

/// "Prepare your repos" (D21, D24): first the folders where the user keeps repos, then the
/// repos with an AGENTS.md or CLAUDE.md and the prompt for their own agent. Lupita only
/// reads; it never writes in a repo.
@MainActor
final class OnboardingWindow {
    private static let shownKey = "onboardingShown"
    private var window: NSWindow?
    private var timer: Timer?
    private var closeObserver: NSObjectProtocol?
    private var titleWatch: AnyCancellable?
    private let store: IndexStore
    /// The welcome step (D56): the shortcut is routed to it while it is in front.
    let welcome = WelcomeScene()
    private let model: OnboardingModel
    private let addFolder: () -> Void

    init(store: IndexStore, addFolder: @escaping () -> Void) {
        self.store = store
        self.model = OnboardingModel(store: store)
        self.addFolder = addFolder
        store.onChange = { [weak self] in self?.model.indexChanged() }
        welcome.onFinish = { [weak self] in self?.model.showWelcome = false }
    }

    /// The welcome step takes the shortcut only while Lupita is the app in front and the step is on screen.
    var activeWelcome: WelcomeScene? {
        model.showWelcome && window?.isVisible == true && NSApp.isActive ? welcome : nil
    }

    /// «Show the tutorial…» in the menu: the welcome step again, then the screen that was next.
    func showTutorial() {
        welcome.reset()
        model.showWelcome = true
        show()
    }

    /// First launch, once the permissions have been asked for.
    func showFirstTimeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.shownKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        welcome.reset()
        model.showWelcome = true
        show()
    }

    func show() {
        model.open()
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView(model: model, welcome: welcome, addFolder: addFolder))
            // Let the window keep its size: the list scrolls, and three or four repos fit at once.
            host.sizingOptions = []
            let w = NSWindow(contentViewController: host)
            w.title = S.onboardingTitle
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 560, height: 680))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
            titleWatch = model.$showWelcome.sink { [weak w] welcoming in
                w?.title = welcoming ? S.welcomeWindowTitle : S.onboardingTitle
            }
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                   object: w, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopTimer(); self?.welcome.reset(); self?.model.showWelcome = false }
            }
        }
        startTimer()
        // A menu bar app is never the active one: a plain `activate()` is only a request, and
        // macOS leaves the window behind the app in front. Bring it forward regardless.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// While the window is visible the rule state is read again every 3 s (two small files
    /// per repo), so the badge turns on by itself once the agent has committed.
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshRules() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// An editor the user can open a repo folder with.
struct Editor: Identifiable, Hashable {
    let id: String   // bundle id, or "finder"
    let name: String
    let url: URL?
    /// URL scheme that opens a file at a line (`vscode://file/path:12`).
    var scheme: String? = nil

    static let known = [
        ("Cursor", "com.todesktop.230313mzl4w4u92", "cursor"), ("VS Code", "com.microsoft.VSCode", "vscode"),
        ("Windsurf", "com.exafunction.windsurf", "windsurf"), ("Zed", "dev.zed.Zed", "zed"),
    ]
    static let finder = Editor(id: "finder", name: S.finder, url: nil)

    static func installed() -> [Editor] {
        let found = known.compactMap { name, bundle, scheme in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
                .map { Editor(id: bundle, name: name, url: $0, scheme: scheme) }
        }
        return found.isEmpty ? [finder] : found
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    private static let editorKey = "openWith", modeKey = "ruleMode"
    /// By hand (the block, pasted in the file) or with the user's agent (the prompt). Only one
    /// is shown at a time, so what is on screen is always what gets copied.
    enum Mode: String { case manual, agent }
    @Published var rows: [RepoOnboarding] = []
    @Published var percent: Int?
    @Published var roots: [String]
    @Published var candidates: [(path: String, repos: Int)] = []
    @Published var selected: Set<String> = []
    @Published var editors: [Editor] = [.finder]
    @Published var copied: String?
    /// The welcome step comes before the folders on the first run (D56).
    @Published var showWelcome = false
    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey); copied = nil }
    }
    @Published var editorID: String {
        didSet { UserDefaults.standard.set(editorID, forKey: Self.editorKey) }
    }
    private let store: IndexStore
    private var reloading = false, reloadAgain = false

    init(store: IndexStore) {
        self.store = store
        roots = store.roots
        editorID = UserDefaults.standard.string(forKey: Self.editorKey) ?? ""
        mode = UserDefaults.standard.string(forKey: Self.modeKey).flatMap(Mode.init) ?? .manual
    }

    var editor: Editor { editors.first { $0.id == editorID } ?? editors[0] }
    var isIndexing: Bool { store.isBuilding || store.index == nil }

    func open() {
        roots = store.roots
        editors = Editor.installed()
        copied = nil
        if roots.isEmpty {
            Task.detached(priority: .userInitiated) {
                let found = RepoDiscovery.candidateRoots()
                await MainActor.run { self.candidates = found; self.selected = Set(found.map(\.path)) }
            }
        }
        reload()
    }

    func indexChanged() {
        objectWillChange.send()  // "indexing" label
        reload()
    }

    /// Saves the chosen folders and indexes them; the window then shows the repos.
    func confirmFolders(extra: [String]) {
        let chosen = candidates.map(\.path).filter(selected.contains) + extra.filter(selected.contains)
        guard !chosen.isEmpty else { return }
        store.roots = chosen
        roots = chosen
    }

    func addCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = S.add
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !candidates.contains(where: { $0.path == url.path }) {
            candidates.append((url.path, RepoDiscovery.repos(under: [url.path]).count))
        }
        selected.insert(url.path)
    }

    /// Reads the index off the main thread; if the index changes meanwhile, once more after.
    func reload() {
        guard let index = store.index else { rows = []; percent = nil; return }
        if reloading { reloadAgain = true; return }
        reloading = true
        Task.detached(priority: .userInitiated) {
            let rows = Onboarding.status(of: index)
            let percent = Onboarding.explainedPercent(of: rows.map(\.repo), in: index)
            await MainActor.run {
                self.rows = rows
                self.percent = percent
                self.reloading = false
                if self.reloadAgain { self.reloadAgain = false; self.reload() }
            }
        }
    }

    /// Only the `<!-- lupita -->` check, no reindex.
    func refreshRules() {
        let current = rows
        guard !current.isEmpty else { return }
        Task.detached(priority: .utility) {
            let fresh = current.map { $0.refreshingRule() }
            await MainActor.run { if fresh != self.rows && self.rows == current { self.rows = fresh } }
        }
    }

    /// What is shown, and what gets copied, in the current mode.
    var text: String { mode == .manual ? Onboarding.ruleBlock : Onboarding.prompt }

    func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = mode == .manual ? S.blockCopied : S.promptCopied
    }

    /// By hand: copies the block and opens the instructions file at its last line.
    /// With an agent: copies the prompt and opens the repo, to paste in the agent's chat.
    func copyAndOpen(_ row: RepoOnboarding) {
        copyText()
        let workspace = NSWorkspace.shared
        if mode == .manual, let file = row.instructionsFile {
            copied = S.pasteBlock(file)
            let path = (row.repo.path as NSString).appendingPathComponent(file)
            let lines = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").components(separatedBy: "\n").count
            if let scheme = editor.scheme,
               let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "\(scheme)://file\(encoded):\(max(lines, 1))") {
                workspace.open(url)
            } else {
                workspace.open(URL(fileURLWithPath: path))
            }
            return
        }
        copied = S.pastePrompt(row.repo.name)
        let folder = URL(fileURLWithPath: row.repo.path)
        if let app = editor.url {
            workspace.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            workspace.open(folder)
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let welcome: WelcomeScene
    let addFolder: () -> Void

    var body: some View {
        Group {
            if model.showWelcome { WelcomeStep(scene: welcome) } else if model.roots.isEmpty { FoldersStep(model: model) } else { ReposStep(model: model, addFolder: addFolder) }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 360)
    }
}

/// D24: the first run asks where the repos live instead of assuming `~/Repos`.
private struct FoldersStep: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(S.foldersTitle).font(.title2.weight(.semibold))
            Text(S.foldersIntro).font(.callout).foregroundStyle(.secondary)
            if model.candidates.isEmpty {
                Text(S.noCandidates).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.candidates, id: \.path) { folder in
                        Toggle(isOn: Binding(get: { model.selected.contains(folder.path) },
                                             set: { if $0 { model.selected.insert(folder.path) } else { model.selected.remove(folder.path) } })) {
                            HStack {
                                Text((folder.path as NSString).abbreviatingWithTildeInPath)
                                Spacer()
                                Text(S.repoCount(folder.repos)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer(minLength: 0)
            HStack {
                Button(model.candidates.isEmpty ? S.addFolder : S.addOtherFolder) { model.addCustomFolder() }
                Spacer()
                Button(S.continueLabel) { model.confirmFolders(extra: []) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.selected.isEmpty)
            }
        }
    }
}

private struct ReposStep: View {
    @ObservedObject var model: OnboardingModel
    let addFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(S.onboardingTitle).font(.title2.weight(.semibold))
            Text(S.onboardingIntro(percent: model.percent)).font(.callout).foregroundStyle(.secondary)
            Picker("", selection: $model.mode) {
                Text(S.modeManual).tag(OnboardingModel.Mode.manual)
                Text(S.modeAgent).tag(OnboardingModel.Mode.agent)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            promptBox
            if model.editors.count > 1 || model.editors.first?.url != nil {
                Picker(S.openWith, selection: Binding(get: { model.editor.id }, set: { model.editorID = $0 })) {
                    ForEach(model.editors) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
                .fixedSize()
            } else {
                Text("\(S.openWith): \(S.finder)").font(.callout).foregroundStyle(.secondary)
            }
            if model.rows.isEmpty {
                Text(model.isIndexing ? S.indexing : S.noAgentRepos)
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) { ForEach(model.rows, id: \.repo) { card($0) } }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button(S.addFolder, action: addFolder)
                Spacer()
                if let copied = model.copied { Text(copied).font(.callout.weight(.medium)).foregroundStyle(Color.accentColor) }
            }
        }
    }

    private var promptBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.mode == .manual ? S.blockLabel : S.promptLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(S.copy) { model.copyText() }
            }
            ScrollView {
                Text(model.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 90, maxHeight: 150)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func card(_ row: RepoOnboarding) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.repo.name).font(.headline)
                Text(S.undefinedCitations(row.undefinedCitations)).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Text(row.ruleInstalled ? S.ruleInstalled : S.ruleMissing)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(row.ruleInstalled ? Color.green.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
            Button(model.mode == .manual ? S.copyBlockAndOpen(row.instructionsFile ?? "AGENTS.md") : S.copyPromptAndOpen) {
                model.copyAndOpen(row)
            }
                .disabled(row.ruleInstalled)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
