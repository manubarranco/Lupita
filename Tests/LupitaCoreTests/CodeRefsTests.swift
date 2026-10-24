import Foundation
import Testing
@testable import LupitaCore

// D29: what agents cite from code, looked up in throwaway repos.

/// A folder with files; `.git` is an empty folder so it counts as a repo.
func makeCodeRepo(_ name: String, _ files: [String: String], in parent: URL? = nil) throws -> Repo {
    let base = parent ?? FileManager.default.temporaryDirectory.appendingPathComponent("lupita-code-\(UUID().uuidString)")
    let dir = base.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
    for (path, text) in files {
        let url = dir.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
    return Repo(name: name, path: RepoDiscovery.realPath(dir.path))
}

func resolveCode(_ text: String, _ repos: [Repo], window: String? = nil) -> Resolution? {
    CodeRefs.FileListCache.shared.clear()
    return CodeRefs.resolve(text, repos: repos, preferredRepo: window)
}

@Suite(.serialized) struct SymbolTests {
    let repo: Repo

    init() throws {
        repo = try makeCodeRepo("atlas", [
            "engine.py": """
            \"\"\"Engine module.\"\"\"
            # How far the arm pulls before it lands
            ARM_TENSION = 0.4
            MAX_RETRIES = 3  # attempts before giving up
            NO_NOTE_AT_ALL = 1

            def build_glyphs(params):
                \"\"\"Pure function: params dict -> glyphs.
                Single geometric entry point.
                Second note.
                Fourth line is cut.
                \"\"\"
                return {}

            # Draws the tail stroke
            # of a g or a j
            @decorated
            def _tail_stroke(p0):
                return p0

            def _bare_stroke(p0):
                return p0

            class FontBuilder:
                \"\"\"Builds the font.\"\"\"

            SHAPES = {
                # the open bowl
                "panza_a": {"rx": 1},
                "bare_key": 2,
            }
            """,
            "test_engine.py": "\"\"\"Engine invariants: moving contrast must not move x-height.\"\"\"\nimport engine\n",
            "viewer/edit_ops.js": """
            /**
             * Bakes a sub-group.
             * Reads rx and ry.
             */
            export function bakeBowlStemOpen(sub) {}

            // Unit tangent of a curve
            const tangentUnit = (p) => p;
            const plainThing = 1;
            const table = {
              // spring back
              spring_y: 3,
            };
            class Scrubber {
              // attaches the scrub handle
              attachScrub(el) {
              }
            }
            """,
            "App.swift": """
            /// Shows the tooltip.
            /// Closes on Esc.
            @MainActor
            func showTooltip() {}

            // The widest column
            let maxColumns = 3
            struct Plain {}
            """,
            "style.css": """
            /* The primary button */
            .btn-primary { color: red; }
            .no-note { color: blue; }
            """,
            "node_modules/lib/index.js": "function ignoredFunction() {}\n",
            "build/out.js": "function ignoredBuilt() {}\n",
        ])
    }

    func first(_ text: String, window: String? = nil) -> Definition? {
        resolveCode(text, [repo], window: window)?.definitions.first
    }

    @Test func pythonDocstringWinsAndIsCappedAtThreeLines() {
        let d = first("build_glyphs")
        #expect(d?.rule == .symbol)
        #expect(d?.title == "Pure function: params dict -> glyphs.")
        #expect(d?.summary == "Single geometric entry point.\nSecond note.")
        #expect(d?.path == "engine.py")
        #expect(d?.line == 7)
        #expect(d?.absolutePath.hasSuffix("/engine.py") == true)
    }

    @Test func pythonCommentAboveSkipsDecorators() {
        let d = first("_tail_stroke")
        #expect(d?.title == "Draws the tail stroke")
        #expect(d?.summary == "of a g or a j")
    }

    @Test func pythonConstantsUseTheCommentAboveOrBesideThem() {
        #expect(first("ARM_TENSION")?.title == "How far the arm pulls before it lands")
        #expect(first("MAX_RETRIES")?.title == "attempts before giving up")
    }

    @Test func aSymbolWithoutCommentSaysSoByBeingEmpty() {
        let d = first("NO_NOTE_AT_ALL")
        #expect(d?.rule == .symbol)
        #expect(d?.title == "")
        #expect(d?.line == 5)
        #expect(first("_bare_stroke")?.title == "")
    }

    @Test func dictionaryKeysAreSymbols() {
        #expect(first("panza_a")?.title == "the open bowl")
        #expect(first("bare_key")?.title == "")
    }

    @Test func testNamesResolveToTheirFileAndDocstring() {
        let d = first("test_engine")
        #expect(d?.path == "test_engine.py")
        #expect(d?.line == 1)
        #expect(d?.title == "Engine invariants: moving contrast must not move x-height.")
    }

    @Test func classes() {
        #expect(first("FontBuilder")?.title == "Builds the font.")
    }

    @Test func javascriptJSDocAndSlashComments() {
        #expect(first("bakeBowlStemOpen")?.title == "Bakes a sub-group.")
        #expect(first("bakeBowlStemOpen")?.summary == "Reads rx and ry.")
        #expect(first("tangentUnit")?.title == "Unit tangent of a curve")
        #expect(first("plainThing")?.title == "")
        #expect(first("spring_y")?.title == "spring back")
        #expect(first("attachScrub")?.title == "attaches the scrub handle")
    }

    @Test func swiftDocCommentsSkipAttributes() {
        #expect(first("showTooltip")?.title == "Shows the tooltip.")
        #expect(first("showTooltip")?.summary == "Closes on Esc.")
        #expect(first("maxColumns")?.title == "The widest column")
    }

    @Test func cssClassesWithTheCommentAbove() {
        #expect(first("`btn-primary`") == nil)  // kebab names are not identifiers
        let css = try? makeCodeRepo("sheet", ["a.css": "/* The primary button */\n.panel_main { color: red; }\n"])
        #expect(css.flatMap { resolveCode("panel_main", [$0])?.definitions.first?.title } == "The primary button")
    }

    @Test func plainWordsAreNoiseUnlessCalledOrBackticked() {
        // `plainThing` is camelCase: code. `RETRIES` has no underscore or hump: a word. `Scrubber` is one hump.
        #expect(first("plainThing") != nil)
        let repo = try? makeCodeRepo("words", ["a.py": "def slider(x):\n    \"\"\"Moves it.\"\"\"\n"])
        #expect(repo.flatMap { resolveCode("slider", [$0]) } == nil)
        #expect(repo.flatMap { resolveCode("slider()", [$0])?.definitions.first?.title } == "Moves it.")
        #expect(repo.flatMap { resolveCode("`slider`", [$0])?.definitions.first?.title } == "Moves it.")
        // The picker splits at `(`: the text after the word says it is called.
        #expect(repo.flatMap { r in CodeRefs.resolve("slider", repos: [r], preferredRepo: nil, after: "()") } != nil)
        #expect(first("Scrubber") == nil)
    }

    @Test func shortNamesAndMissingOnesAreNotAnswered() {
        #expect(first("h()") == nil)
        #expect(first("never_defined_anywhere") == nil)
        #expect(first("ignoredFunction") == nil)
        #expect(first("ignored_built") == nil)
    }

    @Test func foldersThatAreNotSourceAreSkipped() {
        #expect(first("ignoredFunction()") == nil)
        #expect(first("ignoredBuilt()") == nil)
    }

    @Test func theWindowsRepoWinsAndTheOtherIsFlagged() throws {
        let other = try makeCodeRepo("other", ["x.py": "def shared_name():\n    \"\"\"Other.\"\"\"\n"])
        let mine = try makeCodeRepo("mine", ["y.py": "def shared_name():\n    \"\"\"Mine.\"\"\"\n"])
        let a = resolveCode("shared_name", [other, mine], window: "mine")
        #expect(a?.definitions.first?.title == "Mine.")
        #expect(a?.fromOtherRepo == false)
        let b = resolveCode("shared_name", [other, mine], window: "elsewhere")
        #expect(b?.definitions.first?.title == "Other.")
        let c = resolveCode("only_in_other", [try makeCodeRepo("third", [:]), other], window: "third")
        #expect(c == nil)
        let d = try makeCodeRepo("fourth", ["z.py": "def other_only():\n    pass\n"])
        let e = resolveCode("other_only", [mine, d], window: "mine")
        #expect(e?.definitions.first?.repo == "fourth")
        #expect(e?.fromOtherRepo == true)
    }

    @Test func mainCheckoutsComeBeforeLinkedWorktrees() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-wt-\(UUID().uuidString)")
        let main = try makeCodeRepo("nib", ["m.py": "def in_main():\n    \"\"\"Main.\"\"\"\n"], in: base)
        let wt = base.appendingPathComponent("nib-worktrees/feat")
        try FileManager.default.createDirectory(at: wt, withIntermediateDirectories: true)
        try "gitdir: x".write(to: wt.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        try "def in_main():\n    \"\"\"Worktree.\"\"\"\n\ndef only_in_worktree():\n    \"\"\"WT only.\"\"\"\n".write(
            to: wt.appendingPathComponent("w.py"), atomically: true, encoding: .utf8)
        let admin = URL(fileURLWithPath: main.path + "/.git/worktrees/feat")
        try FileManager.default.createDirectory(at: admin, withIntermediateDirectories: true)
        try (wt.path + "/.git\n").write(to: admin.appendingPathComponent("gitdir"), atomically: true, encoding: .utf8)
        #expect(resolveCode("in_main", [main])?.definitions.first?.title == "Main.")
        let d = resolveCode("only_in_worktree", [main])?.definitions.first
        #expect(d?.title == "WT only.")
        #expect(d?.repo == "nib · feat")
    }

    @Test func theResolverPrefersGlossaryUnlessTheTextLooksLikeCode() throws {
        let r = try makeCodeRepo("g", [
            "glossary.md": "- **settle_up** — what we call the final payout\n- **spine** — the stem of a letter\n",
            "a.py": "def settle_up():\n    \"\"\"Code.\"\"\"\n\ndef spine():\n    \"\"\"Code too.\"\"\"\n",
        ])
        let resolver = Resolver(index: RefIndex.build(repos: [r]))
        CodeRefs.FileListCache.shared.clear()
        // No code shape (a plain word): the glossary term wins.
        #expect(resolver.resolve("spine", preferredRepo: "g").definitions.first?.rule == .term)
        // Code shape (`_`, `()` or backticks): the symbol wins.
        #expect(resolver.resolve("settle_up", preferredRepo: "g").definitions.first?.rule == .symbol)
        #expect(resolver.resolve("spine()", preferredRepo: "g").definitions.first?.rule == .symbol)
        #expect(resolver.resolve("`spine`", preferredRepo: "g").definitions.first?.rule == .symbol)
    }

    @Test func idsAndRepoReferencesComeFirst() throws {
        let r = try makeCodeRepo("p", [
            "docs/decisions.md": "## D1 — Use SQLite\nBecause.\n",
            "a.py": "def D1():\n    pass\n",
            "main.py": "x = 1\n",
        ])
        let resolver = Resolver(index: RefIndex.build(repos: [r]))
        #expect(resolver.resolve("D1", preferredRepo: "p").definitions.first?.rule == .heading)
        #expect(resolver.resolve("main.py", preferredRepo: "p").definitions.first?.rule == .file)
    }
}
