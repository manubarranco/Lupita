import Foundation
import Testing
@testable import LupitaCore

// A path with `..` never leaves its repo.

@Suite struct PathEscapeTests {
    let repo: Repo

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-escape-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "# Readme\n\nInside.\n".write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Outside\n\nSecret.\n".write(to: root.appendingPathComponent("outside.md"), atomically: true, encoding: .utf8)
        repo = Repo(name: "repo", path: RepoDiscovery.realPath(dir.path))
    }

    @Test func parentPathOutsideTheRepoIsNotAFile() {
        #expect(!RepoRefs.isFile("../outside.md", repos: [repo]))
        #expect(RepoRefs.resolve("../outside.md", repos: [repo], preferredRepo: "repo") == nil)
    }

    @Test func parentPathStayingInsideStillResolves() {
        #expect(RepoRefs.isFile("docs/../README.md", repos: [repo]))
        #expect(RepoRefs.resolve("docs/../README.md", repos: [repo], preferredRepo: "repo") != nil)
    }
}
