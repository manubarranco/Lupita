import CoreGraphics
import Foundation
import Testing
@testable import LupitaCore

// What the tooltip answers, the underline marks (Manu, 2026-10-31): sections, commits, branches, dot paths, `Lupita`.
@Suite struct UnderlineEverythingTests {
    static let spec = "# Spec\n\n## 4. Rules\n\nText.\n\n## 7. Output\n\nMore.\n"

    static func sections() -> Resolver {
        var index = RefIndex()
        index.repos = [Repo(name: "r", path: "/r"), Repo(name: "other", path: "/other")]
        index.add(text: spec, fileName: "spec.md", repo: "r", relativePath: "spec.md", absolutePath: "/r/spec.md")
        index.add(text: spec, fileName: "spec.md", repo: "other", relativePath: "spec.md", absolutePath: "/other/spec.md")
        index.rank()
        return Resolver(index: index)
    }

    /// `§4/§7` is one word: the `§` under the pointer is the one looked up.
    @Test func thePieceUnderThePointerOfTwoSections() {
        let word = "§4/§7):"
        #expect(SectionRefs.piece(of: word, at: 1).map { (word as NSString).substring(with: $0) } == "§4/")
        #expect(SectionRefs.piece(of: word, at: 4).map { (word as NSString).substring(with: $0) } == "§7):")
        #expect(SectionRefs.piece(of: "§4.4", at: 2) == nil)
        let r = Self.sections()
        let line = "para §4/§7): la memoria"
        let seven = CandidatePicker.pick(line: line, cursorOffset: 9, resolver: r, preferredRepo: "r", fromPath: "spec.md")
        #expect(seven?.definitions.first?.title == "Output")
        let four = CandidatePicker.pick(line: line, cursorOffset: 6, resolver: r, preferredRepo: "r", fromPath: "spec.md")
        #expect(four?.definitions.first?.title == "Rules")
    }

    /// With no repo from the window and no document named, a bare `§4` could be any repo's: nothing is shown.
    @Test func aBareSectionWithNoRepoShowsNothing() {
        let r = Self.sections()
        #expect(r.resolve("§4").definitions.isEmpty)
        #expect(!r.resolve("§4", preferredRepo: "r", fromPath: "spec.md").definitions.isEmpty)
        #expect(!r.resolve("§4", context: "the spec", block: "the spec §4").definitions.isEmpty)
    }

    /// A chat window names no file: the repo its texts name most is the one meant.
    @Test func theRepoAWindowNamesMost() {
        var index = RefIndex()
        index.repos = [Repo(name: "LiOS", path: "/x/LiOS"), Repo(name: "lupita", path: "/x/lupita"), Repo(name: "DesignerPunk", path: "/x/dp")]
        let r = Resolver(index: index)
        #expect(r.repoMostNamed(in: ["Lupita: próximos pasos", "Entorno LiOS", "en LiOS, el spec de LiOS"]) == "LiOS")
        #expect(r.repoMostNamed(in: ["Lupita: próximos pasos"]) == "lupita")
        #expect(r.repoMostNamed(in: ["nada que ver", "Liosa"]) == nil)
    }

    /// The second layer underlines a `§` the reader's file answers, each piece of `§4/§7` on its own part of the box.
    @Test func sectionsAreUnderlinedInTheSecondLayer() {
        let r = Self.sections()
        let word = OCRWord(text: "§4/§7", box: CGRect(x: 0, y: 0, width: 50, height: 14))
        let candidates = HighlightPicker.symbolCandidates(words: [word], excluding: [])
        #expect(Set(candidates.keys) == ["§4", "§7"])
        #expect(candidates["§7"]?.first?.minX == 30)
        let found = Found()
        HighlightPicker.findSymbols(candidates, resolver: r, preferredRepo: "r", fromPath: "spec.md", stop: { false }) { found.add($0.count) }
        #expect(found.total == 2)
    }

