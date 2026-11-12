import Foundation
import Testing
@testable import LupitaCore

// Only the project's own GitHub release assets feed the in-place update.

@Suite struct ProjectReleaseAssetTests {
    private func ok(_ s: String) -> Bool { Versions.isProjectReleaseAsset(URL(string: s)!) }

    @Test func realAssetPasses() {
        #expect(ok("https://github.com/manubarranco/lupita/releases/download/v0.12.0/Lupita.zip"))
    }

    /// The address GitHub's API really gives (2026-11-12): the repo with its capital letter.
    @Test func theAddressGitHubGivesPasses() {
        #expect(ok("https://github.com/manubarranco/Lupita/releases/download/v0.11.0/Lupita.zip"))
    }

    @Test func httpFails() {
        #expect(!ok("http://github.com/manubarranco/lupita/releases/download/v0.12.0/Lupita.zip"))
    }

    @Test func otherHostsFail() {
        #expect(!ok("https://github.com.evil.example/manubarranco/lupita/releases/download/v1/Lupita.zip"))
        #expect(!ok("https://evil.example/manubarranco/lupita/releases/download/v1/Lupita.zip"))
    }

    @Test func otherRepoFails() {
        #expect(!ok("https://github.com/someone/lupita/releases/download/v1/Lupita.zip"))
        #expect(!ok("https://github.com/manubarranco/lupita/archive/main.zip"))
    }

    @Test func fileURLFails() {
        #expect(!ok("file:///manubarranco/lupita/releases/download/v1/Lupita.zip"))
    }

    @Test func userInfoTrickFails() {
        #expect(!ok("https://github.com@evil.example/manubarranco/lupita/releases/download/x/Lupita.zip"))
    }
}
