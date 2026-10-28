import Foundation

// The tooltip's design system, as the app reads it (D54, D55). The tokens live in docs/design-system; the build script
// resolves them into one JSON document per theme (embedded in ThemeData.generated.swift). `TooltipTheme` is one such
// document with the reader's choices applied: mode, size step, density and the macOS accessibility settings.
// The views read ONLY this: a style number never lives in a view.

public enum ThemeMode: String, CaseIterable, Sendable, Codable { case light, dark }

/// Text size step. Body is the anchor; every theme shares the scale.
public enum ThemeSize: String, CaseIterable, Sendable, Codable { case s = "S", m = "M", l = "L", xl = "XL" }

/// Spacing: compact / normal / airy («amplia»).
public enum ThemeDensity: String, CaseIterable, Sendable, Codable { case compact, normal, airy }

/// The macOS accessibility settings the tooltip obeys in every theme.
public struct ThemeAccessibility: Equatable, Sendable {
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public init(reduceTransparency: Bool = false, increaseContrast: Bool = false) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
    }
}

public enum FontRole: String, Codable, Sendable { case heading, body, code }
/// Which size of the scale a text role takes.
public enum SizeClass: String, Codable, Sendable { case heading, body, code, label }
public enum SystemDesign: String, Codable, Sendable { case `default`, serif, rounded, monospaced }

/// A macOS font by name, plus the system design to fall back to. `primary == "system"` means the system font itself.
public struct FontSpec: Codable, Equatable, Sendable {
    public let primary: String
    public let fallback: SystemDesign
    public var isSystem: Bool { primary == "system" }
}

public struct RGBA: Equatable, Sendable, Hashable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double) { self.r = r; self.g = g; self.b = b; self.a = a }
    /// `#RRGGBB` or `#RRGGBBAA`.
    public init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 || hex.count == 9, let v = UInt64(hex.dropFirst(), radix: 16) else { return nil }
        let alpha = hex.count == 9
        r = Double((v >> (alpha ? 24 : 16)) & 255) / 255
        g = Double((v >> (alpha ? 16 : 8)) & 255) / 255
        b = Double((v >> (alpha ? 8 : 0)) & 255) / 255
        a = alpha ? Double(v & 255) / 255 : 1
    }
    public func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

extension RGBA: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let c = RGBA(hex: s) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad colour \(s)")) }
        self = c
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        func h(_ x: Double) -> String { String(format: "%02X", Int((x * 255).rounded())) }
        try c.encode("#" + h(r) + h(g) + h(b) + h(a))
    }
}

public struct ShadowLayer: Codable, Equatable, Sendable {
    public let x: Double, y: Double, blur: Double, spread: Double
    public let color: RGBA
}

/// The eleven text roles of the hierarchy (README of the design system).
public enum TextRole: String, CaseIterable, Codable, Sendable {
    case title, id, description, repo, location, badge, eyebrow, footnote, placeholder, swatch, notice
}

public struct TextStyle: Equatable, Sendable {
    public let role: TextRole
    public let fontRole: FontRole
    public let font: FontSpec
    public let size: Double
    public let weight: Int
    public let italic: Bool
    public let lineHeight: Double
    public let tracking: Double
    public let color: RGBA
}

// MARK: - Document (what the build script writes)

struct ThemeDocument: Decodable {
    struct Text: Decodable {
        let font: FontRole, size: SizeClass
        let weight: Int, italic: Bool, lineHeight: Double, tracking: Double
        let color: RGBA
    }
    struct Colors: Decodable {
        let surface, noticeSurface, border, textPrimary, textSecondary, textAccent, badgeBg, badgeFg, originBg, originFg, swatchBorder, rowHover, shadow, shadowEdge: RGBA
    }
    struct Radius: Decodable { let container, notice, swatch, badge, row: Double }
    struct Border: Decodable { let container, swatch, notice: Double }
    struct Space: Decodable {
        let padding, blockGap, rangeGap, rangeLineGap, entryGap, inlineGap, rowGap, nameGap, swatchGap, swatchInnerGap, badgeX, badgeY, noticeX, noticeY, rowPadX, rowPadY, metaGap: Double
    }
    struct Shadow: Decodable { let container, notice: [ShadowLayer] }
    struct Mode: Decodable {
        let text: [String: Text]
        let color: Colors
        let surfaceBlur: Double, suggestionOpacity: Double
        let radius: Radius, border: Border, space: Space, shadow: Shadow
    }
    let id: String, name: String, blurb: String
    let fonts: [String: FontSpec]
    let light: Mode, dark: Mode
}

