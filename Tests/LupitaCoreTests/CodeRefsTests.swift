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
    CodeRefs.FileListCache.shared.clear(); CodeRefs.TableCache.shared.clear()
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
        CodeRefs.FileListCache.shared.clear(); CodeRefs.TableCache.shared.clear()
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

@Suite(.serialized) struct AddressTests {
    let repo: Repo
    let parent: URL

    init() throws {
        parent = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-addr-\(UUID().uuidString)")
        repo = try makeCodeRepo("atlas", [
            "index.html": "<html></html>",
            "viewer/mesa.html": "<html></html>",
            ".claude/launch.json": "",
        ], in: parent)
        let config = """
        {"version": "0.0.1", "configurations": [
          {"name": "atlas-ui", "runtimeExecutable": "python3", "runtimeArgs": ["\(repo.path)/serve.py"], "port": 8130},
          {"name": "docs", "url": "http://localhost:8090", "runtimeExecutable": "npx"}
        ]}
        """
        try config.write(toFile: repo.path + "/.claude/launch.json", atomically: true, encoding: .utf8)
    }

    func resolve(_ text: String, listener: CodeRefs.Addresses.Listener? = nil, repos: [Repo]? = nil) -> Definition? {
        CodeRefs.Addresses.listener = { _ in listener }
        defer { CodeRefs.Addresses.listener = CodeRefs.Addresses.lsofListener }
        CodeRefs.FileListCache.shared.clear(); CodeRefs.TableCache.shared.clear()
        return CodeRefs.resolve(text, repos: repos ?? [repo], preferredRepo: "atlas")?.definitions.first
    }

    @Test func offAddressShowsTheRepoThatDeclaresIt() {
        let d = resolve("localhost:8130")
        #expect(d?.rule == .address)
        #expect(d?.repo == "atlas")
        #expect(d?.title.contains("atlas-ui") == true)
        #expect(d?.summary.contains("pid") == false)  // not running
        #expect(d?.path == "index.html")
    }

    @Test func theRouteIsThePageAndIsFoundInTheRepo() {
        let d = resolve("http://127.0.0.1:8130/mesa.html?skin=b")
        #expect(d?.summary.contains("/mesa.html") == true)
        #expect(d?.summary.contains("pid") == false)
        #expect(d?.path == "viewer/mesa.html")
        #expect(resolve("http://localhost:8130/missing.html")?.path == ".claude/launch.json")
    }

    @Test func aRunningProcessIsReported() {
        let live = CodeRefs.Addresses.Listener(pid: 4242, command: "python3", cwd: repo.path)
        let d = resolve("`localhost:8130`.", listener: live)
        #expect(d?.summary.contains("pid 4242") == true)
        #expect(d?.repo == "atlas")
    }

    @Test func theProcessFolderBeatsTheDeclaringRepo() throws {
        let other = try makeCodeRepo("other", ["app.js": "x"], in: parent)
        let live = CodeRefs.Addresses.Listener(pid: 7, command: "node", cwd: other.path + "/")
        let d = resolve("localhost:8130", listener: live, repos: [repo, other])
        #expect(d?.repo == "other")
        let none = resolve("localhost:9999", listener: live, repos: [repo, other])
        #expect(none?.title.contains("node") == true)
        #expect(none?.repo == "other")
    }

