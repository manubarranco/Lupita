import LupitaCore
import AppKit

/// Menu header: the app name in the full label colour (a disabled item would grey it) and the
/// index stats under it.
@MainActor
final class MenuHeader: NSView {
    private let title = NSTextField(labelWithString: "")
    private let stats = NSTextField(labelWithString: "")

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: 58))
        self.title.stringValue = title
        self.title.font = .boldSystemFont(ofSize: 15)
        self.title.textColor = .labelColor
        stats.font = .systemFont(ofSize: 11)
        stats.textColor = .secondaryLabelColor
        stats.maximumNumberOfLines = 2
        addSubview(self.title)
        addSubview(stats)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(_ lines: [String]) {
        stats.stringValue = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let inset = MenuRow.inset
        title.frame = NSRect(x: inset, y: bounds.height - 28, width: bounds.width - inset * 2, height: 20)
        stats.frame = NSRect(x: inset, y: 6, width: bounds.width - inset * 2, height: 30)
    }
}

/// A menu row with a switch on the right. Optional disclosure chevron before the label and a
/// trash button after the switch. Views in a menu do not close it when clicked, so toggling
/// switches leaves the menu open.
@MainActor
final class MenuRow: NSView {
    static let width: CGFloat = 300
    static let inset: CGFloat = 14
    private static let slot: CGFloat = 16

    private let label = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()
    private var chevron: NSButton?
    private var trash: NSButton?
    private let indent: CGFloat
    var onToggle: ((Bool) -> Void)?
    var onChevron: (() -> Void)?
    var onTrash: (() -> Void)?

    init(title: String, on: Bool, indent: CGFloat = 0, chevron: Bool = false, trash: Bool = false, tooltip: String? = nil) {
        self.indent = indent
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 26))
        label.stringValue = title
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = tooltip
        addSubview(label)
        toggle.controlSize = .small
        toggle.state = on ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggled)
        toggle.setAccessibilityLabel(title)
        addSubview(toggle)
        if chevron {
            let button = Self.iconButton("chevron.right", description: S.expand)
            button.target = self
            button.action = #selector(chevronClicked)
            self.chevron = button
            addSubview(button)
        }
        if trash {
            let button = Self.iconButton("trash", description: S.remove)
            button.target = self
            button.action = #selector(trashClicked)
            button.toolTip = S.remove
            self.trash = button
            addSubview(button)
        }
        dim(!on)
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func iconButton(_ symbol: String, description: String) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: slot, height: slot))
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    var isExpanded = false {
        didSet {
            chevron?.image = NSImage(systemSymbolName: isExpanded ? "chevron.down" : "chevron.right",
                                     accessibilityDescription: S.expand)
        }
    }

    /// The row's switch can be locked (a repo whose folder is off); its own state is kept.
    func setLocked(_ locked: Bool) {
        toggle.isEnabled = !locked
        dim(locked || toggle.state == .off)
    }

    private func dim(_ off: Bool) {
        label.textColor = off ? .secondaryLabelColor : .labelColor
    }

    @objc private func toggled() {
        let on = toggle.state == .on
        dim(!on)
        onToggle?(on)
    }
    @objc private func chevronClicked() { onChevron?() }
    @objc private func trashClicked() { onTrash?() }

    override func layout() {
        super.layout()
        let inset = Self.inset, h = bounds.height
        var right = bounds.width - inset
        // The trash slot is always reserved so every switch lines up.
        let trashFrame = NSRect(x: right - Self.slot, y: (h - Self.slot) / 2, width: Self.slot, height: Self.slot)
        trash?.frame = trashFrame
        right = trashFrame.minX - 6
        let size = toggle.fittingSize
        toggle.frame = NSRect(x: right - size.width, y: (h - size.height) / 2, width: size.width, height: size.height)
        var left = inset + indent
        if let chevron {
            chevron.frame = NSRect(x: left - 4, y: (h - Self.slot) / 2, width: Self.slot, height: Self.slot)
            left += Self.slot
        }
        let labelHeight: CGFloat = 17
        label.frame = NSRect(x: left, y: (h - labelHeight) / 2, width: toggle.frame.minX - left - 8, height: labelHeight)
    }
}
