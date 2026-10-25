import Foundation
import LupitaCore

/// The «Explain terms of:» switches in the menu (D42). One per vocabulary package; only Git so far.
/// On by default, like the lens: the package works from the first minute.
enum VocabularyPackages {
    static let gitKey = "vocabulary.git"

    static var gitOn: Bool {
        get { UserDefaults.standard.object(forKey: gitKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: gitKey)
            apply()
        }
    }

    /// Hands the saved switches to `LupitaCore`, which does the lookups.
    static func apply() { GitVocabulary.isEnabled = gitOn }
}