    @Test func aLaunchCommandNamingAWorktreeNamesTheWorktree() throws {
        let wt = parent.appendingPathComponent("atlas-worktrees/qa")
        try FileManager.default.createDirectory(at: wt, withIntermediateDirectories: true)
        try "gitdir: x".write(to: wt.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        let admin = URL(fileURLWithPath: repo.path + "/.git/worktrees/qa")
        try FileManager.default.createDirectory(at: admin, withIntermediateDirectories: true)
        try (RepoDiscovery.realPath(wt.path) + "/.git\n").write(to: admin.appendingPathComponent("gitdir"), atomically: true, encoding: .utf8)
        let json = #"{"configurations": [{"name": "qa-ui", "runtimeArgs": ["\#(RepoDiscovery.realPath(wt.path))/serve.py"], "port": 8140}]}"#
        try json.write(toFile: repo.path + "/.claude/launch.json", atomically: true, encoding: .utf8)
        #expect(resolve("localhost:8140")?.repo == "atlas · qa")
    }

    @Test func unknownAndOffAddressesSaySo() {
        let d = resolve("localhost:5555")
        #expect(d?.repo == "")
        #expect(d?.summary.contains("pid") == false)
    }

    @Test func urlsInTheDocsConfigAreRead() {
        #expect(resolve("localhost:8090")?.title.contains("docs") == true)
    }

    @Test func notAddresses() {
        #expect(resolve("localhost") == nil)
        #expect(resolve("example.com:8080") == nil)
        #expect(resolve("localhost:8130abc") == nil)
    }

    @Test func theResolverAnswersAddressesBeforeRepoReferences() {
        CodeRefs.Addresses.listener = { _ in nil }
        defer { CodeRefs.Addresses.listener = CodeRefs.Addresses.lsofListener }
        var index = RefIndex()
        index.repos = [repo]
        let r = Resolver(index: index).resolve("http://127.0.0.1:8130/mesa.html", preferredRepo: "atlas")
        #expect(r.definitions.first?.rule == .address)
    }
}

@Suite(.serialized) struct TokenTests {
    let repo: Repo

    init() throws {
        repo = try makeCodeRepo("site", [
            "src/styles/tokens.css": """
            /* Palette */
            :root {
              --brand: #0E5400;
              --accent: var(--brand);
              --ink: rgb(10, 20, 30);
              --muted: hsl(0, 0%, 50%);
              --space: 8px;
              --shadow-card: 0 1px 2px rgba(0,0,0,.2);
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --brand: #6BFF3F;
                --ink: #F5F5F5;
              }
            }
            """,
            "src/theme.scss": """
            :root { --solo: #123ABC; }
            [data-theme="dark"] { --solo: #FEDCBA; --only-dark: #111; }
            // line comment with --not-a-token: red;
            """,
            "src/Button.astro": "---\nconst x = {a: 1};\n---\n<style>\n  .b { --btn-bg: var(--accent); background: var(--btn-bg); }\n</style>\n",
            "node_modules/pkg/x.css": ":root { --hidden: #000000; }",
        ])
    }

    func first(_ text: String) -> Definition? {
        CodeRefs.FileListCache.shared.clear(); CodeRefs.TableCache.shared.clear()
        return CodeRefs.resolve(text, repos: [repo], preferredRepo: "site")?.definitions.first
    }

    @Test func aTokenShowsItsValueSwatchAndPlace() {
        let d = first("--brand")
        #expect(d?.rule == .token)
        #expect(d?.path == "src/styles/tokens.css")
        #expect(d?.line == 3)
        #expect(d?.title.contains("#0E5400") == true)
    }

    @Test func darkAndLightValuesAreBothShown() {
        let d = first("--brand")
        #expect(d?.title.contains("#6BFF3F") == true)
        #expect(d?.colors?.map(\.hex) == ["#0E5400", "#6BFF3F"])
        #expect(d?.colors?.map(\.label) == [S.light, S.dark])
        let solo = first("--solo")
        #expect(solo?.colors?.map(\.hex) == ["#123ABC", "#FEDCBA"])
        #expect(first("--only-dark")?.colors?.map(\.hex) == ["#111111"])
    }

    @Test func varChainsAreFollowedPerTheme() {
        let d = first("var(--accent)")
        #expect(d?.colors?.map(\.hex) == ["#0E5400", "#6BFF3F"])
        #expect(d?.summary.contains("var(--brand)") == true)
        let deep = first("--btn-bg")
        #expect(deep?.colors?.first?.hex == "#0E5400")
        #expect(deep?.path == "src/Button.astro")
    }

    @Test func fallbacksAndFunctionColours() {
        #expect(first("var(--ink, red)")?.colors?.first?.hex == "#0A141E")
        #expect(first("--muted")?.colors?.first?.hex == "#808080")
        let space = first("--space")
        #expect(space?.title == "8px")
        #expect(space?.colors == nil)
        #expect(first("--shadow-card")?.colors == nil)
    }

