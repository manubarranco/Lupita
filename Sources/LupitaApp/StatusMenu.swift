import LupitaCore
import AppKit

/// The menu bar icon and its menu, rebuilt each time it opens.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: IndexStore
    private let onHotkeyChange: (HotkeyChoice) -> Void
    var onPrepareRepos: (() -> Void)?
    var onIDReport: (() -> Void)?

    init(store: IndexStore, onHotkeyChange: @escaping (HotkeyChoice) -> Void) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
        super.init()
        item.button?.image = Self.icon()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        NotificationCenter.default.addObserver(forName: IndexStore.changed, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHeader() }
        }
    }

    /// Lupita looking slightly down-left, at the screen below (D17): the lens drawing of
    /// `LensFace` without the disc, as an 18 pt template image so it follows the menu bar's
    /// colour. Stroke and eyes are a little heavier than the lens's so they hold at this size.
    private static func icon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            // The drawing spans -42...56 units on both axes: centre that box in the image.
            let scale = rect.width / 100
            cg.translateBy(x: rect.midX - 7 * scale, y: rect.midY - 7 * scale)
            cg.scaleBy(x: scale, y: scale)
            let ring = NSBezierPath(ovalIn: NSRect(x: -38, y: -38, width: 76, height: 76))
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: 28, y: 28))
            handle.line(to: NSPoint(x: 52, y: 52))
            NSColor.black.set()
            for path in [ring, handle] {
                path.lineWidth = 9
                path.lineCapStyle = .round
                path.stroke()
            }
            for cx: CGFloat in [-10, 10] {
                NSBezierPath(roundedRect: NSRect(x: cx - 5.5 - 6, y: -12 + 5, width: 11, height: 24), xRadius: 5.5, yRadius: 5.5).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = S.appName
        return image
    }

    /// Dev aid (`lupita poke --menu`): opens the menu as a click on the icon would.
    func open(expanding: Bool = false) {
        if expanding { expanded = Set(store.roots) }
        item.button?.performClick(nil)
    }

    private lazy var header = MenuHeader(title: S.appName)
    /// Folders whose repos are showing, the repos found in each, and the items now in the menu.
    private var expanded: Set<String> = []
    private var repoCache: [String: [Repo]] = [:]
    private var repoItems: [String: [NSMenuItem]] = [:]
    private var folderItems: [String: NSMenuItem] = [:]

    private func refreshHeader() { header.update([store.summary, store.freshness]) }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        repoItems = [:]
        folderItems = [:]
        refreshHeader()
        menu.addItem(viewItem(header))
        menu.addItem(.separator())

        let shortcut = NSMenuItem(title: S.shortcut(HotkeyChoice.current.short), action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for choice in HotkeyChoice.allCases {
            let item = action(choice.label, #selector(chooseHotkey(_:)), represented: choice.rawValue)
            item.state = choice == HotkeyChoice.current ? .on : .off
            choices.addItem(item)
        }
        shortcut.submenu = choices
        menu.addItem(shortcut)
        let lens = MenuRow(title: S.lens, on: CursorLens.isOn)
        lens.onToggle = { CursorLens.isOn = $0 }
        menu.addItem(viewItem(lens))
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: S.explainTermsOf))
        let git = MenuRow(title: S.gitPackage, on: VocabularyPackages.gitOn)
        git.onToggle = { VocabularyPackages.gitOn = $0 }
        menu.addItem(viewItem(git))
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: S.folders))
        for root in store.roots { addFolder(root, to: menu) }
        menu.addItem(action(S.addFolder, #selector(addRoot)))
        menu.addItem(action(S.prepareRepos, #selector(prepareRepos)))
        menu.addItem(action(S.reindex, #selector(reindex)))
        // Hidden: only there when ⌥ is held as the menu opens (D40).
        if NSEvent.modifierFlags.contains(.option) { menu.addItem(action(S.idReportMenu, #selector(idReport))) }
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: S.permissions))
        menu.addItem(permissionItem(S.accessibility, granted: Permissions.accessibility, pane: .accessibility))
        menu.addItem(permissionItem(S.screenRecording, granted: Permissions.screenRecording, pane: .screenRecording))
        menu.addItem(.separator())
        menu.addItem(action(S.about, #selector(showAbout)))
        menu.addItem(action(S.help, #selector(openHelp)))
        menu.addItem(action(Updater.availableVersion.map(S.downloadUpdate) ?? S.checkForUpdates, #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: S.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func viewItem(_ view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        return item
    }

    // MARK: Folders and their repos

    private func addFolder(_ root: String, to menu: NSMenu) {
        let on = !store.disabledRoots.contains(root)
        let row = MenuRow(title: (root as NSString).abbreviatingWithTildeInPath, on: on, chevron: true, trash: true, tooltip: root)
        row.isExpanded = expanded.contains(root)
        let item = viewItem(row)
        row.onToggle = { [weak self] on in
            guard let self else { return }
            store.setRoot(root, enabled: on)
            repoItems[root]?.forEach { ($0.view as? MenuRow)?.setLocked(!on) }
        }
        row.onChevron = { [weak self, weak row, weak item] in
            guard let self, let row, let item else { return }
            if expanded.remove(root) == nil { expanded.insert(root) }
            row.isExpanded = expanded.contains(root)
            showRepos(of: root, after: item)
        }
        row.onTrash = { [weak self] in
            // Close the menu first: an alert cannot run inside its tracking loop.
            self?.item.menu?.cancelTracking()
            DispatchQueue.main.async { self?.confirmRemove(root) }
        }
        folderItems[root] = item
        menu.addItem(item)
        if expanded.contains(root) { showRepos(of: root, after: item) }
    }

    func confirmRemove(_ root: String, dryRun: Bool = false) {
        let alert = NSAlert()
        // NSAlert titles are plain text: the question goes in an accessory view so the path can
        // have its own style (monospaced, on a soft background) instead of quotes.
        let around = S.removeFolderAround
        let spacing = NSMutableParagraphStyle()
        spacing.paragraphSpacing = 8
        spacing.alignment = .center  // air between the question and the explanation
        let text = NSMutableAttributedString(string: around.before, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        text.append(NSAttributedString(string: (root as NSString).abbreviatingWithTildeInPath, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .backgroundColor: NSColor.labelColor.withAlphaComponent(0.1),
        ]))
        text.append(NSAttributedString(string: around.after, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]))
        text.addAttribute(.paragraphStyle, value: spacing, range: NSRange(location: 0, length: text.length))
        text.append(NSAttributedString(string: "\n" + S.removeFolderBody, attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        let label = NSTextField(wrappingLabelWithString: "")
        label.attributedStringValue = text
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: 260, height: 0)
        label.frame.size.height = label.sizeThatFits(NSSize(width: 260, height: CGFloat.greatestFiniteMagnitude)).height
        alert.messageText = ""
        alert.accessoryView = label
        alert.addButton(withTitle: S.removeFromLupita).hasDestructiveAction = true
        alert.addButton(withTitle: S.cancel)
        NSApp.activate()
        // The alert pins its icon to the left; once laid out, move it to the middle.
        alert.layout()
        if let content = alert.window.contentView,
           let icon = Self.imageViews(in: content).first(where: { $0.image === alert.icon || $0.frame.width >= 48 }) {
            icon.translatesAutoresizingMaskIntoConstraints = true
            icon.frame.origin.x = (content.bounds.width - icon.frame.width) / 2
        }
        guard alert.runModal() == .alertFirstButtonReturn, !dryRun else { return }
        expanded.remove(root)
        store.removeRoot(root)
    }

    private static func imageViews(in view: NSView) -> [NSImageView] {
        view.subviews.flatMap { ($0 as? NSImageView).map { [$0] } ?? imageViews(in: $0) }
    }

    private func removeRepoItems(of root: String) {
        for item in repoItems.removeValue(forKey: root) ?? [] { item.menu?.removeItem(item) }
    }

    /// Shows (or hides) the repos of a folder right under its row. The list comes from the cache at
    /// once and is refreshed in the background, so a repo cloned meanwhile appears.
    private func showRepos(of root: String, after folder: NSMenuItem) {
        removeRepoItems(of: root)
        guard expanded.contains(root) else { return }
        if let cached = repoCache[root] { insertRepos(cached, of: root, after: folder) }
        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                RepoDiscovery.repos(under: [root])
            }.value
            guard let self, expanded.contains(root), found != repoCache[root] || repoItems[root] == nil else { return }
            repoCache[root] = found
            removeRepoItems(of: root)
            if let folder = folderItems[root] { insertRepos(found, of: root, after: folder) }
        }
    }

    private func insertRepos(_ repos: [Repo], of root: String, after folder: NSMenuItem) {
        guard let menu = folder.menu, var index = Optional(menu.index(of: folder)), index >= 0 else { return }
        let rootOn = !store.disabledRoots.contains(root)
        let off = store.disabledRepos
        var items: [NSMenuItem] = []
        for repo in repos {
            let row = MenuRow(title: repo.name, on: !off.contains(repo.path), indent: 22, tooltip: repo.path)
            row.setLocked(!rootOn)
            row.onToggle = { [weak self] on in self?.store.setRepo(repo.path, enabled: on) }
            let item = viewItem(row)
            index += 1
            menu.insertItem(item, at: index)
            items.append(item)
        }
        repoItems[root] = items
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, represented: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.representedObject = represented
        return item
    }

    private func permissionItem(_ name: String, granted: Bool, pane: Permissions.Pane) -> NSMenuItem {
        if granted { return disabled("✓ \(name)") }
        return action(S.grant(name), #selector(openPane(_:)), represented: pane.rawValue)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationVersion: Updater.installedVersion])
    }

    @objc private func openHelp() { NSWorkspace.shared.open(Updater.helpPage) }

    @objc private func checkForUpdates() {
        if Updater.availableVersion != nil {
            NSWorkspace.shared.open(Updater.releasesPage)
        } else {
            Task { await Updater.checkAndReport() }
        }
    }

    @objc private func idReport() { onIDReport?() }

    @objc private func prepareRepos() { onPrepareRepos?() }

    @objc func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = S.add
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.roots = Array(Set(store.roots + [url.path])).sorted()
    }

    @objc private func reindex() { store.rebuild() }

    @objc private func chooseHotkey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = HotkeyChoice(rawValue: raw) else { return }
        onHotkeyChange(choice)
    }

    @objc private func toggleLens() { CursorLens.isOn.toggle() }

    @objc private func openPane(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let pane = Permissions.Pane(rawValue: raw) else { return }
        Permissions.open(pane)
    }
}
