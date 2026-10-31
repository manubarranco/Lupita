import CoreGraphics
import Foundation
import Testing
@testable import LupitaCore

// D39: which words the highlight mode underlines.
@Suite struct HighlightPickerTests {
    static func resolver() -> Resolver {
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas")]
        index.add(text: "## D023 — Sin dependencias\nNada nuevo.\n", fileName: "decisions.md", repo: "atlas", relativePath: "docs/decisions.md", absolutePath: "/x/atlas/docs/decisions.md")
        index.add(text: "- **fast-forward** — avanzar sin merge\n- **saldo inicial** — lo que hay al abrir\n", fileName: "glossary.md", repo: "atlas", relativePath: "docs/glossary.md", absolutePath: "/x/atlas/docs/glossary.md")
        index.rank()
        return Resolver(index: index)
    }

    /// Words laid out on one row, 10 pt per character, 4 pt gaps.
    static func row(_ text: String, y: CGFloat = 0) -> [OCRWord] {
        var x: CGFloat = 0
        return text.split(separator: " ").map { w in
            defer { x += CGFloat(w.count) * 10 + 4 }
            return OCRWord(text: String(w), box: CGRect(x: x, y: y, width: CGFloat(w.count) * 10, height: 14))
        }
    }

    /// `FR-` at the end of a line and `001, 002 y 003` on the next, with a sidebar word between on the same screen row:
    /// the first half, the joined ID and the numbers that follow are all marked.
    @Test func aListBrokenAcrossLinesIsMarkedWithItsNumbers() {
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas")]
        index.add(text: "- **FR-001**: One\n- **FR-002**: Two\n- **FR-003**: Three\n", fileName: "fr.md", repo: "atlas", relativePath: "docs/fr.md", absolutePath: "/x/atlas/docs/fr.md")
        index.rank()
        let r = Resolver(index: index)
        // Row 1: a sidebar word far left, then the sentence ending in `FR-`. Row 2: another sidebar word, then the list.
        let row1 = [OCRWord(text: "Hoy", box: CGRect(x: 0, y: 0, width: 30, height: 14))] + Self.row("una lista FR-", y: 0).map { OCRWord(text: $0.text, box: $0.box.offsetBy(dx: 300, dy: 0)) }
        let row2 = [OCRWord(text: "Resultados", box: CGRect(x: 0, y: 20, width: 100, height: 14))] + Self.row("001, 002 y 003.", y: 20).map { OCRWord(text: $0.text, box: $0.box.offsetBy(dx: 300 + 40, dy: 0)) }
        let marks = HighlightPicker.marks(words: row1 + row2, resolver: r)
        // `FR-`, `001,`, `002` and `003.`
        #expect(marks.count == 4)
    }

    /// The sidebar item `Cambios` sits 6 pt below `Hoy • FR-` and makes a row of its own between the two lines of the list.
    @Test func aSidebarRowBetweenTheTwoLinesDoesNotHideTheList() {
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas")]
        index.add(text: "- **FR-001**: One\n- **FR-002**: Two\n- **FR-003**: Three\n", fileName: "fr.md", repo: "atlas", relativePath: "docs/fr.md", absolutePath: "/x/atlas/docs/fr.md")
        index.rank()
        let r = Resolver(index: index)
        func at(_ x: CGFloat, _ y: CGFloat, _ t: String, w: CGFloat = 30) -> OCRWord { OCRWord(text: t, box: CGRect(x: x, y: y, width: w, height: 14)) }
        let words = [at(17, 365, "Hoy"), at(606, 365, "FR-"), at(1200, 371, "Cambios", w: 60),
                     at(606, 384, "001,", w: 40), at(650, 384, "002,", w: 40), at(694, 384, "003", w: 30)]
        #expect(HighlightPicker.marks(words: words, resolver: r).count == 4)
    }

    @Test func marksIDsTermsAndCommands() {
        let marks = HighlightPicker.marks(words: Self.row("per D023 we use fast-forward and git stash"), resolver: Self.resolver())
        #expect(marks.count == 3)
    }

