import Testing
import Foundation
@testable import LupitaCore

@Suite struct ThemePreferencesTests {
    static func defaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "lupita-theme-test-\(UUID().uuidString)")!
        return d
    }

    @Test func emptyDefaultsGiveCristalMNormalSystem() {
        let p = ThemePreferences.load(Self.defaults())
        #expect(p == ThemePreferences(themeID: "cristal", appearance: .system, size: .m, density: .normal))
    }

    @Test func choicesSurviveARestart() {
        let d = Self.defaults()
        ThemePreferences(themeID: "terminal", appearance: .dark, size: .xl, density: .airy).save(d)
        let back = ThemePreferences.load(d)   // a new launch reads the same store
        #expect(back.themeID == "terminal" && back.appearance == .dark && back.size == .xl && back.density == .airy)
    }

    @Test func unknownValuesFallBackToTheDefaults() {
        let d = Self.defaults()
        d.set("gone-theme", forKey: ThemePreferences.themeKey)
        d.set("XXL", forKey: ThemePreferences.sizeKey)
        d.set("loose", forKey: ThemePreferences.densityKey)
        d.set("sepia", forKey: ThemePreferences.appearanceKey)
        #expect(ThemePreferences.load(d) == ThemePreferences())
    }

    @Test func modeFollowsTheSystemUnlessForced() {
        #expect(ThemePreferences(appearance: .system).mode(systemIsDark: true) == .dark)
        #expect(ThemePreferences(appearance: .system).mode(systemIsDark: false) == .light)
        #expect(ThemePreferences(appearance: .light).mode(systemIsDark: true) == .light)
        #expect(ThemePreferences(appearance: .dark).mode(systemIsDark: false) == .dark)
    }

    @Test func everyControlChangesTheTheme() {
        let base = ThemePreferences().theme(systemIsDark: false)
        #expect(ThemePreferences(themeID: "papel").theme(systemIsDark: false).id == "papel")
        #expect(ThemePreferences(size: .xl).theme(systemIsDark: false).width > base.width)
        #expect(ThemePreferences(density: .airy).theme(systemIsDark: false).space.padding > base.space.padding)
        #expect(ThemePreferences(appearance: .dark).theme(systemIsDark: false).mode == .dark)
    }

    @Test func savingPostsAChangeNotification() async {
        let d = Self.defaults()
        let center = NotificationCenter.default
        nonisolated(unsafe) var seen = false
        let token = center.addObserver(forName: ThemePreferences.didChange, object: nil, queue: nil) { _ in seen = true }
        ThemePreferences(themeID: "neon").save(d)
        center.removeObserver(token)
        #expect(seen)
    }
}