    @Test func unknownTokensAndFlagsAreNotAnswered() {
        #expect(first("--repo") == nil)
        #expect(first("--hidden") == nil)
        #expect(first("--not-a-token") == nil)
    }

    @Test func aHexColourShowsASwatchAndTheTokensThatDefineIt() {
        let d = first("#0e5400")
        #expect(d?.rule == .color)
        #expect(d?.id == "#0E5400")
        #expect(d?.title == "rgb(14, 84, 0)")
        #expect(d?.colors?.map(\.hex) == ["#0E5400"])
        #expect(d?.summary.contains("--brand") == true)
        #expect(d?.summary.contains("--accent") == true)
        #expect(d?.path == "src/styles/tokens.css")
    }

    @Test func shortHexAndColoursNoTokenUses() {
        let d = first("#abc")
        #expect(d?.id == "#AABBCC")
        #expect(d?.path == "")
        #expect(first("#12")?.rule != .color)  // two digits are a PR number at most
        #expect(first("#GGGGGG") == nil)
        // A short hex is expanded before comparing: `--only-dark: #111` is #111111.
        #expect(first("#111111")?.summary.contains("--only-dark") == true)
    }

    @Test func allDigitHexIsLeftToPullRequests() {
        // `#333` could be a PR number: the PR type decides (see PullRequestTests).
        #expect(first("#333") == nil || first("#333")?.rule != .token)
    }

    @Test func colourParsing() {
        #expect(CodeRefs.Tokens.color(of: "rgb(255 0 0 / 50%)") == "#FF000080")
        #expect(CodeRefs.Tokens.color(of: "rgba(0,128,255,1)") == "#0080FF")
        #expect(CodeRefs.Tokens.color(of: "hsl(120, 100%, 25%)") == "#007F00" || CodeRefs.Tokens.color(of: "hsl(120, 100%, 25%)") == "#008000")
        #expect(CodeRefs.Tokens.color(of: "#fff") == "#FFFFFF")
        #expect(CodeRefs.Tokens.color(of: "1rem") == nil)
    }
}

@Suite struct BareHSLTests {
    @Test func shadcnComponentsAreAColour() {
        #expect(CodeRefs.Tokens.color(of: "0 0% 100%") == "#FFFFFF")
        #expect(CodeRefs.Tokens.color(of: "240 4.8% 95.9%") != nil)
        #expect(CodeRefs.Tokens.color(of: "10 20 30") == nil)
    }
}

@Suite(.serialized) struct CommandTests {
    let repo: Repo
    let other: Repo

