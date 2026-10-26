import CoreGraphics
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
}
