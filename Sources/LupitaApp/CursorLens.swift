import AppKit
import SwiftUI
import LupitaCore

/// How the lens follows the pointer while the chord is held. Two feels to compare by eye.
enum LensStyle: String, CaseIterable {
    case smooth, playful, off

    static let defaultsKey = "lens"
    static var current: LensStyle {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(LensStyle.init) ?? .smooth }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var label: String {
        switch self {
        case .smooth: S.lensSmooth
        case .playful: S.lensPlayful
        case .off: S.lensOff
        }
    }

    /// Spring stiffness and damping ratio. Smooth catches up in ~0.15 s with no visible
    /// overshoot; playful is a bit slower and bounces once when it arrives.
    var spring: (stiffness: CGFloat, dampingRatio: CGFloat)? {
        switch self {
        case .smooth: (600, 0.85)
        case .playful: (380, 0.5)
        case .off: nil
        }
    }
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
        position = target()
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

    /// One spring step per frame toward the pointer (semi-implicit Euler).
    @objc private func tick(_ link: CADisplayLink) {
        guard let panel else { return }
        let goal = target()
        let dt = lastTick == 0 ? link.duration : min(link.timestamp - lastTick, 1.0 / 30)
        lastTick = link.timestamp
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || LensStyle.current.spring == nil {
            position = goal
        } else if let spring = LensStyle.current.spring {
            let damping = 2 * spring.dampingRatio * spring.stiffness.squareRoot()
            velocity.dx += (spring.stiffness * (goal.x - position.x) - damping * velocity.dx) * dt
            velocity.dy += (spring.stiffness * (goal.y - position.y) - damping * velocity.dy) * dt
            position.x += velocity.dx * dt
            position.y += velocity.dy * dt
        }
        place(panel)
    }

    private func target() -> CGPoint {
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