struct ThemeShared: Decodable {
    struct Step: Decodable { let heading, body, code, label, width, swatch: Double }
    struct Limits: Decodable {
        let titleLines, rangeTitleLines, idLines, descriptionLines, locationLines, maxRows: Int
    }
    let scale: [String: Step]
    let density: [String: Double]
    let limits: Limits
}

// MARK: - The theme

public struct TooltipTheme: Equatable, Sendable {
    public struct Colors: Equatable, Sendable {
        public var surface, noticeSurface, border, textPrimary, textSecondary, textAccent, badgeBg, badgeFg, originBg, originFg, swatchBorder, rowHover, shadow, shadowEdge: RGBA
    }
    public struct Radius: Equatable, Sendable { public var container, notice, swatch, badge, row: Double }
    public struct Border: Equatable, Sendable { public var container, swatch, notice: Double }
    public struct Space: Equatable, Sendable {
        public var padding, blockGap, rangeGap, rangeLineGap, entryGap, inlineGap, rowGap, nameGap, swatchGap, swatchInnerGap, badgeX, badgeY, noticeX, noticeY, rowPadX, rowPadY, metaGap: Double
    }
    public struct Limits: Equatable, Sendable {
        public var titleLines, rangeTitleLines, idLines, descriptionLines, locationLines, maxRows: Int
    }

    public let id: String
    public let name: String
    public let blurb: String
    public let mode: ThemeMode
    public let size: ThemeSize
    public let density: ThemeDensity
    public let accessibility: ThemeAccessibility
    public let fonts: [FontRole: FontSpec]
    public let width: Double
    public let swatchSize: Double
    public let colors: Colors
    public let radius: Radius
    public let border: Border
    public let space: Space
    public let limits: Limits
    /// 0 means a solid surface; above 0 the surface is a material over the content behind.
    public let surfaceBlur: Double
    public let suggestionOpacity: Double
    public let containerShadow: [ShadowLayer]
    public let noticeShadow: [ShadowLayer]
    private let styles: [TextRole: TextStyle]

    public func text(_ role: TextRole) -> TextStyle { styles[role]! }

    /// The room the shadow needs around the view so the panel can be as big as the tooltip plus its shadow.
    public func shadowInsets(of layers: [ShadowLayer]) -> (top: Double, left: Double, bottom: Double, right: Double) {
        var t = 0.0, l = 0.0, b = 0.0, r = 0.0
        for s in layers {
            let reach = s.blur + max(s.spread, 0)   // CSS blur radius × 1 covers the visible tail
            t = max(t, reach - s.y); b = max(b, reach + s.y)
            l = max(l, reach - s.x); r = max(r, reach + s.x)
        }
        return (max(t, 0).rounded(.up), max(l, 0).rounded(.up), max(b, 0).rounded(.up), max(r, 0).rounded(.up))
    }

    // MARK: Catalog

    /// The theme ids in menu order; the first is the default.
    public static var ids: [String] { ThemeData.order }
    public static let defaultID = "cristal"
    public static var names: [(id: String, name: String)] { ids.compactMap { id in documents[id].map { (id, $0.name) } } }

    nonisolated(unsafe) private static let documents: [String: ThemeDocument] = {
        let decoder = JSONDecoder()
        var out: [String: ThemeDocument] = [:]
        for (id, json) in ThemeData.documents { out[id] = try! decoder.decode(ThemeDocument.self, from: Data(json.utf8)) }
        return out
    }()
    nonisolated(unsafe) private static let shared: ThemeShared = try! JSONDecoder().decode(ThemeShared.self, from: Data(ThemeData.shared.utf8))

    /// Density factor, as in the tokens.
    public static func densityFactor(_ d: ThemeDensity) -> Double { shared.density[d.rawValue]! }

