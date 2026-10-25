import Foundation
import LupitaCore

/// The «Explain terms of:» switches in the menu (D43), one per package of fixed dictionaries. On by default,
/// like the lens: the packages work from the first minute. Only fixed dictionaries have a switch; what comes
/// out of the user's repos is always on.
enum VocabularyPackages {
    static func key(_ package: TermPackage) -> String { "vocabulary." + package.rawValue }

    static func isOn(_ package: TermPackage) -> Bool { UserDefaults.standard.object(forKey: key(package)) as? Bool ?? true }

    static func set(_ package: TermPackage, on: Bool) {
        UserDefaults.standard.set(on, forKey: key(package))
        apply()
    }

    static func title(_ package: TermPackage) -> String {
        switch package {
        case .git: S.gitPackage
        case .terminal: S.terminalPackage
        case .development: S.developmentPackage
        }
    }

    /// Hands the saved switches to `LupitaCore`, which does the lookups.
    static func apply() {
        for package in TermPackage.allCases { TermPackages.set(package, on: isOn(package)) }
    }
}
