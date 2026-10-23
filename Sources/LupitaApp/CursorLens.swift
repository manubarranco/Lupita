import AppKit
import SwiftUI
import LupitaCore

/// How the lens follows the pointer while the chord is held. Feels to compare by eye.
enum LensStyle: String, CaseIterable {
    case smooth, elastic, looseElastic, off

    static let defaultsKey = "lens"
    static var current: LensStyle {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(LensStyle.init) ?? .elastic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var label: String {
        switch self {
        case .smooth: S.lensSmooth
        case .elastic: S.lensElastic
        case .looseElastic: S.lensLooseElastic
        case .off: S.lensOff
        }
    }

    var motion: LensMotion? {
        switch self {
        // Springs to a fixed spot below-right of the pointer, ~0.12 s, no overshoot.
        case .smooth: .follow(stiffness: 600, dampingRatio: 0.85)
        // Tied to the pointer by a loose elastic string: it starts late, and when the pointer
        // stops it swings past to the other side and back until it rests a string away.
        case .elastic: .tether(length: 34, stiffness: 70, drag: 3.2)
        case .looseElastic: .tether(length: 40, stiffness: 35, drag: 2.6)
        case .off: nil
        }
    }
}

enum LensMotion {
    case follow(stiffness: CGFloat, dampingRatio: CGFloat)
    case tether(length: CGFloat, stiffness: CGFloat, drag: CGFloat)
}

/// A magnifying glass that trails the pointer while the shortcut is held: "I'm following you,
/// I'll look wherever you say". Click-through, never takes focus. With Reduce Motion it sticks
/// to the pointer instead of trailing.
@MainActor
final class CursorLens: NSObject {
    private static let size: CGFloat = 30
    /// From the pointer tip to the lens centre: below-right, like a cursor badge.
    private static let offset = CGVector(dx: 24, dy: -22)
    /// Waits this long before showing, so ⌃⌥⌘+key shortcuts of other apps do not flash it.
    private static let delay: Duration = .milliseconds(150)
    /// The string never stretches beyond this, however fast the pointer goes.
    private static let maxDistance: CGFloat = 180

    private var panel: NSPanel?
    private var link: CADisplayLink?
    private var showTask: Task<Void, Never>?
    private var position = CGPoint.zero
    private var velocity = CGVector.zero
    private var lastTick: CFTimeInterval = 0

    func begin() {
        guard LensStyle.current != .off else { return }
        showTask?.cancel()
        showTask = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { self?.show() }
        }
    }

    func end() {
        showTask?.cancel()
        showTask = nil
        link?.invalidate()
        link = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func show() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: LensView())
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        position = badge()
        velocity = .zero
        place(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        self.panel = panel

        let link = panel.contentView!.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        lastTick = 0
        self.link = link
    }

    /// One physics step per frame (semi-implicit Euler).
    @objc private func tick(_ link: CADisplayLink) {
        guard let panel else { return }
        let dt = lastTick == 0 ? link.duration : min(link.timestamp - lastTick, 1.0 / 30)
        lastTick = link.timestamp
        let motion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : LensStyle.current.motion
        switch motion {
        case nil:
            position = badge()
        case let .follow(stiffness, dampingRatio)?:
            let goal = badge()
            let damping = 2 * dampingRatio * stiffness.squareRoot()
            step(force: CGVector(dx: stiffness * (goal.x - position.x) - damping * velocity.dx,
                                 dy: stiffness * (goal.y - position.y) - damping * velocity.dy), dt: dt)
        case let .tether(length, stiffness, drag)?:
            let pointer = NSEvent.mouseLocation
            let d = CGVector(dx: position.x - pointer.x, dy: position.y - pointer.y)
            let r = max(hypot(d.dx, d.dy), 0.001)
            // Taut, the string pulls; slack, a softer push keeps the lens off the pointer tip.
            let pull = stiffness * (r - length) / r * (r > length ? 1 : 0.5)
            step(force: CGVector(dx: -pull * d.dx - drag * velocity.dx,
                                 dy: -pull * d.dy - drag * velocity.dy), dt: dt)
            let nr = hypot(position.x - pointer.x, position.y - pointer.y)
            if nr > Self.maxDistance {
                let k = Self.maxDistance / nr
                position = CGPoint(x: pointer.x + (position.x - pointer.x) * k, y: pointer.y + (position.y - pointer.y) * k)
            }
        }
        place(panel)
    }

    private func step(force: CGVector, dt: CGFloat) {
        velocity.dx += force.dx * dt
        velocity.dy += force.dy * dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
    }

    private func badge() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        return CGPoint(x: mouse.x + Self.offset.dx, y: mouse.y + Self.offset.dy)
    }

    private func place(_ panel: NSPanel) {
        panel.setFrameOrigin(NSPoint(x: position.x - Self.size / 2, y: position.y - Self.size / 2))
    }
}

private struct LensView: View {
    var body: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 26, height: 26)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: 30, height: 30)
    }
}
