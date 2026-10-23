import AppKit
import LupitaCore

/// A magnifying glass that trails the pointer while the shortcut is held: "I'm following you,
/// I'll look wherever you say". It is tied to the pointer by a loose elastic string: it starts
/// late, and when the pointer stops it swings past to the other side and back until it rests a
/// string away, off the word being pointed at. Click-through, never takes focus, never in the
/// OCR capture (own windows are excluded). With Reduce Motion it sticks below-right instead.
///
/// It is Lupita's character (D17, docs/lens-behavior.md): two pill eyes that look at the
/// pointer while it follows, face forward at rest, narrow when the string is taut, and blink.
@MainActor
final class CursorLens: NSObject {
    /// The panel: the ring is about 35 pt across, about 42 pt with the handle.
    private static let size: CGFloat = 50
    /// From the pointer tip to the lens centre: below-right, like a cursor badge.
    private static let offset = CGVector(dx: 24, dy: -22)
    /// Waits this long before showing, so ⌃⌥⌘+key shortcuts of other apps do not flash it.
    private static let delay: Duration = .milliseconds(150)
    /// The string: rest length, pull when taut, air drag. Never stretches beyond `maxDistance`.
    private static let length: CGFloat = 40
    private static let stiffness: CGFloat = 35
    private static let drag: CGFloat = 2.6
    private static let maxDistance: CGFloat = 180
    /// Stretched past this, the lens is focused: it narrows its eyes.
    private static let tense = 0.62 * maxDistance
    /// Slower than this for `restAfter`, the lens rests and faces forward.
    private static let restSpeed: CGFloat = 18
    private static let restAfter: CFTimeInterval = 0.35
    private static let fade: CFTimeInterval = 0.12

    static let defaultsKey = "lens"
    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    private var panel: NSPanel?
    private var face: LensFace?
    private var link: CADisplayLink?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var position = CGPoint.zero
    private var velocity = CGVector.zero
    private var lastTick: CFTimeInterval = 0
    private var still: CFTimeInterval = 0
    private var blink: CGFloat = 0
    private var nextBlink: CFTimeInterval = 0

