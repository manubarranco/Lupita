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

/// Underlines what Lupita knows while ⌃⌥⌘ is held. A click-through panel per screen (macOS draws a
/// window on one display only when each has its own Spaces, the default); the lines draw from left
/// to right and disappear when the shortcut is released.
@MainActor
final class HighlightOverlay {
    private var panels: [NSPanel] = []

    var isShowing: Bool { !panels.isEmpty }

    /// - Parameters:
    ///   - marks: boxes in global top-left coordinates, each with whether its background is dark.
    func show(_ marks: [(box: CGRect, onDark: Bool)]) {
        hide(animated: false)
        guard !marks.isEmpty, let primary = NSScreen.screens.first else { return }
        let primaryHeight = primary.frame.height
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Top-left global → Cocoa global.
        let cocoa = marks.enumerated().map { n, mark in
            (n: n, onDark: mark.onDark, line: CGRect(x: mark.box.minX,
                                                    y: primaryHeight - mark.box.maxY - HighlightStyle.gap - HighlightStyle.thickness,
                                                    width: mark.box.width, height: HighlightStyle.thickness))
        }
        for screen in NSScreen.screens {
            let frame = screen.frame
            let here = cocoa.filter { $0.line.intersects(frame) }
            guard !here.isEmpty else { continue }
            let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            panel.isFloatingPanel = true
            panel.level = .popUpMenu - 1  // under the lens
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            panel.contentView = view

            for mark in here {
                let line = CALayer()
                line.backgroundColor = HighlightStyle.ink(onDark: mark.onDark)
                line.cornerRadius = HighlightStyle.cornerRadius
                line.anchorPoint = CGPoint(x: 0, y: 0.5)
                line.frame = mark.line.offsetBy(dx: -frame.minX, dy: -frame.minY)
                view.layer?.addSublayer(line)
                guard !reduce else { continue }
                let grow = CABasicAnimation(keyPath: "transform.scale.x")
                grow.fromValue = 0
                grow.toValue = 1
                grow.duration = HighlightStyle.fill
                grow.beginTime = CACurrentMediaTime() + HighlightStyle.stagger * Double(min(mark.n, HighlightStyle.staggerLimit))
                grow.fillMode = .backwards
                grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.7, 0.2, 1)
                line.add(grow, forKey: "grow")
            }
            // A panel made at a screen's frame can be nudged onto the main screen: pin it back.
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func hide(animated: Bool = true) {
        let gone = panels
        panels = []
        guard animated else { gone.forEach { $0.orderOut(nil) }; return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = HighlightStyle.fadeOut
            gone.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { gone.forEach { $0.orderOut(nil) } })
    }
}