    /// Commits and branches are looked up in the second layer: their shapes make candidates, prose does not.
    @Test func commitsAndBranchesAreCandidates() {
        let words = ["58fd19f", "feature/structured-files", "HTML/JSON", "0/12", "qué/por", "y/o"].map {
            OCRWord(text: $0, box: CGRect(x: 0, y: 0, width: 10, height: 14))
        }
        #expect(Set(HighlightPicker.symbolCandidates(words: words, excluding: []).keys) == ["58fd19f", "feature/structured-files", "y/o"])
        #expect(!RepoRefs.matches(RepoRefs.branchName, "HTML/JSON"))
        #expect(!RepoRefs.matches(RepoRefs.branchName, "20/20"))
    }

    /// A deleted branch: a merge names it, or a commit cites it with a usual prefix. `0/12` in a message is no branch.
    @Test func proseInACommitMessageIsNoDeletedBranch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-br-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func git(_ args: String...) { _ = Git.output(root.path, ["-c", "user.name=t", "-c", "user.email=t@t"] + args) }
        git("init", "-q", "-b", "main")
        try "a".write(to: root.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        git("add", "a.txt")
        git("commit", "-q", "-m", "docs: gate passed with 0/12 overrides, visor HTML/JSON and explore/highlight")
        let repos = [Repo(name: "r", path: root.path)]
        #expect(RepoRefs.branches("0/12", repos: repos).isEmpty)
        #expect(RepoRefs.branches("HTML/JSON", repos: repos).isEmpty)
        #expect(RepoRefs.branches("explore/highlight", repos: repos).first?.title == S.branchDeleted)
    }

    /// `.claude/commands` keeps its dot; `Lupita` is the repo `lupita` when its README says so; `nib` keeps its case.
    @Test func dotPathsAndCapitalisedRepoNames() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-dot-\(UUID().uuidString)/lupita")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude/commands"), withIntermediateDirectories: true)
        try "# Lupita\n\nTooltips.\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        var index = RefIndex()
        index.repos = [Repo(name: "lupita", path: root.path), Repo(name: "nib", path: "/x/nib")]
        let r = Resolver(index: index)
        #expect(HighlightPicker.kind(of: ".claude/commands", resolver: r, block: "") == .id)
        #expect(HighlightPicker.kind(of: "Lupita", resolver: r, block: "") == .id)
        #expect(HighlightPicker.kind(of: "Nib", resolver: r, block: "") == nil)
    }
}

final class Found: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var total = 0
    func add(_ n: Int) { lock.lock(); total += n; lock.unlock() }
}

// `el núcleo (§1)`: a word before that names no document of the repos is prose; the reader's file answers.
@Suite struct SectionProseBeforeTests {
    @Test func aSpanishWordBeforeIsNoDocument() {
        var index = RefIndex()
        index.repos = [Repo(name: "LiOS", path: "/LiOS")]
        let spec = "# Spec\n\n## 1. Por qué existe\n\nTexto.\n\n- *Memoria* — el núcleo (§1).\n"
        index.add(text: spec, fileName: "lios-intention.md", repo: "LiOS", relativePath: "spec/lios-intention.md", absolutePath: "/LiOS/spec/lios-intention.md")
        index.add(text: "## 1. Otro\n", fileName: "nucleo.md", repo: "LiOS", relativePath: "x/nucleo.md", absolutePath: "/LiOS/x/nucleo.md")
        index.rank()
        let r = Resolver(index: index)
        let line = "- *Memoria* — el núcleo (§1)."
        let found = CandidatePicker.pick(line: line, cursorOffset: 25, resolver: r, preferredRepo: "LiOS", fromPath: "spec/lios-intention.md")
        #expect(found?.definitions.first?.title == "Por qué existe")
        // A real document named before: `nucleo §1` is that file's.
        #expect(r.resolve("§1", preferredRepo: "LiOS", context: "see nucleo", fromPath: "spec/lios-intention.md", block: "see nucleo §1")
            .definitions.first?.title == "Otro")
    }
}
