import Foundation

/// Development diagnostics (lookup log, accessibility dumps). Off by default, because the
/// permission prompt promises that nothing is stored. Turn on with
/// `defaults write com.manubarranco.lupita debugLog -bool true`.
enum Debug {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "debugLog") }
}
