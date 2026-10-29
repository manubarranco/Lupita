import AppKit
import SwiftUI
import LupitaCore

// The only place where the design tokens (TooltipTheme) are translated to SwiftUI. The views read `theme` through
// these helpers; a style number never lives in a view.

extension Color {
    init(rgba c: RGBA) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }

    /// `#RRGGBB` or `#RRGGBBAA`: a sample colour taken from the user's content (not a tooltip style).
    init(hex: String) {
        self.init(rgba: RGBA(hex: hex) ?? RGBA(r: 0, g: 0, b: 0, a: 1))
    }
}

/// A rounded rectangle, or a capsule for the radius 999 of the tokens; insettable so a border can sit inside it.
struct ThemeShape: InsettableShape {
    var radius: Double
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let corner = radius >= 999 ? min(r.width, r.height) / 2 : max(CGFloat(radius) - inset, 0)
        return RoundedRectangle(cornerRadius: corner).path(in: r)
    }

    func inset(by amount: CGFloat) -> ThemeShape { ThemeShape(radius: radius, inset: inset + amount) }
}

extension TooltipTheme {
    /// The font of a text role, resolved for this Mac (a named font that is missing falls back as the tokens say).
    func font(_ role: TextRole) -> Font {
        let s = text(role)
        return Font(ThemeFonts.nsFont(s.font, size: s.size, weight: s.weight, italic: s.italic) as CTFont)
    }

    func color(_ role: TextRole) -> Color { Color(rgba: text(role).color) }

    /// A rounded rectangle, or a capsule for the radius 999 of the tokens.
    func shape(_ radius: Double) -> ThemeShape { ThemeShape(radius: radius) }

    /// The room a shadow needs around its view.
    func insets(of layers: [ShadowLayer]) -> EdgeInsets {
        let i = shadowInsets(of: layers)
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }
}

extension View {
    /// Font, colour, line spacing and tracking of a text role.
    func themed(_ role: TextRole, _ theme: TooltipTheme) -> some View {
        let s = theme.text(role)
        return self
            .font(theme.font(role))
            .foregroundStyle(theme.color(role))
            .lineSpacing(max(s.lineHeight - 1, 0) * s.size)
            .tracking(s.tracking)
    }

    /// The tooltip's surface: solid, or a material (the blur number is a hint: Material has no radius) under a
    /// translucent surface colour; a border drawn inside the shape; the shadow layers behind it.
    /// A shadow's spread has no SwiftUI equivalent and is ignored.
    func themedSurface(_ theme: TooltipTheme, fill: RGBA, radius: Double, borderWidth: Double, shadow: [ShadowLayer]) -> some View {
        let shape = theme.shape(radius)
        return self
            .background {
                ZStack {
                    ForEach(Array(shadow.enumerated()), id: \.offset) { _, layer in
                        shape.fill(Color.black)
                            .shadow(color: Color(rgba: layer.color), radius: layer.blur / 2, x: layer.x, y: layer.y)
                            .mask {   // the shadow is outside the box only: a translucent surface must not show it through
                                OutsideShape(radius: radius).fill(Color.black, style: FillStyle(eoFill: true))
                            }
                    }
                    if theme.surfaceBlur > 0 {
                        shape.fill(theme.surfaceBlur <= 24 ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.regularMaterial))
                    }
                    shape.fill(Color(rgba: fill))
                }
            }
            .overlay {   // an inner halo: a blurred stroke on the edge, kept inside the shape
                ZStack {
                    ForEach(Array(theme.insetShadow.enumerated()), id: \.offset) { _, layer in
                        shape.stroke(Color(rgba: layer.color), lineWidth: max(layer.blur, 1)).blur(radius: layer.blur / 2).clipShape(shape)
                    }
                }.allowsHitTesting(false)
            }
            .overlay {
                if borderWidth > 0 { shape.strokeBorder(Color(rgba: theme.colors.border), lineWidth: borderWidth) }
            }
    }
}

/// What the tooltip should look like right now: the reader's choices (Aspecto) plus macOS's accessibility settings.
enum TooltipStyle {
    @MainActor static func current(mode: ThemeMode? = nil, defaults: UserDefaults = .standard) -> TooltipTheme {
        var preferences = ThemePreferences.load(defaults)
        if let mode { preferences.appearance = mode == .dark ? .dark : .light }
        let systemIsDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let workspace = NSWorkspace.shared
        let accessibility = ThemeAccessibility(reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                                               increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast)
        return preferences.theme(systemIsDark: systemIsDark, accessibility: accessibility)
    }
}

/// Everything around a `ThemeShape` (a big rectangle with the shape cut out), as a Shape so it takes no room of its own:
/// a negative `padding` on a mask made the hosting window grow by hundreds of points.
private struct OutsideShape: Shape {
    let radius: Double
    func path(in rect: CGRect) -> Path {
        var p = Path(rect.insetBy(dx: -400, dy: -400))
        p.addPath(ThemeShape(radius: radius).path(in: rect))
        return p
    }
}
