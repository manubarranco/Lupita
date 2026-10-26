import LupitaCore
import AppKit

/// Menu header: the app name in the full label colour (a disabled item would grey it).
@MainActor
final class MenuHeader: NSView {
    private let title = NSTextField(labelWithString: "")

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: 30))
        self.title.stringValue = title
        self.title.font = .boldSystemFont(ofSize: 15)
        self.title.textColor = .labelColor
        addSubview(self.title)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        title.frame = NSRect(x: MenuRow.inset, y: (bounds.height - 20) / 2, width: bounds.width - MenuRow.inset * 2, height: 20)
    }
}

/// Small secondary lines under a section title: the index stats and when it was last updated.
@MainActor
final class MenuNote: NSView {
    private let text = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuRow.width, height: 34))
        text.font = .systemFont(ofSize: 11)
        text.textColor = .secondaryLabelColor
        text.maximumNumberOfLines = 2
        addSubview(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(_ lines: [String]) {
        text.stringValue = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        needsLayout = true
    }

    override func layout() {
        super.layout()
        text.frame = NSRect(x: MenuRow.inset, y: 2, width: bounds.width - MenuRow.inset * 2, height: bounds.height - 4)
    }
}

/// A menu row with a switch on the right. Optional disclosure chevron before the label and a
/// remove button (⊖) after the switch. A folder that is no longer there shows a warning in the
/// switch's place, which opens a panel to find it. Views in a menu do not close it when clicked, so toggling
/// switches leaves the menu open.
@MainActor
final class MenuRow: NSView {
    static let width: CGFloat = 300
    static let inset: CGFloat = 14
    private static let slot: CGFloat = 16

    private let label = NSTextField(labelWithString: "")
    private let toggle = PillSwitch()
    private var chevron: NSButton?
    private var remove: NSButton?
    private var warning: NSButton?
    private let indent: CGFloat
    var onToggle: ((Bool) -> Void)?
    var onChevron: (() -> Void)?
    var onRemove: (() -> Void)?
    var onFind: (() -> Void)?

    init(title: String, on: Bool, indent: CGFloat = 0, chevron: Bool = false, removable: Bool = false, missing: Bool = false,
         tooltip: String? = nil) {
        self.indent = indent
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 26))
        label.stringValue = title
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = tooltip
        addSubview(label)
        toggle.isOn = on
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
        if removable {
            let button = Self.iconButton("minus.circle", description: S.remove)
            button.target = self
            button.action = #selector(removeClicked)
            button.toolTip = S.remove
            self.remove = button
            addSubview(button)
        }
        if missing {
            toggle.isHidden = true
            let button = Self.iconButton("exclamationmark.triangle.fill", description: S.findFolder)
            button.symbolConfiguration = .init(pointSize: 13, weight: .medium)
            button.contentTintColor = .systemOrange
            button.target = self
            button.action = #selector(findClicked)
            button.toolTip = S.folderMissing
            label.toolTip = S.folderMissing
            warning = button
            addSubview(button)
        }
        dim(!on || missing)
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

    /// On, off or mixed (a folder with some repos on and some off).
    func setState(_ state: SwitchState) {
        toggle.isMixed = state == .mixed
        toggle.isOn = state == .on
        dim(!toggle.isEnabled || state == .off)
    }

    /// The row's switch can be locked (a repo whose folder is off); its own state is kept.
    func setLocked(_ locked: Bool) {
        toggle.isEnabled = !locked
        dim(locked || (!toggle.isOn && !toggle.isMixed))
    }

    private func dim(_ off: Bool) {
        label.textColor = off ? .secondaryLabelColor : .labelColor
    }

    @objc private func toggled() {
        let on = toggle.isOn
        guard warning == nil else { return }
        dim(!on)
        onToggle?(on)
    }
    @objc private func chevronClicked() { onChevron?() }
    @objc private func removeClicked() { onRemove?() }
    @objc private func findClicked() { onFind?() }

    override func layout() {
        super.layout()
        let inset = Self.inset, h = bounds.height
        var right = bounds.width - inset
        // The remove slot is always reserved so every switch lines up.
        let removeFrame = NSRect(x: right - Self.slot, y: (h - Self.slot) / 2, width: Self.slot, height: Self.slot)
        remove?.frame = removeFrame
        right = removeFrame.minX - 6
        let size = PillSwitch.size
        toggle.frame = NSRect(x: right - size.width, y: (h - size.height) / 2, width: size.width, height: size.height)
        warning?.frame = NSRect(x: toggle.frame.midX - 9, y: (h - 18) / 2, width: 18, height: 18)
        var left = inset + indent
        if let chevron {
            chevron.frame = NSRect(x: left - 4, y: (h - Self.slot) / 2, width: Self.slot, height: Self.slot)
            left += Self.slot
        }
        let labelHeight: CGFloat = 17
        label.frame = NSRect(x: left, y: (h - labelHeight) / 2, width: toggle.frame.minX - left - 8, height: labelHeight)
    }
}

/// A switch drawn by hand: `NSSwitch` paints itself grey inside a menu (its window is never key),
/// which reads as disabled. This one keeps the accent colour when on.
@MainActor
final class PillSwitch: NSControl {
    static let size = NSSize(width: 30, height: 18)
    var isOn = false { didSet { needsDisplay = true } }
    /// Some of what it controls is on and some off: knob in the middle, track half tinted.
    var isMixed = false { didSet { needsDisplay = true } }
    override var isEnabled: Bool { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        setAccessibilityRole(.checkBox)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { Self.size }
    override func accessibilityValue() -> Any? { isMixed ? 2 : isOn ? 1 : 0 }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        (isOn ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(0.18)).setFill()
        track.fill()
        if isMixed {
            // Half the track in the accent: some on, some off.
            NSGraphicsContext.saveGraphicsState()
            track.addClip()
            NSColor.controlAccentColor.setFill()
            NSRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        let d = bounds.height - 4
        let x = isMixed ? (bounds.width - d) / 2 : isOn ? bounds.width - d - 2 : 2
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: 2, width: d, height: d)).fill()
        if !isEnabled {
            NSColor.windowBackgroundColor.withAlphaComponent(0.5).setFill()
            track.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        // Mixed turns everything on, as a mixed checkbox does.
        if isMixed { isMixed = false; isOn = true } else { isOn.toggle() }
        sendAction(action, to: target)
    }
}
