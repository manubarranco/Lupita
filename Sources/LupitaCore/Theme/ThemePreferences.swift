import Foundation

/// What the reader chose in «Aspecto»: theme, light / dark, size, density. Saved in UserDefaults and read by the real
/// tooltip every time it opens, so a change shows without restarting (D55).
public struct ThemePreferences: Equatable, Sendable {
    /// Follow the system's light / dark, or force one.
    public enum Appearance: String, CaseIterable, Sendable { case system, light, dark }

    public var themeID: String
    public var appearance: Appearance
    public var size: ThemeSize
    public var density: ThemeDensity

    public init(themeID: String = TooltipTheme.defaultID, appearance: Appearance = .system, size: ThemeSize = .m, density: ThemeDensity = .normal) {
        self.themeID = themeID
        self.appearance = appearance
        self.size = size
        self.density = density
    }

    public static let themeKey = "tooltipTheme", appearanceKey = "tooltipAppearance", sizeKey = "tooltipSize", densityKey = "tooltipDensity"
    /// Posted (on the default center) after `save`, so open windows can follow.
    public static let didChange = Notification.Name("LupitaThemePreferencesDidChange")

    /// Reads the saved choices; anything missing or unknown is the default.
    public static func load(_ defaults: UserDefaults = .standard) -> ThemePreferences {
        let id = defaults.string(forKey: themeKey).flatMap { TooltipTheme.ids.contains($0) ? $0 : nil } ?? TooltipTheme.defaultID
        return ThemePreferences(
            themeID: id,
            appearance: defaults.string(forKey: appearanceKey).flatMap(Appearance.init) ?? .system,
            size: defaults.string(forKey: sizeKey).flatMap(ThemeSize.init) ?? .m,
            density: defaults.string(forKey: densityKey).flatMap(ThemeDensity.init) ?? .normal)
    }

    public func save(_ defaults: UserDefaults = .standard) {
        defaults.set(themeID, forKey: Self.themeKey)
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        defaults.set(size.rawValue, forKey: Self.sizeKey)
        defaults.set(density.rawValue, forKey: Self.densityKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// The mode to draw in: the forced one, or the system's (`systemIsDark`).
    public func mode(systemIsDark: Bool) -> ThemeMode {
        switch appearance {
        case .light: .light
        case .dark: .dark
        case .system: systemIsDark ? .dark : .light
        }
    }

    public func theme(systemIsDark: Bool, accessibility: ThemeAccessibility = ThemeAccessibility()) -> TooltipTheme {
        TooltipTheme.load(themeID, mode: mode(systemIsDark: systemIsDark), size: size, density: density, accessibility: accessibility)
    }
}
