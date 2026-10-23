import LupitaCore
import AppKit

/// The menu bar icon and its menu, rebuilt each time it opens.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: IndexStore
    private let onHotkeyChange: (HotkeyChoice) -> Void

    init(store: IndexStore, onHotkeyChange: @escaping (HotkeyChoice) -> Void) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
        super.init()
        item.button?.image = NSImage(systemSymbolName: "number.square", accessibilityDescription: S.appName)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabled(store.summary))
        if !store.freshness.isEmpty { menu.addItem(disabled(store.freshness)) }
        let shortcut = NSMenuItem(title: S.shortcut(HotkeyChoice.current.short), action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for choice in HotkeyChoice.allCases {
            let item = action(choice.label, #selector(chooseHotkey(_:)), represented: choice.rawValue)
            item.state = choice == HotkeyChoice.current ? .on : .off
            choices.addItem(item)
        }
        shortcut.submenu = choices
        menu.addItem(shortcut)
        let lens = NSMenuItem(title: S.lens, action: nil, keyEquivalent: "")
        let styles = NSMenu()
        for style in LensStyle.allCases {
            let item = action(style.label, #selector(chooseLens(_:)), represented: style.rawValue)
            item.state = style == LensStyle.current ? .on : .off
            styles.addItem(item)
        }
        lens.submenu = styles
        menu.addItem(lens)
        menu.addItem(.separator())

        menu.addItem(disabled(S.folders))
        for root in store.roots {
            let row = NSMenuItem(title: "  " + root, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.addItem(action(S.remove, #selector(removeRoot(_:)), represented: root))
            row.submenu = sub
            menu.addItem(row)
        }
        menu.addItem(action(S.addFolder, #selector(addRoot)))
        menu.addItem(action(S.reindex, #selector(reindex)))
        menu.addItem(.separator())

        menu.addItem(permissionItem(S.accessibility, granted: Permissions.accessibility, pane: .accessibility))
        menu.addItem(permissionItem(S.screenRecording, granted: Permissions.screenRecording, pane: .screenRecording))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: S.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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

    @objc private func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = S.add
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.roots = Array(Set(store.roots + [url.path])).sorted()
    }

    @objc private func removeRoot(_ sender: NSMenuItem) {
        guard let root = sender.representedObject as? String else { return }
        store.roots = store.roots.filter { $0 != root }
    }

    @objc private func reindex() { store.rebuild() }

    @objc private func chooseHotkey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = HotkeyChoice(rawValue: raw) else { return }
        onHotkeyChange(choice)
    }

    @objc private func chooseLens(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = LensStyle(rawValue: raw) else { return }
        LensStyle.current = style
    }

    @objc private func openPane(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let pane = Permissions.Pane(rawValue: raw) else { return }
        Permissions.open(pane)
    }
}
