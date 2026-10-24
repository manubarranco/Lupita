import LupitaCore
import AppKit
import Carbon.HIToolbox

/// The shortcut that triggers a lookup. Modifier-only chords fire on release, and only if no
/// other key was pressed meanwhile, so ⌃⌥⌘+key shortcuts of other apps keep working.
enum HotkeyChoice: String, CaseIterable {
    case controlOptionCommand, fnControlOption

    static let defaultsKey = "hotkey"
    static var current: HotkeyChoice {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(HotkeyChoice.init) ?? .controlOptionCommand }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var label: String {
        switch self {
        case .controlOptionCommand: "⌃⌥⌘ (\(S.pressAndRelease))"
        case .fnControlOption: "fn⌃⌥ (\(S.pressAndRelease))"
        }
    }

    var short: String {
        switch self {
        case .controlOptionCommand: "⌃⌥⌘"
        case .fnControlOption: "fn⌃⌥"
        }
    }
}

@MainActor
protocol Trigger: AnyObject {}

/// Key + modifiers via Carbon `RegisterEventHotKey`: needs no permission.
@MainActor
final class Hotkey: Trigger {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private static var action: (() -> Void)?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Hotkey.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { Hotkey.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x4C55_5049), id: 1)  // "LUPI"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    isolated deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}

/// Modifier-only chord (⌃⌥⌘, fn⌃⌥). Global monitors need the Accessibility permission.
@MainActor
final class ModifierChord: Trigger {
    private static let relevant: NSEvent.ModifierFlags = [.control, .option, .command, .shift, .function]
    private let target: NSEvent.ModifierFlags
    private let action: () -> Void
    /// true when the full chord is down, false when it fires or is cancelled (drives the lens).
    private let hold: (Bool) -> Void
    private var armed = false {
        didSet { if armed != oldValue { hold(armed) } }
    }
    private var monitors: [Any] = []

    init(_ target: NSEvent.ModifierFlags, hold: @escaping (Bool) -> Void, action: @escaping () -> Void) {
        self.target = target
        self.hold = hold
        self.action = action
        let flags: (NSEvent) -> Void = { [weak self] e in MainActor.assumeIsolated { self?.flagsChanged(e) } }
        let key: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.armed = false } }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: key) as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { flags($0); return $0 } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { key($0); return $0 } as Any)
    }

    isolated deinit { monitors.forEach(NSEvent.removeMonitor) }

    private func flagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.relevant)
        if flags == target {
            armed = true
        } else if flags.isEmpty {
            let fire = armed
            armed = false
            if fire { action() }
        } else if !target.isSuperset(of: flags) {
            armed = false  // an extra modifier (e.g. ⇧) joined: not our chord
        }
    }
}

@MainActor
func makeTrigger(_ choice: HotkeyChoice, hold: @escaping (Bool) -> Void, action: @escaping () -> Void) -> Trigger {
    switch choice {
    case .controlOptionCommand: ModifierChord([.control, .option, .command], hold: hold, action: action)
    case .fnControlOption: ModifierChord([.function, .control, .option], hold: hold, action: action)
    }
}
