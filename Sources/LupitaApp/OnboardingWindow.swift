import AppKit
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
    private let store: IndexStore
    private let model: OnboardingModel
    private let addFolder: () -> Void

    init(store: IndexStore, addFolder: @escaping () -> Void) {
        self.store = store
        self.model = OnboardingModel(store: store)
        self.addFolder = addFolder
        store.onChange = { [weak self] in self?.model.indexChanged() }
    }

    /// First launch, once the permissions have been asked for.
    func showFirstTimeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.shownKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        show()
    }

    func show() {
        model.open()
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView(model: model, addFolder: addFolder))
            // Let the window keep its size: the list scrolls, and three or four repos fit at once.
            host.sizingOptions = []
            let w = NSWindow(contentViewController: host)
            w.title = S.onboardingTitle
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 560, height: 680))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                   object: w, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopTimer() }
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

    static let known = [
        ("Cursor", "com.todesktop.230313mzl4w4u92"), ("VS Code", "com.microsoft.VSCode"),
        ("Windsurf", "com.exafunction.windsurf"), ("Zed", "dev.zed.Zed"),
    ]
    static let finder = Editor(id: "finder", name: S.finder, url: nil)

    static func installed() -> [Editor] {
        let found = known.compactMap { name, bundle in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle).map { Editor(id: bundle, name: name, url: $0) }
        }
        return found.isEmpty ? [finder] : found
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    private static let editorKey = "openWith"
    @Published var rows: [RepoOnboarding] = []
    @Published var percent: Int?
    @Published var roots: [String]
    @Published var candidates: [(path: String, repos: Int)] = []
    @Published var selected: Set<String> = []
    @Published var editors: [Editor] = [.finder]
    @Published var copied: String?
    @Published var editorID: String {
        didSet { UserDefaults.standard.set(editorID, forKey: Self.editorKey) }
    }
    private let store: IndexStore
    private var reloading = false, reloadAgain = false

    init(store: IndexStore) {
        self.store = store
        roots = store.roots
        editorID = UserDefaults.standard.string(forKey: Self.editorKey) ?? ""
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

    func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Onboarding.prompt, forType: .string)
    }

    func copyAndOpen(_ row: RepoOnboarding) {
        copyPrompt()
        copied = row.repo.name
        let folder = URL(fileURLWithPath: row.repo.path)
        if let app = editor.url {
            NSWorkspace.shared.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(folder)
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let addFolder: () -> Void

    var body: some View {
        Group {
            if model.roots.isEmpty { FoldersStep(model: model) } else { ReposStep(model: model, addFolder: addFolder) }
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
                if let copied = model.copied { Text("\(S.copied): \(copied)").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private var promptBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(S.promptLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(S.copy) { model.copyPrompt(); model.copied = S.promptWord }
            }
            ScrollView {
                Text(Onboarding.prompt)
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
            Button(S.copyAndOpen) { model.copyAndOpen(row) }
                .disabled(row.ruleInstalled)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
