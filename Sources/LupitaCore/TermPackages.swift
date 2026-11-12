import Foundation

/// The fixed dictionaries the user can switch off in the menu (D43): knowledge of a trade that the user may
/// already have. What comes out of the user's repos (IDs, glossaries, commits, branches, files, PRs, symbols, CSS
/// tokens, local addresses, `package.json` scripts) is never in a package and is always on.
public enum TermPackage: String, CaseIterable, Sendable {
    /// Git in prose (D42) and the `git …` commands with their flags.
    case git
    /// Shell commands (`rm`, `chmod`, `cd`) and the common package-manager subcommands (`npm install`).
    case terminal
    /// Errors (system, JavaScript, Python), HTTP statuses, HTML tags and the words of development in prose (D62).
    case development
    /// The words of design in prose (D62).
    case design
}

public enum TermPackages {
    // Written from the main thread (the menu), read from the lookups' threads.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var switchedOn = Set(TermPackage.allCases)

    /// Switched off for the current task only: tests use it so they do not disturb each other.
    @TaskLocal public static var off: Set<TermPackage> = []

    public static func isOn(_ package: TermPackage) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return switchedOn.contains(package) && !off.contains(package)
    }

    public static func set(_ package: TermPackage, on: Bool) {
        lock.lock(); defer { lock.unlock() }
        if on { switchedOn.insert(package) } else { switchedOn.remove(package) }
    }
}