    @Test func marksRepoNamesTagsAndStatuses() {
        let r = Self.resolver()
        let kinds = HighlightPicker.classified(words: Self.row("in atlas the <dialog> returns HTTP 401 and ENOENT"), resolver: r).map(\.kind)
        #expect(kinds == [.id, .term, .term, .term])
        // No hint, wrong case, not a tag: nothing.
        #expect(HighlightPicker.marks(words: Self.row("chapter 401 of Atlas, a <notatag> here"), resolver: r).isEmpty)
    }

    /// OCR reads `LiOS` in a code font as `LioS`; the tooltip finds it, so the underline must too. A plain
    /// lowercase name keeps its exact case.
    @Test func mixedCaseRepoNamesMatchAnyCase() {
        var index = RefIndex()
        index.repos = [Repo(name: "LiOS", path: "/x/LiOS"), Repo(name: "app", path: "/x/app")]
        let r = Resolver(index: index)
        #expect(HighlightPicker.classified(words: Self.row("see LioS and app"), resolver: r).map(\.kind) == [.id, .id])
        #expect(HighlightPicker.marks(words: Self.row("the App and APP"), resolver: r).isEmpty)
    }

    /// D49: a file or folder that exists in a repo is underlined like an ID; one that does not, is not.
    @Test func existingFilesAreMarked() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-hl-\(UUID().uuidString)/atlas")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "# D\n".write(to: root.appendingPathComponent("docs/decisions.md"), atomically: true, encoding: .utf8)
        try "# C\n".write(to: root.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: root.path)]
        let r = Resolver(index: index)
        let marks = HighlightPicker.classified(words: Self.row("see docs/decisions.md, CLAUDE.md:3 and docs/nope.md y/o"), resolver: r)
        #expect(marks.map(\.kind) == [.id, .id])
    }

    /// A bare name (`decisions.md`) is found wherever the index saw it, shallowest first, in the tooltip and the underline.
    @Test func bareFileNamesAreFoundAnywhereInTheRepo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-hl-\(UUID().uuidString)/atlas")
        for folder in ["docs", "domains/billing"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
            try "# Decisions\n".write(to: root.appendingPathComponent(folder + "/decisions.md"), atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: root.path)]
        for rel in ["domains/billing/decisions.md", "docs/decisions.md"] {
            index.add(text: "# Decisions\n", fileName: "decisions.md", repo: "atlas", relativePath: rel,
                      absolutePath: root.appendingPathComponent(rel).path)
        }
        let r = Resolver(index: index)
        #expect(r.resolve("decisions.md", preferredRepo: "atlas").definitions.map(\.path) == ["docs/decisions.md", "domains/billing/decisions.md"])
        let marks = HighlightPicker.classified(words: Self.row("see decisions.md, not notes.md"), resolver: r)
        #expect(marks.map(\.kind) == [.id])
    }

    /// The tooltip takes the code font as a hint too: a bare `401` in inline code is a status, as it is underlined.
    @Test func aCodeStyledStatusResolvesLikeItIsUnderlined() {
        let r = Self.resolver()
        #expect(r.resolve("401", codeStyled: true).definitions.first?.rule == .error)
        #expect(r.resolve("401").definitions.first?.rule != .error)
    }

    @Test func ignoresWhatIsNotKnown() {
        let marks = HighlightPicker.marks(words: Self.row("the yak-shave of D999 and debounceIndex()"), resolver: Self.resolver())
        #expect(marks.isEmpty)
    }

    @Test func aPhraseGivesOneBoxAndPunctuationIsLeftOut() {
        let words = Self.row("see saldo inicial, then D023.")
        let marks = HighlightPicker.marks(words: words, resolver: Self.resolver())
        #expect(marks.count == 2)
        // "D023." is 5 characters wide (50 pt); the box leaves the dot out.
        #expect(abs(marks[1].width - 40) < 0.5)
        // The phrase covers both words, and the comma is dropped from the end.
        #expect(abs(marks[0].width - ((words[2].box.maxX - words[1].box.minX) - 10)) < 0.5)
    }

    @Test func aPhraseDoesNotCrossAClosingPunctuationOrAGap() {
        let closed = HighlightPicker.marks(words: Self.row("saldo, inicial"), resolver: Self.resolver())
        #expect(closed.isEmpty)
        var far = Self.row("saldo inicial")
        far[1] = OCRWord(text: "inicial", box: far[1].box.offsetBy(dx: 400, dy: 0))
        #expect(HighlightPicker.marks(words: far, resolver: Self.resolver()).isEmpty)
    }

    @Test func eachRowIsReadOnItsOwn() {
        let words = Self.row("D023", y: 0) + Self.row("git stash", y: 40)
        #expect(HighlightPicker.marks(words: words, resolver: Self.resolver()).count == 2)
    }

    /// After a hold the lookup reuses the window's words: the word under the pointer is found among all of them.
    @Test func theWindowsWordsAnswerAPointerLookup() {
        let words = Self.row("per D023 we use fast-forward", y: 0) + Self.row("nothing here to see", y: 40) + Self.row("and saldo inicial too", y: 80)
        let atID = CandidatePicker.pick(words: words, cursor: CGPoint(x: 55, y: 7), resolver: Self.resolver())
        #expect(atID?.key == "D23" || atID?.key == "D023")
        let atTerm = CandidatePicker.pick(words: words, cursor: CGPoint(x: 80, y: 87), resolver: Self.resolver())
        #expect(atTerm?.definitions.isEmpty == false)
    }

    // Ink per mark: a dark editor next to a light sidebar in one window.
    @Test func inkFollowsTheBackgroundUnderEachMark() {
        let light = OCRWord(text: "D023", box: CGRect(x: 0, y: 0, width: 40, height: 14), background: 0.95)
        let dark = OCRWord(text: "D023", box: CGRect(x: 300, y: 0, width: 40, height: 14), background: 0.12)
        let words = [light, dark]
        #expect(HighlightPicker.isDark(behind: light.box, words: words) == false)
        #expect(HighlightPicker.isDark(behind: dark.box, words: words) == true)
        // Nothing measured: the caller falls back to the whole window.
        #expect(HighlightPicker.isDark(behind: CGRect(x: 600, y: 0, width: 40, height: 14), words: words) == nil)
    }

    // D46: IDs get a solid line, terms a dashed one.
    @Test func marksSayWhetherTheyAreIDsOrTerms() {
        let marks = HighlightPicker.classified(words: Self.row("per D023 we use fast-forward and git stash"), resolver: Self.resolver())
        #expect(marks.map(\.kind) == [.id, .term, .term])
    }

    /// D51: what the tooltip explains from its shape or one cheap check.
    @Test func shapesAndCheapChecks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-hl51-\(UUID().uuidString)/atlas")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent(".claude/commands"), withIntermediateDirectories: true)
        try "---\ndescription: Retro semanal\n---\n".write(to: root.appendingPathComponent(".claude/commands/retro.md"), atomically: true, encoding: .utf8)
        try ":root { --accent: #0e5400; }\n".write(to: root.appendingPathComponent("app.css"), atomically: true, encoding: .utf8)
        try #"{"scripts": {"build": "astro build"}}"#.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root.deletingLastPathComponent()) }
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: root.path)]
        let r = Resolver(index: index)
        func kinds(_ s: String) -> [HighlightPicker.Kind] { HighlightPicker.classified(words: Self.row(s), resolver: r).map(\.kind) }
        #expect(kinds("usa --accent y #1a1a1a") == [.id, .term])
        #expect(kinds("abre localhost:8130 o http://127.0.0.1:4321/x") == [.term, .term])
        // OCR splits an address in a code font: one mark over both halves.
        let split = HighlightPicker.classified(words: Self.row("en localhost: 8130 ya"), resolver: r)
        #expect(split.count == 1 && split[0].box.minX == 24)
        // The tooltip answers on either half too.
        #expect(CandidatePicker.pick(words: Self.row("en localhost: 8130 ya"), cursor: CGPoint(x: 140, y: 7), resolver: r)?.query.hasPrefix("localhost:8130") == true)
        #expect(kinds("lanza /retro y mira PR #123") == [.id, .id])
        // Not a token of the repos, a bare number, a path that is no command, digits only: nothing.
        #expect(kinds("con --force el #12 en /tmp y #333").isEmpty)
        let npm = HighlightPicker.classified(words: Self.row("corre npm run build y luego"), resolver: r)
        // One mark over the three words (`corre` ends at 50, `build` at 172), not over `y luego`.
        #expect(npm.count == 1 && npm[0].box.minX == 54 && npm[0].box.maxX == 172)
    }

    /// D51: git words come out alone, inside «», misread as `k…»`, and split across lines.
    @Test func gitWordsInQuotesAndAcrossLines() {
        let r = Self.resolver()
        #expect(HighlightPicker.marks(words: Self.row("puedes «stashear» o kstashear» o «stashears antes"), resolver: r).count == 3)
        // A real plural in quotes keeps its s: «rebases» is not misread.
        #expect(HighlightPicker.marks(words: Self.row("los «saldos» no"), resolver: r).isEmpty)
        #expect(HighlightPicker.marks(words: Self.row("estás en detached HEAD ahora"), resolver: r).count == 1)
        let split = Self.row("hicimos un merge fast-", y: 0) + Self.row("forward ayer", y: 18)
        #expect(HighlightPicker.classified(words: split, resolver: r).map(\.box.minX) == [152, 0])
    }

    /// D53: symbols are a second layer: candidates by shape, found in the repos' source, as answers come back.
    @Test func symbolsComeAsASecondLayer() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-sym-\(UUID().uuidString)/atlas")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "def build_glyphs(p):\n    pass\n\nARM_TENSION = 0.4\n".write(to: root.appendingPathComponent("engine.py"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: root.path)]
        let r = Resolver(index: index)
        let words = Self.row("llama build_glyphs con ARM_TENSION y no_such_thing ni slider en atlas")
        let first = HighlightPicker.classified(words: words, resolver: r)
        let candidates = HighlightPicker.symbolCandidates(words: words, excluding: first)
        // `slider` is a plain word, `atlas` already marked as a repo: neither is a candidate.
        #expect(Set(candidates.keys) == ["build_glyphs", "ARM_TENSION", "no_such_thing"])
        let found = Collected()
        HighlightPicker.findSymbols(candidates, resolver: r, stop: { false }) { found.add($0) }
        #expect(found.marks.map(\.box.minX).sorted() == [54, 212])
        #expect(found.marks.allSatisfy { $0.kind == .id })
        // Let go before the lookups start: nothing comes back.
        let none = Collected()
        HighlightPicker.findSymbols(candidates, resolver: r, stop: { true }) { none.add($0) }
        #expect(none.marks.isEmpty)
    }
}