    /// Loads a theme for the reader's choices. An unknown id falls back to the default theme.
    public static func load(_ id: String = defaultID, mode: ThemeMode = .light, size: ThemeSize = .m, density: ThemeDensity = .normal,
                            accessibility: ThemeAccessibility = ThemeAccessibility()) -> TooltipTheme {
        let doc = documents[id] ?? documents[defaultID]!
        let m = mode == .light ? doc.light : doc.dark
        let step = shared.scale[size.rawValue]!
        let factor = shared.density[density.rawValue]!
        func scaled(_ n: Double) -> Double { (n * factor * 2).rounded() / 2 }   // the same half-point rounding as the tokens

        var fonts: [FontRole: FontSpec] = [:]
        for role in [FontRole.heading, .body, .code] { fonts[role] = doc.fonts[role.rawValue]! }

        var c = TooltipTheme.Colors(surface: m.color.surface, noticeSurface: m.color.noticeSurface, border: m.color.border,
                                    textPrimary: m.color.textPrimary, textSecondary: m.color.textSecondary, textAccent: m.color.textAccent,
                                    badgeBg: m.color.badgeBg, badgeFg: m.color.badgeFg, originBg: m.color.originBg, originFg: m.color.originFg,
                                    swatchBorder: m.color.swatchBorder, rowHover: m.color.rowHover, shadow: m.color.shadow, shadowEdge: m.color.shadowEdge)
        var blur = m.surfaceBlur
        var borders = TooltipTheme.Border(container: m.border.container, swatch: m.border.swatch, notice: m.border.notice)
        let secondary = m.color.textSecondary
        if accessibility.reduceTransparency {
            c.surface = c.surface.withAlpha(1)
            c.noticeSurface = c.noticeSurface.withAlpha(1)
            blur = 0
        }
        if accessibility.increaseContrast {
            c.textSecondary = c.textPrimary
            borders = TooltipTheme.Border(container: borders.container + 1, swatch: borders.swatch + 1, notice: borders.notice + 1)
        }

        var styles: [TextRole: TextStyle] = [:]
        for role in TextRole.allCases {
            let t = m.text[role.rawValue]!
            let points: Double
            switch t.size { case .heading: points = step.heading; case .body: points = step.body; case .code: points = step.code; case .label: points = step.label }
            var color = t.color
            if accessibility.increaseContrast && color == secondary { color = m.color.textPrimary }
            styles[role] = TextStyle(role: role, fontRole: t.font, font: fonts[t.font]!, size: points, weight: t.weight, italic: t.italic,
                                     lineHeight: t.lineHeight, tracking: t.tracking, color: color)
        }
        let s = m.space
        let l = shared.limits
        return TooltipTheme(
            id: doc.id, name: doc.name, blurb: doc.blurb, mode: mode, size: size, density: density, accessibility: accessibility, fonts: fonts,
            width: step.width, swatchSize: step.swatch, colors: c,
            radius: Radius(container: m.radius.container, notice: m.radius.notice, swatch: m.radius.swatch, badge: m.radius.badge, row: m.radius.row),
            border: borders,
            space: Space(padding: scaled(s.padding), blockGap: scaled(s.blockGap), rangeGap: scaled(s.rangeGap), rangeLineGap: scaled(s.rangeLineGap),
                         entryGap: scaled(s.entryGap), inlineGap: scaled(s.inlineGap), rowGap: scaled(s.rowGap), nameGap: scaled(s.nameGap),
                         swatchGap: scaled(s.swatchGap), swatchInnerGap: scaled(s.swatchInnerGap), badgeX: scaled(s.badgeX), badgeY: scaled(s.badgeY),
                         noticeX: scaled(s.noticeX), noticeY: scaled(s.noticeY), rowPadX: scaled(s.rowPadX), rowPadY: scaled(s.rowPadY), metaGap: scaled(s.metaGap)),
            limits: Limits(titleLines: l.titleLines, rangeTitleLines: l.rangeTitleLines, idLines: l.idLines, descriptionLines: l.descriptionLines,
                           locationLines: l.locationLines, maxRows: l.maxRows),
            surfaceBlur: blur, suggestionOpacity: m.suggestionOpacity,
            containerShadow: m.shadow.container, noticeShadow: m.shadow.notice, styles: styles)
    }
}
