import AppKit
import QuartzCore

/// Where the highlight's look lives (D39). Colour, thickness and timing in one place, so a later theme
/// (tokens, gradients with contrast) changes this and nothing else.
enum HighlightStyle {
    /// Thin line in Lupita's ink, under the word.
    static let thickness: CGFloat = 1.5
    /// Points between the bottom of the word's box and the line.
    static let gap: CGFloat = 0
    static let cornerRadius: CGFloat = 0.75
    /// Fills in word by word, so reading the window hides behind the animation.
    static let fill: CFTimeInterval = 0.34
    static let stagger: CFTimeInterval = 0.024
    static let staggerLimit = 18
    static let fadeOut: CFTimeInterval = 0.12

    /// Dark ink on light windows, light ink on dark ones (docs/brand/guide.md).
    static func ink(onDark: Bool) -> CGColor {
        onDark ? CGColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1) : CGColor(red: 0.12, green: 0.12, blue: 0.11, alpha: 1)
    }
}

/// Underlines what Lupita knows while ⌃⌥⌘ is held. A click-through panel over the window's screen; the
/// lines draw from left to right and disappear when the shortcut is released.
@MainActor
final class HighlightOverlay {
    private var panel: NSPanel?

    var isShowing: Bool { panel != nil }

    /// - Parameters:
    ///   - marks: boxes in global top-left coordinates.
    func show(_ marks: [CGRect], isDark: Bool) {
        hide(animated: false)
        guard !marks.isEmpty, let screen = NSScreen.screens.first else { return }
        // One panel over every screen: marks keep their global position without a screen lookup.
        let union = NSScreen.screens.reduce(screen.frame) { $0.union($1.frame) }
        let panel = NSPanel(contentRect: union, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu - 1  // under the lens
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let view = NSView(frame: NSRect(origin: .zero, size: union.size))
        view.wantsLayer = true
        panel.contentView = view

        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let primaryHeight = screen.frame.height
        let ink = HighlightStyle.ink(onDark: isDark)
        for (n, mark) in marks.enumerated() {
            // Top-left global → Cocoa global → the panel's own.
            let y = primaryHeight - mark.maxY - HighlightStyle.gap - HighlightStyle.thickness - union.minY
            let line = CALayer()
            line.backgroundColor = ink
            line.cornerRadius = HighlightStyle.cornerRadius
            line.anchorPoint = CGPoint(x: 0, y: 0.5)
            line.frame = CGRect(x: mark.minX - union.minX, y: y, width: mark.width, height: HighlightStyle.thickness)
            view.layer?.addSublayer(line)
            guard !reduce else { continue }
            let grow = CABasicAnimation(keyPath: "transform.scale.x")
            grow.fromValue = 0
            grow.toValue = 1
            grow.duration = HighlightStyle.fill
            grow.beginTime = CACurrentMediaTime() + HighlightStyle.stagger * Double(min(n, HighlightStyle.staggerLimit))
            grow.fillMode = .backwards
            grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.7, 0.2, 1)
            line.add(grow, forKey: "grow")
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide(animated: Bool = true) {
        guard let panel else { return }
        self.panel = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ $0.duration = HighlightStyle.fadeOut; panel.animator().alphaValue = 0 },
                                             completionHandler: { panel.orderOut(nil) })
    }
}
