import Combine
import Foundation

/// The state behind the «Aspecto» window: what the reader chose (saved at every change, so the real tooltip reads it the
/// next time it opens, D55) plus the id of the sample state shown above the controls.
public final class AppearanceModel: ObservableObject {
    @Published public private(set) var preferences: ThemePreferences
    @Published public var state: String
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, state: String = "definition") {
        self.defaults = defaults
        self.preferences = ThemePreferences.load(defaults)
        self.state = state
    }

    public func setTheme(_ id: String) { change { $0.themeID = id } }
    public func setAppearance(_ appearance: ThemePreferences.Appearance) { change { $0.appearance = appearance } }
    public func setSize(_ size: ThemeSize) { change { $0.size = size } }
    public func setDensity(_ density: ThemeDensity) { change { $0.density = density } }

    private func change(_ edit: (inout ThemePreferences) -> Void) {
        var next = preferences
        edit(&next)
        guard next != preferences else { return }
        preferences = next
        next.save(defaults)   // posts ThemePreferences.didChange
    }

    /// The theme of the sample: the same call the real tooltip makes when it opens.
    public func sampleTheme(systemIsDark: Bool, accessibility: ThemeAccessibility = ThemeAccessibility()) -> TooltipTheme {
        preferences.theme(systemIsDark: systemIsDark, accessibility: accessibility)
    }

    /// The `blurb` of the chosen theme, shown under the theme picker.
    public var blurb: String { TooltipTheme.load(preferences.themeID).blurb }
}
