import AppKit

/// How a theme's font resolves on this Mac (D55). A named font that is not installed falls back to the system design
/// of its role, and says so; it never resolves silently to some other face.
public enum FontResolution: Equatable, Sendable {
    case system(SystemDesign)
    case named(String)
    case fallback(missing: String, SystemDesign)
}

public enum ThemeFonts {
    /// NSFont weight for a CSS-style weight (100…900).
    public static func weight(_ w: Int) -> NSFont.Weight {
        switch w {
        case ..<150: .ultraLight
        case ..<250: .thin
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }

    /// `NSFont(name:)` is nil for a missing font (it does not substitute); a hit must also be that family, not a look-alike.
    public static func resolve(_ spec: FontSpec) -> FontResolution {
        if spec.isSystem { return .system(spec.fallback) }
        if let f = NSFont(name: spec.primary, size: 12), f.familyName == spec.primary || f.fontName == spec.primary || f.displayName == spec.primary {
            return .named(spec.primary)
        }
        return .fallback(missing: spec.primary, spec.fallback)
    }

    /// The face for a role at a size, weight and slant. Nil only when a named font lacks the exact face asked for.
    public static func nsFont(_ spec: FontSpec, size: Double, weight w: Int, italic: Bool) -> NSFont {
        let s = CGFloat(size)
        let wt = weight(w)
        switch resolve(spec) {
        case .named(let family):
            var traits: [NSFontDescriptor.TraitKey: Any] = [.weight: wt.rawValue]
            if italic { traits[.symbolic] = NSFontDescriptor.SymbolicTraits.italic.rawValue }
            let d = NSFontDescriptor(fontAttributes: [.family: family, .traits: traits])
            if let f = NSFont(descriptor: d, size: s), f.familyName == family { return f }
            return systemFont(.default, s, wt, italic)
        case .system(let design), .fallback(_, let design):
            return systemFont(design, s, wt, italic)
        }
    }

    private static func systemFont(_ design: SystemDesign, _ size: CGFloat, _ weight: NSFont.Weight, _ italic: Bool) -> NSFont {
        var font: NSFont
        switch design {
        case .monospaced: font = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        default:
            font = NSFont.systemFont(ofSize: size, weight: weight)
            let d: NSFontDescriptor.SystemDesign? = design == .serif ? .serif : design == .rounded ? .rounded : nil
            if let d, let desc = font.fontDescriptor.withDesign(d), let f = NSFont(descriptor: desc, size: size) { font = f }
        }
        if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }
}
