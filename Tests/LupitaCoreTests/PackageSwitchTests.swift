import CoreGraphics
import Foundation
import Testing
@testable import LupitaCore

// D43: the «Explain terms of:» switches turn off fixed dictionaries only.
@Suite struct PackageSwitchTests {
    let resolver: Resolver

    init() throws {
        let repo = try makeCodeRepo("web", ["package.json": "{\n  \"scripts\": {\n    \"build\": \"next build\",\n    \"dev\": \"next dev\"\n  }\n}\n"])
        var index = RefIndex()
        index.repos = [repo]
        resolver = Resolver(index: index)
    }

    func shown(_ text: String) -> Bool {
        CodeRefs.FileListCache.shared.clear(); CodeRefs.TableCache.shared.clear()
        return resolver.resolve(text, preferredRepo: "web").isShown
    }

    func marked(_ line: String) -> Int {
        HighlightPicker.marks(words: HighlightPickerTests.row(line), resolver: resolver).count
    }

    func prose(_ sentence: String) -> Bool {
        S.language = "es"
        let start = sentence.range(of: "⟦")!
        let offset = sentence.distance(from: sentence.startIndex, to: start.lowerBound) + 1
        let line = sentence.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: "")
        return CandidatePicker.pick(line: line, cursorOffset: offset, resolver: resolver)?.isShown ?? false
    }

    static let gitThings = ["git stash", "git rebase main", "git reset --hard", "git push --force"]
    static let terminalThings = ["rm -rf build", "`chmod`", "cd docs", "`ls`"]
    static let developmentThings = ["ENOENT", "TypeError", "`404`", "HTTP 401", "<dialog>"]

    @Test func everythingIsOnByDefault() {
        for text in Self.gitThings + Self.terminalThings + Self.developmentThings { #expect(shown(text), "\(text)") }
        #expect(prose("hay que ⟦rebasear⟧ la rama"))
        #expect(marked("hay que rebasear y hacer un git stash") >= 2)
        #expect(marked("falló con ENOENT") == 1)
        #expect(marked("corre rm en la carpeta") == 1)
    }

    @Test func gitOffTurnsOffGitInProseAndInCommands() {
        TermPackages.$off.withValue([.git]) {
            for text in Self.gitThings { #expect(!shown(text), "\(text)") }
            #expect(!prose("hay que ⟦rebasear⟧ la rama"))
            #expect(!prose("necesito un ⟦force push⟧"))
            #expect(marked("hay que rebasear y hacer un force push") == 0)
            #expect(marked("corre git stash ahora") == 0)
            // The other packages are untouched.
            for text in Self.terminalThings + Self.developmentThings { #expect(shown(text), "\(text)") }
        }
    }

    @Test func terminalOffTurnsOffShellCommandsOnly() {
        TermPackages.$off.withValue([.terminal]) {
            for text in Self.terminalThings { #expect(!shown(text), "\(text)") }
            #expect(!shown("npm install"))
            #expect(marked("corre rm en la carpeta") == 0)
            // Git and development are untouched, and so is a script from package.json.
            for text in Self.gitThings + Self.developmentThings { #expect(shown(text), "\(text)") }
            #expect(shown("git stash"))
            #expect(shown("npm run build"))
            #expect(prose("hay que ⟦rebasear⟧ la rama"))
        }
    }

    @Test func developmentOffTurnsOffErrorsStatusesAndTags() {
        TermPackages.$off.withValue([.development]) {
            for text in Self.developmentThings { #expect(!shown(text), "\(text)") }
            #expect(marked("falló con ENOENT") == 0)
            for text in Self.gitThings + Self.terminalThings { #expect(shown(text), "\(text)") }
        }
    }

    @Test func whatComesFromTheReposIsAlwaysOn() {
        TermPackages.$off.withValue(Set(TermPackage.allCases)) {
            #expect(shown("npm run build"))
            #expect(shown("pnpm dev"))
            for text in Self.gitThings + Self.terminalThings + Self.developmentThings { #expect(!shown(text), "\(text)") }
            #expect(!prose("hay que ⟦rebasear⟧ la rama"))
        }
    }
}