    func begin() {
        guard Self.isOn else { return }
        if hideTask != nil, let panel, let face {
            // Released and pressed again while closing: open the eyes again, same lens.
            hideTask?.cancel()
            hideTask = nil
            face.openTarget = 1
            NSAnimationContext.runAnimationGroup { $0.duration = Self.fade; panel.animator().alphaValue = 1 }
            return
        }
        showTask?.cancel()
        showTask = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { self?.show() }
        }
    }

    /// Closes the eyes while it fades out, then goes.
    func end() {
        showTask?.cancel()
        showTask = nil
        guard let panel, hideTask == nil else { return }
        face?.openTarget = 0
        NSAnimationContext.runAnimationGroup { $0.duration = Self.fade; panel.animator().alphaValue = 0 }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.fade + 0.03))
            if !Task.isCancelled { self?.remove() }
        }
    }

    private func remove() {
        hideTask = nil
        link?.invalidate()
        link = nil
        panel?.orderOut(nil)
        panel = nil
        face = nil
    }

    private func show() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        let face = LensFace(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        panel.contentView = face
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        position = badge()
        velocity = .zero
        still = 0
        blink = 0
        nextBlink = 0
        face.openTarget = 1
        if reduceMotion { face.open = 1 }
        place(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = Self.fade; panel.animator().alphaValue = 1 }
        self.panel = panel
        self.face = face

        let link = face.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        lastTick = 0
        self.link = link
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// One step of the string and the eyes per frame (semi-implicit Euler).
    @objc private func tick(_ link: CADisplayLink) {
        guard let panel, let face else { return }
        let dt = lastTick == 0 ? link.duration : min(link.timestamp - lastTick, 1.0 / 30)
        lastTick = link.timestamp
        let now = link.timestamp
        let pointer = NSEvent.mouseLocation
        guard !reduceMotion else {
            position = badge()
            place(panel)
            face.look = .zero
            face.height = LensFace.eyeHeight
            face.open = face.openTarget
            face.blink = 1
            face.needsDisplay = true
            return
        }
        let d = CGVector(dx: position.x - pointer.x, dy: position.y - pointer.y)
        let r = max(hypot(d.dx, d.dy), 0.001)
        // Taut, the string pulls; slack, a softer push keeps the lens off the pointer tip.
        let pull = Self.stiffness * (r - Self.length) / r * (r > Self.length ? 1 : 0.5)
        velocity.dx += (-pull * d.dx - Self.drag * velocity.dx) * dt
        velocity.dy += (-pull * d.dy - Self.drag * velocity.dy) * dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        var nr = hypot(position.x - pointer.x, position.y - pointer.y)
        if nr > Self.maxDistance {
            let k = Self.maxDistance / nr
            position = CGPoint(x: pointer.x + (position.x - pointer.x) * k, y: pointer.y + (position.y - pointer.y) * k)
            nr = Self.maxDistance
        }
        place(panel)

        // Where the eyes want to be, in lens units (the face is drawn flipped: y grows down).
        let toPointer = CGVector(dx: (pointer.x - position.x) / max(nr, 0.001), dy: -(pointer.y - position.y) / max(nr, 0.001))
        still = hypot(velocity.dx, velocity.dy) < Self.restSpeed ? still + dt : 0
        var look = CGVector.zero, height = LensFace.eyeHeight
        let focused = nr > Self.tense
        if focused {
            look = CGVector(dx: toPointer.dx * 5, dy: toPointer.dy * 5 + 3)
            height = 7
        } else if still < Self.restAfter {
            look = CGVector(dx: toPointer.dx * 7, dy: toPointer.dy * 7)
            height = 20
        }

        // Ease towards it: the prototype's per-frame factors, made frame-rate independent.
        func ease(_ k: CGFloat) -> CGFloat { 1 - pow(1 - k, CGFloat(dt) * 60) }
        face.look.dx += (look.dx - face.look.dx) * ease(0.2)
        face.look.dy += (look.dy - face.look.dy) * ease(0.2)
        face.height += (height - face.height) * ease(0.3)
        face.open += (face.openTarget - face.open) * ease(0.25)

        if nextBlink == 0 { nextBlink = now + .random(in: 2.2...5.2) }
        if !focused, now > nextBlink {
            blink = 1
            nextBlink = now + .random(in: 2.2...5.2)
        }
        face.blink = blink > 0 ? max(0.08, 1 - sin(min(blink, 1) * .pi)) : 1
        blink = max(0, blink - CGFloat(dt) / 0.15)
        face.needsDisplay = true
    }

    private func badge() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        return CGPoint(x: mouse.x + Self.offset.dx, y: mouse.y + Self.offset.dy)
    }

    private func place(_ panel: NSPanel) {
        panel.setFrameOrigin(NSPoint(x: position.x - Self.size / 2, y: position.y - Self.size / 2))
    }
}

/// The drawing: in a 100-unit box centred on the ring, a ring of radius 38 and stroke 8, a
/// handle to the lower right and two pill eyes 10 × 22 at x = ±9, scaled by 0.42.
private final class LensFace: NSView {
    static let eyeHeight: CGFloat = 22
    private static let scale: CGFloat = 0.42

    /// Eye offset and height in lens units; `open` and `blink` multiply the height (0...1).
    var look = CGVector.zero
    var height = eyeHeight
    var open: CGFloat = 0
    var openTarget: CGFloat = 0
    var blink: CGFloat = 1

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            guard let cg = NSGraphicsContext.current?.cgContext else { return }
            cg.translateBy(x: bounds.midX, y: bounds.midY)
            cg.scaleBy(x: Self.scale, y: Self.scale)

            let ring = NSBezierPath(ovalIn: NSRect(x: -38, y: -38, width: 76, height: 76))
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: 28, y: 28))
            handle.line(to: NSPoint(x: 52, y: 52))
            for path in [ring, handle] {
                path.lineWidth = 8
                path.lineCapStyle = .round
            }

            // A soft shadow under the disc keeps the lens readable on any background.
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(0.25)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.set()
            NSColor.controlBackgroundColor.setFill()
            ring.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor.labelColor.set()
            ring.stroke()
            handle.stroke()

            let h = max(1.5, height * blink * open), w: CGFloat = 10
            for cx: CGFloat in [-9, 9] {
                let eye = NSRect(x: cx - w / 2 + look.dx, y: -h / 2 + look.dy, width: w, height: h)
                NSBezierPath(roundedRect: eye, xRadius: min(5, h / 2), yRadius: min(5, h / 2)).fill()
            }
        }
    }
}