final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var all: [HighlightPicker.Mark] = []
    func add(_ m: [HighlightPicker.Mark]) { lock.lock(); all += m; lock.unlock() }
    var marks: [HighlightPicker.Mark] { lock.lock(); defer { lock.unlock() }; return all }

    @Test func aPhraseWithAWordThatCleansToNothingDoesNotCrash() {
        var index = RefIndex()
        index.repos = []
        let r = Resolver(index: index)
        let row = ["npm", "**"].enumerated().map {
            OCRWord(text: $0.element, box: CGRect(x: CGFloat($0.offset) * 40, y: 0, width: 30, height: 12))
        }
        #expect(HighlightPicker.phraseLength(row, at: 0, resolver: r, block: "") == nil)
    }

    @Test func aWordFormIsOneSolidMark() {
        var index = RefIndex()
        index.add(text: "### Task Group 2: Export\n", fileName: "a.md", repo: "r", relativePath: "a.md", absolutePath: "/r/a.md")
        index.rank()
        let r = Resolver(index: index)
        let words = ["See", "Task", "Group", "2,", "and", "Task", "9"].enumerated().map {
            OCRWord(text: $0.element, box: CGRect(x: CGFloat($0.offset) * 50, y: 0, width: 45, height: 12))
        }
        let marks = HighlightPicker.classified(words: words, resolver: r)
        #expect(marks.filter { $0.kind == .id }.count == 1)
        #expect(marks.first { $0.kind == .id }?.box.minX == 50)
        #expect(marks.first { $0.kind == .id }?.box.maxX ?? 0 > 150)
    }

    @Test func aWordFormInParenthesesIsOneSolidMark() {
        var index = RefIndex()
        index.add(text: "### Task 2.3: Export\n### Requirement 3: Login\n", fileName: "a.md", repo: "r", relativePath: "a.md", absolutePath: "/r/a.md")
        index.rank()
        let r = Resolver(index: index)
        for texts in [["Done", "(Task", "2.3)", "Requirement", "3"], ["Done", "(", "Task", "2.3)", "Requirement", "3"],
                      ["Done", "(Task", "2.3", ")", "Requirement", "3"], ["Requirement", "3", "(Task", "2.3)"], ["(Task", "2.3,", "Requirement", "3,"]] {
            let words = texts.enumerated().map { OCRWord(text: $0.element, box: CGRect(x: CGFloat($0.offset) * 50, y: 0, width: 45, height: 12)) }
            let marks = HighlightPicker.classified(words: words, resolver: r)
            #expect(marks.filter { $0.kind == .id }.count == 2, "\(texts) → \(marks)")
        }
    }

    @Test func aLoneParenthesisBeforeAGlossaryWordDoesNotHideTheForm() {
        var index = RefIndex()
        index.add(text: "### Task 2.3: Export\n", fileName: "a.md", repo: "r", relativePath: "a.md", absolutePath: "/r/a.md")
        index.add(text: "- **Task** — a unit of work\n", fileName: "glossary.md", repo: "r", relativePath: "glossary.md", absolutePath: "/r/glossary.md")
        index.rank()
        let r = Resolver(index: index)
        #expect(r.resolveTerm("Task") != nil)
        let words = ["con", "(", "Task", "2.3)", "suelto"].enumerated().map {
            OCRWord(text: $0.element, box: CGRect(x: CGFloat($0.offset) * 50, y: 0, width: 45, height: 12))
        }
        let marks = HighlightPicker.classified(words: words, resolver: r)
        #expect(marks.map(\.kind) == [.id])
        #expect(marks.first?.box.minX == 100)
    }

    @Test func aWordFormBrokenAcrossTwoLinesIsMarkedOnBothHalves() {
        var index = RefIndex()
        index.add(text: "### Requirement 3: Login\n### Task Group 2: Export\n", fileName: "a.md", repo: "r", relativePath: "a.md", absolutePath: "/r/a.md")
        index.rank()
        let r = Resolver(index: index)
        func word(_ t: String, _ x: CGFloat, _ y: CGFloat) -> OCRWord { OCRWord(text: t, box: CGRect(x: x, y: y, width: 60, height: 12)) }
        let broken = [word("Covers", 0, 0), word("Requirement", 65, 0), word("3,", 0, 14), word("and", 65, 14)]
        let marks = HighlightPicker.classified(words: broken, resolver: r)
        #expect(marks.count == 2 && marks.allSatisfy { $0.kind == .id })
        #expect(Set(marks.map { $0.box.minY }) == [0, 14])
        // A sentence end between the lines is not a form.
        let ended = [word("Covers", 0, 0), word("Requirement.", 65, 0), word("3", 0, 14)]
        #expect(HighlightPicker.classified(words: ended, resolver: r).isEmpty)
        let group = [word("See", 0, 0), word("Task", 65, 0), word("Group", 130, 0), word("2", 0, 14)]
        #expect(HighlightPicker.classified(words: group, resolver: r).count == 2)
    }

    @Test func aBrokenFormIsFoundWithASidebarOnTheSameScreenLine() {
        var index = RefIndex()
        index.add(text: "### Requirement 3: Login\n", fileName: "a.md", repo: "r", relativePath: "a.md", absolutePath: "/r/a.md")
        index.rank()
        let r = Resolver(index: index)
        func word(_ t: String, _ x: CGFloat, _ y: CGFloat) -> OCRWord { OCRWord(text: t, box: CGRect(x: x, y: y, width: 60, height: 12)) }
        // The sidebar's words share each screen line with the chat's words.
        let words = [word("Lupita", 17, 0), word("Covers", 401, 0), word("Requirement", 470, 0), word("Contexto", 1200, 0),
                     word("Notes", 17, 14), word("3,", 403, 14), word("and", 470, 14), word("44", 1382, 14)]
        let marks = HighlightPicker.classified(words: words, resolver: r)
        #expect(marks.count == 2 && marks.allSatisfy { $0.kind == .id })
        #expect(Set(marks.map { $0.box.minX }) == [470, 403])
    }
}
