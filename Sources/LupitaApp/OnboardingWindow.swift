import AppKit
import LupitaCore
import SwiftUI

/// "Prepare your repos" (D21): lists the repos with agents and hands the user a prompt for
/// their own agent. Lupita only reads; it never writes in a repo.
@MainActor
final class OnboardingWindow {
    private static let shownKey = "onboardingShown"
    private var window: NSWindow?
    private let store: IndexStore
    private let model = OnboardingModel()
    private let addFolder: () -> Void

    init(store: IndexStore, addFolder: @escaping () -> Void) {
        self.store = store
        self.addFolder = addFolder
    }

    /// First launch, once the permissions have been asked for.
    func showFirstTimeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.shownKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        show()
    }

    func show() {
        model.reload(from: store)
        if window == nil {
            let view = OnboardingView(model: model, refresh: { [weak self] in
                guard let self else { return }
                self.store.rebuild()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    while self.store.isBuilding { try? await Task.sleep(for: .milliseconds(200)) }
                    self.model.reload(from: self.store)
                }
            }, addFolder: addFolder)
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = S.onboardingTitle
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 520, height: 460))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    @Published var rows: [RepoOnboarding] = []
    @Published var loading = false

    /// Reads the files off the main thread; the index may still be rebuilding, so the
    /// numbers can move a moment later (the refresh button asks again).
    func reload(from store: IndexStore) {
        guard let index = store.index else { rows = []; return }
        loading = true
        Task.detached(priority: .userInitiated) {
            let rows = Onboarding.status(of: index)
            await MainActor.run { self.rows = rows; self.loading = false }
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let refresh: () -> Void
    let addFolder: () -> Void
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(S.onboardingTitle).font(.title2.weight(.semibold))
            Text(S.onboardingIntro).font(.callout).foregroundStyle(.secondary)
            if model.rows.isEmpty {
                Text(S.noAgentRepos).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(model.rows, id: \.repo) { row in card(row) }
                    }
                }
            }
            HStack {
                Button(S.addFolder, action: addFolder)
                Button(S.refresh, action: refresh)
                Spacer()
                if let copied { Text("\(S.copied): \(copied)").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
    }

    private func card(_ row: RepoOnboarding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.repo.name).font(.headline)
                Spacer()
                Text(row.ruleInstalled ? S.ruleInstalled : S.ruleMissing)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(row.ruleInstalled ? Color.green.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
            }
            Text(S.undefinedCitations(row.undefinedCitations)).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(S.copyPrompt) { copy(Onboarding.rulePrompt(), row.repo.name) }
                    .disabled(row.ruleInstalled)
                Button(S.copyConversionPrompt) { copy(Onboarding.conversionPrompt(), row.repo.name) }
                    .buttonStyle(.link)
                    .help(S.conversionWarning)
            }
            Text(S.conversionWarning).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func copy(_ text: String, _ repo: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = repo
    }
}