    init() throws {
        repo = try makeCodeRepo("web", [
            "package.json": """
            {
              "name": "web",
              "scripts": {
                "dev": "next dev",
                "build": "next build",
                "test:e2e": "playwright test"
              }
            }
            """,
            "apps/admin/package.json": #"{"scripts": {"lint": "eslint ."}}"#,
        ])
        other = try makeCodeRepo("api", ["package.json": #"{"scripts": {"build": "tsc", "serve": "node dist/index.js"}}"#])
    }

    func first(_ text: String, window: String? = "web") -> Definition? {
        CodeRefs.resolve(text, repos: [repo, other], preferredRepo: window)?.definitions.first
    }

    @Test func npmRunReadsThePackageJson() {
        let d = first("npm run build")
        #expect(d?.rule == .terminal)
        #expect(d?.id == "npm run build")
        #expect(d?.title.contains("next build") == true)
        #expect(d?.repo == "web")
        #expect(d?.path == "package.json")
        #expect(d?.line == 5)
        #expect(first("`npm run test:e2e`")?.title.contains("playwright test") == true)
    }

    @Test func shortFormsOfOtherManagers() {
        #expect(first("pnpm dev")?.title.contains("next dev") == true)
        #expect(first("yarn build")?.title.contains("next build") == true)
        #expect(first("pnpm run dev")?.title.contains("next dev") == true)
        #expect(first("bun run build")?.title.contains("next build") == true)
    }

    @Test func nestedPackagesAreSearched() {
        #expect(first("npm run lint")?.path == "apps/admin/package.json")
    }

    @Test func theWindowsRepoComesFirstAndOthersAreFlagged() {
        #expect(first("npm run build", window: "api")?.title.contains("tsc") == true)
        let r = CodeRefs.resolve("npm run serve", repos: [repo, other], preferredRepo: "web")
        #expect(r?.definitions.first?.repo == "api")
        #expect(r?.fromOtherRepo == true)
    }

    @Test func builtInPackageCommandsComeFromTheDictionary() {
        let d = first("npm ci")
        #expect(d?.rule == .terminal)
        #expect(d?.repo == "")
        #expect(d?.title.isEmpty == false)
        #expect(first("npm audit") != nil)
        #expect(first("pnpm install")?.id == "pnpm install")
        #expect(first("npm run nonexistent")?.repo == "")  // falls back to what `run` means
    }

    @Test func gitCommandsHaveOneLineAndWarnAboutDangerousFlags() {
        #expect(first("git status")?.title.isEmpty == false)
        #expect(first("git checkout main/master/staging")?.id == "git checkout main/master/staging" || first("git checkout main/master/staging")?.id.hasPrefix("git checkout") == true)
        #expect(first("git add -A")?.summary.contains("-A") == true)
        #expect(first("git reset --hard")?.summary.contains("--hard") == true)
        #expect(first("git push --force")?.summary.contains("--force") == true)
        #expect(first("git merge feature/a-open-bowl")?.rule == .terminal)
        #expect(first("git") != nil)
        #expect(first("git frobnicate")?.title.isEmpty == false)  // unknown subcommand: git itself
    }

    @Test func shellCommands() {
        #expect(first("cd Lupita")?.title.isEmpty == false)
        #expect(first("rm -rf build")?.summary.contains("-rf") == true)
        #expect(first("brew install ffmpeg")?.title.isEmpty == false)
        #expect(first("$ python3 serve.py")?.id == "python3 serve.py")
    }

    @Test func commonEnglishWordsAreCommandsOnlyBetweenBackticks() {
        #expect(first("make sure") == nil)
        #expect(first("open the file") == nil)
        #expect(first("find the bug") == nil)
        #expect(first("`make build`")?.rule == .terminal)
        #expect(first("`open file.txt`")?.rule == .terminal)
        #expect(first("node --check") == nil)
        #expect(first("`node --check`")?.rule == .terminal)
    }

    @Test func notCommands() {
        #expect(first("hello world") == nil)
        #expect(first("scripts/test.sh") == nil)
        #expect(first("1 2 3 4 5 6 7 8 9") == nil)
    }

    @Test func spanishTextWhenTheMacIsInSpanish() {
        let saved = S.language
        defer { S.language = saved }
        S.language = "es-ES"
        #expect(first("git status")?.title.hasPrefix("Muestra") == true)
        S.language = "en-GB"
        #expect(first("git status")?.title.hasPrefix("Shows") == true)
    }

    @Test func resolverSendsMultiWordCommandsToCodeBeforeRepoReferences() {
        var index = RefIndex()
        index.repos = [repo]
        let r = Resolver(index: index).resolve("git checkout feature/search", preferredRepo: "web")
        #expect(r.definitions.first?.rule == .terminal)
    }
}

@Suite struct ErrorTagTests {
    func first(_ text: String) -> Definition? { CodeRefs.resolve(text, repos: [], preferredRepo: nil)?.definitions.first }
    func with(_ text: String, before: String) -> Definition? {
        CodeRefs.resolve(text, repos: [], preferredRepo: nil, before: before)?.definitions.first
    }

    @Test func errorNamesGetOneLine() {
        for name in ["ENOENT", "TypeError", "KeyError", "AbortError", "NotAllowedError", "MODULE_NOT_FOUND", "EADDRINUSE"] {
            let d = first(name)
            #expect(d?.rule == .error, "\(name)")
            #expect(d?.title.isEmpty == false, "\(name)")
            #expect(d?.absolutePath == "")
        }
        #expect(first("`ENOENT`,")?.id == "ENOENT")
        #expect(first("typeerror") == nil)
        #expect(first("ValidationError") == nil)
    }

    @Test func htmlTagsNeedTheirAngleBrackets() {
        let d = first("<dialog>")
        #expect(d?.rule == .tag)
        #expect(d?.id == "<dialog>")
        #expect(first("`<section>`")?.rule == .tag)
        #expect(first("</div>")?.rule == .tag)
        #expect(first("<meta charset>")?.rule == .tag)
        #expect(first("<img src=\"a.png\" />")?.rule == .tag)
        #expect(first("<br/>")?.rule == .tag)
        #expect(first("dialog") == nil)
        #expect(first("<Button>") == nil)
        #expect(first("<notatag>") == nil)
    }

    @Test func httpStatusNeedsAHint() {
        #expect(first("401") == nil)
        #expect(first("HTTP 401")?.rule == .error)
        #expect(first("401 Unauthorized")?.rule == .error)
        #expect(first("`404`")?.id == "404")
        #expect(first("status 503")?.rule == .error)
        #expect(with("401", before: "the API returns ")?.rule == .error)
        #expect(with("401", before: "chapter ") == nil)
        #expect(first("HTTP 999") == nil)
        #expect(first("404 Banana") == nil)
    }

    @Test func spanishDictionary() {
        let saved = S.language
        defer { S.language = saved }
        S.language = "es-ES"
        #expect(first("ENOENT")?.title.hasPrefix("No existe") == true)
        S.language = "en-GB"
        #expect(first("ENOENT")?.title.hasPrefix("No such") == true)
    }
}

@Suite(.serialized) struct PullRequestTests {
    let repo: Repo
    let bare: Repo

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-pr-\(UUID().uuidString)")
        repo = try makeCodeRepo("shop", ["a.txt": "a\n"], in: base)
        bare = try makeCodeRepo("empty", ["a.txt": "a\n"], in: base)
        guard Git.executable != nil else { return }
        try FileManager.default.removeItem(atPath: repo.path + "/.git")
        try FileManager.default.removeItem(atPath: bare.path + "/.git")
        func git(_ repo: Repo, _ args: String...) { _ = Git.output(repo.path, ["-c", "user.name=T", "-c", "user.email=t@example.com"] + args) }
        git(repo, "init", "-q", "-b", "main")
        git(repo, "add", "."); git(repo, "commit", "-q", "-m", "first")
        git(repo, "checkout", "-q", "-b", "feature/search")
        try "b\n".write(toFile: repo.path + "/b.txt", atomically: true, encoding: .utf8)
        git(repo, "add", "."); git(repo, "commit", "-q", "-m", "wip search")
        git(repo, "checkout", "-q", "main")
        git(repo, "merge", "-q", "--no-ff", "feature/search", "-m", "Merge pull request #12 from owner/feature/search", "-m", "Add the search box")
        try "c\n".write(toFile: repo.path + "/c.txt", atomically: true, encoding: .utf8)
        git(repo, "add", "."); git(repo, "commit", "-q", "-m", "Fix the typo in checkout (#34)")
        try "d\n".write(toFile: repo.path + "/d.txt", atomically: true, encoding: .utf8)
        git(repo, "add", "."); git(repo, "commit", "-q", "-m", "Mentions (#56) in the middle of a line")
        git(bare, "init", "-q", "-b", "main")
    }

    func first(_ text: String, window: String? = "shop") -> Definition? {
        CodeRefs.resolve(text, repos: [repo, bare], preferredRepo: window)?.definitions.first
    }

    @Test func aMergeCommitGivesTheTitleFromItsBody() throws {
        try #require(Git.executable != nil)
        let d = first("#12")
        #expect(d?.rule == .pullRequest)
        #expect(d?.title == "Add the search box")
        #expect(d?.summary.contains("owner/feature/search") == true)
        #expect(d?.summary.isEmpty == false)
        #expect(d?.repo == "shop")
    }

    @Test func aSquashCommitGivesItsSubject() throws {
        try #require(Git.executable != nil)
        #expect(first("#34")?.title == "Fix the typo in checkout")
    }

    @Test func allThreeSpellings() throws {
        try #require(Git.executable != nil)
        for form in ["#12", "PR 12", "PR #12", "pr #12", "`#12`", "(#12)."] {
            #expect(first(form)?.title == "Add the search box", "\(form)")
        }
    }

    @Test func aMentionInTheMiddleOfAMessageIsNotTheMerge() throws {
        try #require(Git.executable != nil)
        #expect(first("PR 56")?.title == S.prNotInHistory)
    }

    @Test func missingPRsSayTheyAreNotInTheLocalHistory() throws {
        try #require(Git.executable != nil)
        let d = first("PR 999")
        #expect(d?.title == S.prNotInHistory)
        #expect(d?.rule == .pullRequest)
        #expect(d?.absolutePath == "")
        #expect(first("#34", window: "empty")?.title == S.prNotInHistory)
    }

    @Test func withoutAWindowAllRepsAreSearched() throws {
        try #require(Git.executable != nil)
        #expect(first("#34", window: nil)?.title == "Fix the typo in checkout")
    }

    @Test func threeDigitNumbersFallBackToColours() throws {
        try #require(Git.executable != nil)
        let d = first("#333")
        #expect(d?.rule == .color)
        #expect(d?.id == "#333333")
        #expect(first("#12")?.rule == .pullRequest)
        // An explicit PR is never a colour.
        #expect(first("PR 333")?.rule == .pullRequest)
    }

    @Test func notPullRequests() {
        #expect(first("12") == nil)
        #expect(first("#") == nil)
        #expect(first("PR") == nil)
        #expect(first("#1234567") == nil)
    }
}

@Suite(.serialized) struct CodePickerTests {
    let repo: Repo
    let resolver: Resolver

