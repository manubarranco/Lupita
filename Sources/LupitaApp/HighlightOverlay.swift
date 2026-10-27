import AppKit
import LupitaCore
import QuartzCore

/// Where the highlight's look lives (D39). Colour, thickness and timing in one place, so a later theme
/// (tokens, gradients with contrast) changes this and nothing else.
enum HighlightStyle {
    /// Thin line in Lupita's ink, under the word.
    static let thickness: CGFloat = 1.5
    /// Points between the bottom of the word's box and the line.
    static let gap: CGFloat = 0
    static let cornerRadius: CGFloat = 0.75
    /// Terms get a dashed line, IDs a solid one: dash and gap lengths, in points.
    static let dash: CGFloat = 3
    static let dashGap: CGFloat = 2
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
    ///   - marks: boxes in global top-left coordinates, each with whether its background is dark and what it
    ///     is (an ID gets a solid line, a term a dashed one).
    func show(_ marks: [(box: CGRect, onDark: Bool, kind: HighlightPicker.Kind)]) {
        hide(animated: false)
        add(marks, staggered: true)
        // Shown even when empty, so a second layer (D53) has somewhere to draw while the shortcut is held.
        showing = true
    }

    /// Marks that arrive after the first ones (symbols, D53): drawn into the panels already up, without the
    /// left-to-right stagger.
    func add(_ marks: [(box: CGRect, onDark: Bool, kind: HighlightPicker.Kind)], staggered: Bool = false) {
        guard !marks.isEmpty, let primary = NSScreen.screens.first else { return }
        let primaryHeight = primary.frame.height
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Top-left global → Cocoa global.
        let cocoa = marks.enumerated().map { n, mark in
            (n: n, onDark: mark.onDark, kind: mark.kind, line: CGRect(x: mark.box.minX,
                                                    y: primaryHeight - mark.box.maxY - HighlightStyle.gap - HighlightStyle.thickness,
                                                    width: mark.box.width, height: HighlightStyle.thickness))
        }
        for screen in NSScreen.screens {
            let frame = screen.frame
            let here = cocoa.filter { $0.line.intersects(frame) }
            guard !here.isEmpty, let view = panel(for: frame).contentView else { continue }
            for mark in here {
                let line = Self.line(mark.kind, ink: HighlightStyle.ink(onDark: mark.onDark))
                line.anchorPoint = CGPoint(x: 0, y: 0.5)
                line.frame = mark.line.offsetBy(dx: -frame.minX, dy: -frame.minY)
                (line as? CAShapeLayer)?.path = Self.dashPath(width: line.frame.width)
                view.layer?.addSublayer(line)
                guard !reduce else { continue }
                let grow = CABasicAnimation(keyPath: "transform.scale.x")
                grow.fromValue = 0
                grow.toValue = 1
                grow.duration = HighlightStyle.fill
                grow.beginTime = CACurrentMediaTime() + (staggered ? HighlightStyle.stagger * Double(min(mark.n, HighlightStyle.staggerLimit)) : 0)
                grow.fillMode = .backwards
                grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.7, 0.2, 1)
                line.add(grow, forKey: "grow")
            }
        }
    }

    /// Whether the marks of this hold are up (the second layer only draws while they are).
    private(set) var showing = false

    /// The click-through panel over one screen, made the first time a mark falls on it.
    private func panel(for frame: CGRect) -> NSPanel {
        if let existing = panels.first(where: { $0.frame == frame }) { return existing }
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
        // A panel made at a screen's frame can be nudged onto the main screen: pin it back.
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        panels.append(panel)
        return panel
    }

    /// A solid bar for an ID; a dashed stroke for a term, round-capped like the bar's corners.
    static func line(_ kind: HighlightPicker.Kind, ink: CGColor) -> CALayer {
        switch kind {
        case .id:
            let bar = CALayer()
            bar.backgroundColor = ink
            bar.cornerRadius = HighlightStyle.cornerRadius
            return bar
        case .term:
            let dashed = CAShapeLayer()
            dashed.strokeColor = ink
            dashed.fillColor = nil
            dashed.lineWidth = HighlightStyle.thickness
            dashed.lineCap = .round
            // A round cap adds half the thickness at each end: shorten the dash so it keeps its length.
            dashed.lineDashPattern = [HighlightStyle.dash - HighlightStyle.thickness, HighlightStyle.dashGap + HighlightStyle.thickness]
                .map { NSNumber(value: Double($0)) }
            return dashed
        }
    }

    static func dashPath(width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let y = HighlightStyle.thickness / 2, inset = HighlightStyle.thickness / 2
        path.move(to: CGPoint(x: inset, y: y))
        path.addLine(to: CGPoint(x: max(inset, width - inset), y: y))
        return path
    }

    func hide(animated: Bool = true) {
        showing = false
        let gone = panels
        panels = []
        guard animated else { gone.forEach { $0.orderOut(nil) }; return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = HighlightStyle.fadeOut
            gone.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { gone.forEach { $0.orderOut(nil) } })
    }
}
