import Foundation
import Testing
@testable import LupitaCore

// A click never runs a file: runnable things are shown in Finder instead of opened.

@Suite struct FileSafetyTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-safety-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func make(_ name: String, mode: Int) throws -> String {
        let url = dir.appendingPathComponent(name)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
        return url.path
    }

    @Test func runnableExtensionsCountEvenWhenMissing() {
        for name in ["x.command", "X.APP", "a.pkg"] {
            #expect(FileSafety.runsWhenOpened(dir.appendingPathComponent(name).path), "\(name)")
        }
    }

    @Test func extensionlessExecutableRuns() throws {
        #expect(FileSafety.runsWhenOpened(try make("tool-bin", mode: 0o755)))
    }

    @Test func extensionlessPlainFileDoesNot() throws {
        #expect(!FileSafety.runsWhenOpened(try make("LICENSE", mode: 0o644)))
    }

    @Test func directoryWithoutExtensionDoesNot() throws {
        let sub = dir.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        #expect(!FileSafety.runsWhenOpened(sub.path))
    }

    @Test func notesAndShellScriptsAreOpenedNormally() throws {
        #expect(!FileSafety.runsWhenOpened(try make("notes.md", mode: 0o755)))
        #expect(!FileSafety.runsWhenOpened(try make("script.sh", mode: 0o755)))
    }
}