    init() throws {
        repo = try makeCodeRepo("atlas", [
            "a.py": "def slider(x):\n    \"\"\"Moves it.\"\"\"\n\ndef plain_thing():\n    pass\n",
            "package.json": "{\"scripts\": {\"build\": \"tsc\"}}",
        ])
        var index = RefIndex()
        index.repos = [repo]
        resolver = Resolver(index: index)
    }

    func pick(_ line: String, at word: String) -> Resolution? {
        CodeRefs.FileListCache.shared.clear()
        let offset = (line as NSString).range(of: word).location + 1
        return CandidatePicker.pick(line: line, cursorOffset: offset, resolver: resolver, preferredRepo: "atlas")
    }

    @Test func aCalledWordIsASymbolEvenThoughTheParenthesesAreSplitOff() {
        #expect(pick("then call slider() once", at: "slider")?.definitions.first?.rule == .symbol)
        #expect(pick("then pick the slider once", at: "slider")?.definitions.isEmpty == true)
        #expect(pick("then pick `slider` once", at: "slider")?.definitions.first?.rule == .symbol)
    }

    @Test func snakeCaseNeedsNoMarks() {
        #expect(pick("the plain_thing helper", at: "plain_thing")?.definitions.first?.title == "")
    }

    @Test func pointingAtAnyWordOfACommandFindsIt() {
        let line = "first run npm run build and then"
        for word in ["npm", "build"] {
            let r = pick(line, at: word)
            #expect(r?.definitions.first?.rule == .terminal, "\(word)")
        }
        #expect(pick(line, at: "first")?.definitions.isEmpty == true)
    }

    @Test func prNumbersWithAndWithoutTheWord() {
        #expect(pick("merged in PR 999 yesterday", at: "PR")?.definitions.first?.rule == .pullRequest)
        #expect(pick("merged in PR 999 yesterday", at: "999")?.definitions.first?.rule == .pullRequest)
        #expect(pick("merged in PR #999 yesterday", at: "#999")?.definitions.first?.rule == .pullRequest)
    }
}
