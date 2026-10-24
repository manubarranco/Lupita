import LupitaCore
import AppKit

/// The menu bar icon and its menu, rebuilt each time it opens.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: IndexStore
    private let onHotkeyChange: (HotkeyChoice) -> Void
    var onPrepareRepos: (() -> Void)?

    init(store: IndexStore, onHotkeyChange: @escaping (HotkeyChoice) -> Void) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
        super.init()
        item.button?.image = Self.icon()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
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
        let lens = action(S.lens, #selector(toggleLens))
        lens.state = CursorLens.isOn ? .on : .off
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
        menu.addItem(action(S.prepareRepos, #selector(prepareRepos)))
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

    @objc private func removeRoot(_ sender: NSMenuItem) {
        guard let root = sender.representedObject as? String else { return }
        store.roots = store.roots.filter { $0 != root }
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
