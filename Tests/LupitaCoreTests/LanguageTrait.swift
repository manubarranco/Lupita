import Testing
@testable import LupitaCore

/// Runs a test (or every test of a suite) in a language that only that test sees. `S.language` is global: setting it
/// from a test made other suites, running in parallel, read the wrong language.
struct LanguageTrait: TestTrait, SuiteTrait, TestScoping {
    let language: String
    var isRecursive: Bool { true }

    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await S.languageOverride.withValue(language) { try await function() }
    }
}

extension Trait where Self == LanguageTrait {
    static func language(_ language: String) -> Self { LanguageTrait(language: language) }
}
