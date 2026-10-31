import Testing
import Foundation
@testable import LupitaCore

@Suite(.serialized) struct AppearanceModelTests {
    static func defaults() -> UserDefaults { UserDefaults(suiteName: "lupita-appearance-test-\(UUID().uuidString)")! }

    /// What the real tooltip reads when it opens.
    static func real(_ d: UserDefaults, dark: Bool = false) -> TooltipTheme { ThemePreferences.load(d).theme(systemIsDark: dark) }

    @Test func startsFromTheSavedChoicesOrTheDefaults() {
        let d = Self.defaults()
        #expect(AppearanceModel(defaults: d).preferences == ThemePreferences())
        ThemePreferences(themeID: "papel", appearance: .dark, size: .l, density: .compact).save(d)
        #expect(AppearanceModel(defaults: d).preferences.themeID == "papel")
    }

    @Test func themeControlChangesSampleAndRealTooltip() {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        let id = TooltipTheme.ids.first { $0 != TooltipTheme.defaultID }!
        m.setTheme(id)
        #expect(m.sampleTheme(systemIsDark: false).id == id)
        #expect(Self.real(d).id == id)
        #expect(m.sampleTheme(systemIsDark: false) == Self.real(d))
    }

    @Test func modeControlChangesSampleAndRealTooltip() {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        m.setAppearance(.dark)
        #expect(m.sampleTheme(systemIsDark: false).mode == .dark)
        #expect(Self.real(d).mode == .dark)
        m.setAppearance(.light)
        #expect(Self.real(d, dark: true).mode == .light)
        m.setAppearance(.system)
        #expect(Self.real(d, dark: true).mode == .dark)
    }

    @Test func sizeControlChangesSampleAndRealTooltip() {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        let base = m.sampleTheme(systemIsDark: false).width
        m.setSize(.xl)
        #expect(m.sampleTheme(systemIsDark: false).width > base)
        #expect(Self.real(d).size == .xl && Self.real(d).width == m.sampleTheme(systemIsDark: false).width)
    }

    @Test func densityControlChangesSampleAndRealTooltip() {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        let base = m.sampleTheme(systemIsDark: false).space.padding
        m.setDensity(.airy)
        #expect(m.sampleTheme(systemIsDark: false).space.padding > base)
        m.setDensity(.compact)
        #expect(m.sampleTheme(systemIsDark: false).space.padding < base)
        #expect(Self.real(d).density == .compact)
    }

    @Test func choicesSurviveReopening() {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        m.setTheme("terminal"); m.setAppearance(.dark); m.setSize(.xl); m.setDensity(.airy)
        let again = AppearanceModel(defaults: d)
        #expect(again.preferences == ThemePreferences(themeID: "terminal", appearance: .dark, size: .xl, density: .airy))
    }

    @Test func eachChangeSavesAndNotifies() async {
        let d = Self.defaults(); let m = AppearanceModel(defaults: d)
        nonisolated(unsafe) var count = 0
        let token = NotificationCenter.default.addObserver(forName: ThemePreferences.didChange, object: nil, queue: nil) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        m.setSize(.l); m.setDensity(.compact); m.setSize(.l)   // the last one changes nothing
        #expect(count == 2)
        #expect(d.string(forKey: ThemePreferences.sizeKey) == "L")
    }

    @Test func everyThemeHasABlurbAndTheModelFollowsTheChoice() {
        let m = AppearanceModel(defaults: Self.defaults())
        for (id, _) in TooltipTheme.names { m.setTheme(id); #expect(!m.blurb.isEmpty) }
        #expect(TooltipTheme.names.count == 7)
    }

    @Test func accessibilityStillAppliesToTheSample() {
        let m = AppearanceModel(defaults: Self.defaults())
        let t = m.sampleTheme(systemIsDark: false, accessibility: ThemeAccessibility(reduceTransparency: true, increaseContrast: false))
        #expect(t.surfaceBlur == 0)
    }

    @Test func appearanceStringsExistInBothLanguages() {
        S.withLanguage("es") { #expect(S.appearanceTitle == "Aspecto" && S.densityAiry == "Amplia") }
        S.withLanguage("en") { #expect(S.appearanceTitle == "Appearance" && S.appearanceMenu == "Appearance…") }
    }
}
