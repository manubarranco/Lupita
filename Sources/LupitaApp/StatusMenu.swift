import LupitaCore
import AppKit

/// The menu bar icon and its menu, rebuilt each time it opens.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: IndexStore
    private let onHotkeyChange: (HotkeyChoice) -> Void
    var onPrepareRepos: (() -> Void)?
    var onTutorial: (() -> Void)?
    var onIDReport: (() -> Void)?
    var onAppearance: (() -> Void)?

    init(store: IndexStore, onHotkeyChange: @escaping (HotkeyChoice) -> Void) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
        super.init()
        item.button?.image = Self.icon()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        NotificationCenter.default.addObserver(forName: IndexStore.changed, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNote() }
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
        if expanding { expandAll() }
        item.button?.performClick(nil)
    }

    private func expandAll() {
        func folders(_ node: RepoNode) -> [String] {
            guard case .folder(let path, _, let children) = node else { return [] }
            return [path] + children.flatMap(folders)
        }
        expanded = Set(store.roots + store.roots.map { $0 + "\u{0}hidden" }
                       + repoCache.flatMap { RepoTree.build(root: $0.key, repos: $0.value).flatMap(folders) })
    }

    /// Dev aid (`--render-menu`): the menu as it opens, with every folder's repos found and shown.
    /// `missingPermissions`: draw the permissions section as if neither were granted.
    func filledForGallery(missingPermissions: Bool, option: Bool = false) -> NSMenu {
        repoCache = Dictionary(uniqueKeysWithValues: store.roots.map { ($0, RepoDiscovery.repos(under: [$0])) })
        expandAll()
        forceMissingPermissions = missingPermissions
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        optionChanged(option)
        return menu
    }
    private var forceMissingPermissions = false
    /// Where a folder's name starts when it has a chevron: rows without one line up with it.
    private static let chevronSpace: CGFloat = 16

    private lazy var header = MenuHeader(title: S.appName)
    /// Made anew each time the menu opens: the last menu's item still holds the old one, and handing
    /// that same view to a new item left the stats blank on the next open.
    private var note = MenuNote()
    /// Folders and subfolders whose repos are showing, the repos found in each root, and the folder
    /// rows now in the menu (they go right after `note`).
    private var expanded: Set<String> = []
    private var repoCache: [String: [Repo]] = [:]
    private var folderRows: [NSMenuItem] = []
    private var noteItem: NSMenuItem?
    /// Each switch row with how to work out its state, to refresh them in place after a toggle.
    private var stateRows: [(row: MenuRow, state: () -> SwitchState)] = []

    private func refreshNote() { note.update([store.summary, store.freshness]) }

    // MARK: ⌥ while the menu is open (D45)

    /// ⌥ shows the repos' hide buttons and «Send ID report…», also when pressed with the menu already
    /// open. A menu in tracking gets no key events for that: a timer in the tracking run loop mode
    /// watches the modifier.
    private var optionDown = false
    private var hideRows: [MenuRow] = []
    private var optionTimer: Timer?
    private var reindexItem: NSMenuItem?
    private var loginRow: MenuRow?
    private lazy var reportItem = action(S.idReportMenu, #selector(idReport))

    func menuWillOpen(_ menu: NSMenu) {
        // System Settings › Login Items can change it while the menu is closed.
        loginRow?.setState(LoginItem.isOn ? .on : .off)
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.optionChanged(NSEvent.modifierFlags.contains(.option)) }
        }
        RunLoop.main.add(timer, forMode: .common)
        optionTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        optionTimer?.invalidate()
        optionTimer = nil
    }

    private func optionChanged(_ down: Bool) {
        guard down != optionDown else { return }
        optionDown = down
        hideRows.forEach { $0.showsHide = down }
        showReportItem(down)
    }

    private func showReportItem(_ show: Bool) {
        guard let reindexItem, let menu = reindexItem.menu else { return }
        if show, reportItem.menu == nil {
            menu.insertItem(reportItem, at: menu.index(of: reindexItem) + 1)
        } else if !show, let owner = reportItem.menu {
            owner.removeItem(reportItem)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        folderRows = []
        stateRows = []
        hideRows = []
        optionDown = NSEvent.modifierFlags.contains(.option)
        refreshNote()
        menu.addItem(viewItem(header))
        menu.addItem(.separator())

        // Permissions only when one is missing: then they come first (D44).
        let missing = [(S.accessibility, Permissions.accessibility, Permissions.Pane.accessibility),
                       (S.screenRecording, Permissions.screenRecording, Permissions.Pane.screenRecording)].filter { !$0.1 || forceMissingPermissions }
        if !missing.isEmpty {
            menu.addItem(.sectionHeader(title: S.permissions))
            for (name, _, pane) in missing { menu.addItem(permissionItem(name, pane: pane)) }
            menu.addItem(.separator())
        }

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
        let login = MenuRow(title: S.openAtLogin, on: LoginItem.isOn)
        login.onToggle = { LoginItem.set($0) }
        menu.addItem(viewItem(login))
        loginRow = login
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: S.folders))
        note = MenuNote()
        refreshNote()
        let noteItem = viewItem(note)
        menu.addItem(noteItem)
        self.noteItem = noteItem
        // ⊕ on the right, in the column of the folders' ⊖.
        let add = MenuActionRow(title: S.addFolder, symbol: "plus.circle", indent: Self.chevronSpace)
        add.onClick = { [weak self] in self?.closeMenu(then: { self?.addRoot() }) }
        menu.addItem(viewItem(add))
        menu.addItem(action(S.prepareRepos, #selector(prepareRepos)))
        menu.addItem(action(S.showTutorial, #selector(showTutorial)))
        let reindex = action(S.reindex, #selector(reindex))
        menu.addItem(reindex)
        reindexItem = reindex
        // Hidden: only there while ⌥ is held (D40, D45).
        showReportItem(optionDown)
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: S.explainTermsOf))
        for package in TermPackage.allCases {
            let row = MenuRow(title: VocabularyPackages.title(package), on: VocabularyPackages.isOn(package))
            row.onToggle = { VocabularyPackages.set(package, on: $0) }
            menu.addItem(viewItem(row))
        }
        menu.addItem(.separator())

        menu.addItem(action(S.appearanceMenu, #selector(showAppearance)))
        menu.addItem(action(S.about, #selector(showAbout)))
        menu.addItem(action(S.help, #selector(openHelp)))
        menu.addItem(action(Updater.availableVersion.map(Updater.menuTitle) ?? S.checkForUpdates, #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: S.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        renderFolders()
        discoverRepos()
    }

    private func viewItem(_ view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        return item
    }

    // MARK: Folders and their repos

    /// Finds the repos of every folder in the background; the folder rows are redrawn when the list
    /// changes (a repo cloned or moved meanwhile). The cache keeps the menu instant on the next open.
    private func discoverRepos() {
        let roots = store.roots
        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                Dictionary(uniqueKeysWithValues: roots.map { ($0, RepoDiscovery.repos(under: [$0])) })
            }.value
            guard let self else { return }
            let changed = roots.contains { found[$0] != repoCache[$0] }
            repoCache.merge(found) { $1 }
            if changed { renderFolders() }
        }
    }

    /// Redraws the folder rows, right under the stats note.
    private func renderFolders() {
        guard let noteItem, let menu = noteItem.menu else { return }
        folderRows.forEach(menu.removeItem)
        folderRows = []
        stateRows = []
        hideRows = []
        var index = menu.index(of: noteItem)
        for item in store.roots.flatMap(folderItems) {
            index += 1
            menu.insertItem(item, at: index)
            folderRows.append(item)
        }
    }

    /// Updates every switch after a toggle, so a folder shows mixed as soon as one of its repos goes off.
    private func refreshStates() {
        for (row, state) in stateRows { row.setState(state()) }
    }

    private func folderItems(_ root: String) -> [NSMenuItem] {
        let title = (root as NSString).abbreviatingWithTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: (root as NSString).expandingTildeInPath, isDirectory: &isDir), isDir.boolValue else {
            // Moved or deleted: a warning instead of the switch, which opens a panel to find it.
            let row = MenuRow(title: title, on: false, indent: Self.chevronSpace, removable: true, missing: true, tooltip: root)
            row.onFind = { [weak self] in self?.closeMenu(then: { self?.findMoved(root) }) }
            row.onRemove = { [weak self] in self?.closeMenu(then: { self?.confirmRemove(root) }) }
            return [viewItem(row)]
        }

        let repos = repoCache[root]
        let hiddenPaths = store.hiddenRepos
        let hidden = (repos ?? []).filter { hiddenPaths.contains($0.path) }
        let nodes = repos.map { RepoTree.build(root: root, repos: $0.filter { !hiddenPaths.contains($0.path) }) } ?? []
        // One repo (and none hidden): no list to open, the folder's row is that repo's switch.
        let single = nodes.count == 1 && nodes[0].repos.count == 1 && hidden.isEmpty
        let rootRepos = nodes.flatMap(\.repos)
        let rootState: () -> SwitchState = { [weak self] in
            guard let self, !store.disabledRoots.contains(root) else { return .off }
            return RepoTree.state(of: rootRepos, disabled: store.disabledRepos)
        }
        let hasList = (!nodes.isEmpty && !single) || !hidden.isEmpty
        let row = MenuRow(title: single && nodes[0].title != (root as NSString).lastPathComponent
                              ? title + RepoTree.separator + nodes[0].title : title,
                          on: true, indent: hasList || repos == nil ? 0 : Self.chevronSpace,
                          chevron: hasList || repos == nil, removable: true, tooltip: root)
        row.setState(rootState())
        row.isExpanded = expanded.contains(root)
        row.onToggle = { [weak self] on in
            guard let self else { return }
            let paths = rootRepos.map(\.path)
            if !on {
                store.setRoot(root, enabled: false)
            } else if store.disabledRoots.contains(root) {
                // Back on: the repos as they were, unless that leaves nothing on.
                store.setRoot(root, enabled: true)
                if RepoTree.state(of: rootRepos, disabled: store.disabledRepos) == .off { store.setRepos(paths, enabled: true) }
            } else {
                // From mixed: everything on.
                store.setRepos(paths, enabled: true)
            }
            // Redrawn after the click returns: the repos below lock or unlock with the folder.
            DispatchQueue.main.async { [weak self] in self?.renderFolders() }
        }
        row.onChevron = { [weak self] in self?.toggleExpanded(root) }
        row.onRemove = { [weak self] in self?.closeMenu(then: { self?.confirmRemove(root) }) }
        stateRows.append((row, rootState))
        var items = [viewItem(row)]
        if hasList, expanded.contains(root) {
            items += nodes.flatMap { nodeItems($0, root: root, depth: 1) }
            if !hidden.isEmpty { items += hiddenItems(hidden, root: root) }
        }
        return items
    }

    /// «Hidden (N)», closed by default, with a ⊕ on each repo to bring it back (D45).
    private func hiddenItems(_ hidden: [Repo], root: String) -> [NSMenuItem] {
        let key = root + "\u{0}hidden"
        let group = MenuRow(title: S.hiddenGroup(hidden.count), on: false, indent: 22, chevron: true, switchless: true)
        group.isExpanded = expanded.contains(key)
        group.onChevron = { [weak self] in self?.toggleExpanded(key) }
        var items = [viewItem(group)]
        guard expanded.contains(key) else { return items }
        let base = RepoDiscovery.realPath((root as NSString).expandingTildeInPath)
        for repo in hidden {
            let relative = repo.path.hasPrefix(base + "/") ? String(repo.path.dropFirst(base.count + 1)) : repo.name
            let row = MenuRow(title: relative.replacingOccurrences(of: "/", with: RepoTree.separator), on: false, indent: 44,
                              slot: .restore, switchless: true, tooltip: repo.path)
            row.onRemove = { [weak self] in
                self?.store.setHidden(repo.path, hidden: false)
                DispatchQueue.main.async { self?.renderFolders() }
            }
            items.append(viewItem(row))
        }
        return items
    }

    private func nodeItems(_ node: RepoNode, root: String, depth: Int) -> [NSMenuItem] {
        let indent = CGFloat(depth) * 22
        let locked: () -> Bool = { [weak self] in self?.store.disabledRoots.contains(root) ?? false }
        switch node {
        case .repo(let repo, let title):
            let row = MenuRow(title: title, on: true, indent: indent, slot: .hide, tooltip: repo.path)
            row.showsHide = optionDown
            row.onRemove = { [weak self] in
                self?.store.setHidden(repo.path, hidden: true)
                DispatchQueue.main.async { self?.renderFolders() }
            }
            hideRows.append(row)
            let state: () -> SwitchState = { [weak self] in
                self?.store.disabledRepos.contains(repo.path) == true ? .off : .on
            }
            row.setState(state())
            row.setLocked(locked())
            row.onToggle = { [weak self] on in
                self?.store.setRepo(repo.path, enabled: on)
                self?.refreshStates()
            }
            stateRows.append((row, state))
            return [viewItem(row)]
        case .folder(let path, let title, let children):
            let repos = node.repos
            let row = MenuRow(title: title, on: true, indent: indent, chevron: true, tooltip: path)
            let state: () -> SwitchState = { [weak self] in
                RepoTree.state(of: repos, disabled: self?.store.disabledRepos ?? [])
            }
            row.setState(state())
            row.setLocked(locked())
            row.isExpanded = expanded.contains(path)
            row.onToggle = { [weak self] on in
                self?.store.setRepos(repos.map(\.path), enabled: on)
                self?.refreshStates()
            }
            row.onChevron = { [weak self] in self?.toggleExpanded(path) }
            stateRows.append((row, state))
            var items = [viewItem(row)]
            if expanded.contains(path) { items += children.flatMap { nodeItems($0, root: root, depth: depth + 1) } }
            return items
        }
    }

    private func toggleExpanded(_ path: String) {
        if expanded.remove(path) == nil { expanded.insert(path) }
        // After the click returns: the row being clicked is one of those redrawn.
        DispatchQueue.main.async { [weak self] in self?.renderFolders() }
    }

    /// Closes the menu first: an alert or a panel cannot run inside its tracking loop.
    private func closeMenu(then work: @escaping () -> Void) {
        item.menu?.cancelTracking()
        DispatchQueue.main.async(execute: work)
    }

    /// A folder that is no longer where it was: the user points at its new place.
    private func findMoved(_ root: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = S.findFolder
        panel.message = S.whereIsFolder((root as NSString).abbreviatingWithTildeInPath)
        // Start next to where it was: a moved folder is often one level up or down.
        var parent = ((root as NSString).expandingTildeInPath as NSString).deletingLastPathComponent
        while !FileManager.default.fileExists(atPath: parent), parent != "/" { parent = (parent as NSString).deletingLastPathComponent }
        panel.directoryURL = URL(fileURLWithPath: parent)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        expanded.remove(root)
        repoCache[root] = nil
        store.relocateRoot(root, to: url.path)
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

    private func action(_ title: String, _ selector: Selector, represented: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.representedObject = represented
        return item
    }

    /// A missing permission, in orange so it stands out: without it Lupita cannot read the screen.
    private func permissionItem(_ name: String, pane: Permissions.Pane) -> NSMenuItem {
        let item = action(S.grant(name), #selector(openPane(_:)), represented: pane.rawValue)
        // White mark on an orange triangle, as on a moved folder's row.
        let config = NSImage.SymbolConfiguration(paletteColors: [.white, .systemOrange])
        item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        return item
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationVersion: Updater.installedVersion])
    }

    @objc private func openHelp() { NSWorkspace.shared.open(Updater.helpPage) }

    @objc private func checkForUpdates() {
        if Updater.availableVersion != nil {
            Updater.offerAvailable()
        } else {
            Task { await Updater.checkAndReport() }
        }
    }

    @objc private func idReport() { onIDReport?() }

    @objc private func showAppearance() { onAppearance?() }

    @objc private func prepareRepos() { onPrepareRepos?() }
    @objc private func showTutorial() { onTutorial?() }

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
