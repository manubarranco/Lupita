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

extension TooltipTheme {
    /// The font of a text role, resolved for this Mac (a named font that is missing falls back as the tokens say).
    func font(_ role: TextRole) -> Font {
        let s = text(role)
        return Font(ThemeFonts.nsFont(s.font, size: s.size, weight: s.weight, italic: s.italic) as CTFont)
    }

    func color(_ role: TextRole) -> Color { Color(rgba: text(role).color) }

    /// A rounded rectangle, or a capsule for the radius 999 of the tokens.
    func shape(_ radius: Double) -> AnyShape {
        radius >= 999 ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: radius))
    }

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
                                ZStack {
                                    Rectangle().fill(Color.black).padding(-400)
                                    shape.fill(Color.black).blendMode(.destinationOut)
                                }.compositingGroup()
                            }
                    }
                    if theme.surfaceBlur > 0 {
                        shape.fill(theme.surfaceBlur <= 24 ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.regularMaterial))
                    }
                    shape.fill(Color(rgba: fill))
                }
            }
            .overlay {
                if borderWidth > 0 { shape.strokeBorder(Color(rgba: theme.colors.border), lineWidth: borderWidth) }
            }
    }
}

/// What the tooltip should look like right now: the reader's choices (Aspecto) plus macOS's accessibility settings.
enum TooltipStyle {
    @MainActor static func current(mode: ThemeMode? = nil) -> TooltipTheme {
        var preferences = ThemePreferences.load()
        if let mode { preferences.appearance = mode == .dark ? .dark : .light }
        let systemIsDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let workspace = NSWorkspace.shared
        let accessibility = ThemeAccessibility(reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                                               increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast)
        return preferences.theme(systemIsDark: systemIsDark, accessibility: accessibility)
    }
}
