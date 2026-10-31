import Foundation
import Testing
@testable import LupitaCore

// Batch 3 of the ID forms: ADR files by number, lists with an omitted prefix, bold properties and tracker keys.
@Suite struct IDFormsBatch3Tests {
    static func resolver(_ files: [String: String], repo: String = "r") -> Resolver {
        var index = RefIndex()
        for (path, text) in files.sorted(by: { $0.key < $1.key }) {
            index.add(text: text, fileName: (path as NSString).lastPathComponent, repo: repo, relativePath: path, absolutePath: "/\(repo)/" + path)
        }
        index.rank()
        return Resolver(index: index)
    }

    static func shown(_ resolver: Resolver, _ text: String, from path: String?, repo: String = "r") -> [Definition] {
        guard let id = IDGrammar.parse(text) else { return [] }
        return resolver.shownDefinitions(for: id, preferredRepo: repo, fromPath: path)
    }

    static func keys(_ text: String) -> [String] { IDGrammar.tokens(in: text).map(\.id.key) }

    // MARK: R3, ADR by the number of its file

    @Test func adrFileDefinesTheAdrOfItsNumber() {
        let r = Self.resolver(["docs/adr/0007-use-foo.md": "# Use foo\n\nWe use foo.", "docs/readme.md": "See ADR-0007."])
        for cite in ["ADR-0007", "ADR007", "ADR7", "ADR 7"] {
            let defs = Self.shown(r, cite, from: "docs/readme.md")
            #expect(defs.first?.path == "docs/adr/0007-use-foo.md", "\(cite)")
        }
    }

    @Test func adrFileMayCarryItsPrefixAndLiveInArchitectureDecisions() {
        let r = Self.resolver(["docs/architecture-decisions/adr007-use-msw.md": "# MSW", "docs/readme.md": "ADR-007"])
        #expect(Self.shown(r, "ADR-007", from: "docs/readme.md").first?.path == "docs/architecture-decisions/adr007-use-msw.md")
    }

    @Test func adrCiteIsReadWithASpace() {
        #expect(Self.keys("see ADR 7, ADR-0007 and ADR007.") == ["ADR7", "ADR0007", "ADR007"])
        #expect(Self.keys("ADR 7a and ADR 12345 and the ADR 7.1 line").isEmpty)
    }

    @Test func adrFileNameIsReadAsTheAdr() {
        #expect(Self.keys("[use foo](0007-use-foo.md) and docs/adr/0008-bar.md") == ["ADR0007", "ADR0008"])
        let r = Self.resolver(["docs/adr/0007-use-foo.md": "# Use foo", "docs/adr/README.md": "[x](0007-use-foo.md)"])
        let id = IDGrammar.tokens(in: "[x](0007-use-foo.md)").first!.id
        #expect(r.shownDefinitions(for: id, preferredRepo: "r", fromPath: "docs/adr/README.md").first?.path == "docs/adr/0007-use-foo.md")
    }

    @Test func numberedFileOutsideAdrFoldersDefinesNothing() {
        let r = Self.resolver(["docs/notes/0007-use-foo.md": "# Use foo", "docs/readme.md": "ADR-0007"])
        #expect(Self.shown(r, "ADR-0007", from: "docs/readme.md").isEmpty)
        #expect(DefinitionRules.definitions(fileName: "0007-use-foo.md", lines: [], folder: "migrations").isEmpty)
    }

    @Test func adrOfAnotherNumberIsNotShown() {
        let r = Self.resolver(["docs/adr/0007-use-foo.md": "# Use foo"])
        #expect(Self.shown(r, "ADR-0008", from: "docs/readme.md").isEmpty)
        #expect(Self.shown(r, "ADR-0070", from: "docs/readme.md").isEmpty)
    }

    @Test func headingOfTheAdrBeatsItsFileName() {
        let r = Self.resolver(["adr/0007-use-foo.md": "# ADR-0007: Use foo please\n"])
        let defs = Self.shown(r, "ADR-0007", from: "adr/0007-use-foo.md")
        #expect(defs.first?.rule == .heading)
        #expect(defs.contains { $0.rule == .fileName })
    }

    @Test func wordFormsOfAdrKeepTheirOldKeys() {
        #expect(Self.keys("ADR-004") == ["ADR004"])
        #expect(IDGrammar.parse("ADR-004")?.scope == IDScope.none)
    }

    // MARK: R14, a list that omits the prefix

    @Test func listNumbersInheritThePrefixOfTheFirstId() {
        #expect(Self.keys("PU-02, 03 y 26 are done") == ["PU02", "PU03", "PU26"])
        #expect(Self.keys("see FR-004/006 and T012 & 013, and 014") == ["FR004", "FR006", "T012", "T013", "T014"])
        #expect(Self.keys("D001 and 002") == ["D001", "D002"])
        let inherited = IDGrammar.tokens(in: "PU-02, 03").last!
        #expect(inherited.id.scope == .folder && inherited.id.display == "03")
        #expect(inherited.range == NSRange(location: 7, length: 2))
    }

    @Test func listNumbersNeedTheSameWidthAndASeparator() {
        #expect(Self.keys("PU-02, 3 and 100") == ["PU02"])
        #expect(Self.keys("PU-02 03") == ["PU02"])
        #expect(Self.keys("PU-02, 03.5") == ["PU02"])
        #expect(Self.keys("PU-02, 03-A") == ["PU02"])
        #expect(Self.keys("FR-004, 006a") == ["FR004"])
        #expect(Self.keys("FR-004a, 005") == ["FR004a"])
        #expect(Self.keys("US1/AC2") == ["US1", "AC2"])
    }

    @Test func lineNumbersAndLoosePairsAreNotLists() {
        #expect(Self.keys("see L120, 121 and lines D120, 121") == ["L120", "D120"])
        #expect(Self.keys("C5, 1") == ["C5"])
        #expect(Self.keys("C5, 6") == ["C5"])
        #expect(Self.keys("C5, 6 and 7") == ["C5", "C6", "C7"])
        #expect(Self.keys("L043, 044") == ["L043", "L044"])
    }

    @Test func inheritedIdIsShownOnlyWhereItIsDefinedInTheFolderOrAbove() {
        let r = Self.resolver([
            "docs/pu.md": "- **PU-03**: Third item\n- **PU-26**: Last item",
            "docs/plan/notes.md": "PU-02, 03 y 26",
            "docs/plan/pu.md": "- **PU-26**: Nearest 26",
            "other/pu.md": "- **PU-26**: Sibling 26",
        ])
        let at = "docs/plan/notes.md"
        #expect(r.resolve("03", preferredRepo: "r", context: "PU-02, ", fromPath: at).definitions.first?.path == "docs/pu.md")
        #expect(r.resolve("26", preferredRepo: "r", context: "PU-02, 03 y", fromPath: at).definitions.first?.path == "docs/plan/pu.md")
        // `PU-02` is not defined anywhere: the cited numbers 03 and 26 are, 04 is not.
        #expect(r.resolve("04", preferredRepo: "r", context: "PU-02, 03 y 26, ", fromPath: at).definitions.isEmpty)
        // A definition in a sibling folder is no definition.
        #expect(r.resolve("26", preferredRepo: "r", context: "PU-02, 03 y", fromPath: "elsewhere/notes.md").definitions.isEmpty)
    }

    @Test func aListBrokenAcrossLinesStillInheritsThePrefix() {
        let r = Self.resolver(["docs/fr.md": "- **FR-002**: Second\n- **FR-003**: Third"])
        let block = "see FR-\n001, 002, 003 for details"
        #expect(r.resolve("002", preferredRepo: "r", context: "001,", fromPath: "docs/a.md", block: block).definitions.first?.path == "docs/fr.md")
        #expect(r.resolve("003", preferredRepo: "r", context: "001, 002,", fromPath: "docs/a.md", block: block).definitions.first?.path == "docs/fr.md")
        #expect(r.resolve("003", preferredRepo: "r", context: "", fromPath: "docs/a.md", block: "total 003 items").definitions.isEmpty)
    }

    @Test func aBareNumberIsNeverOfferedAsAMisreadId() {
        let r = Self.resolver(["a.md": "## D02 — Second\n\n## DD2 — Other\n\n## D2 — Third"])
        for number in ["002", "02", "2"] {
            #expect(r.resolve(number, preferredRepo: "r", context: "see ", fromPath: "b.md").definitions.isEmpty, "\(number)")
        }
        // A real misreading still works: a letter read as a zero.
        #expect(!r.resolve("D0Z", preferredRepo: "r").definitions.isEmpty)
    }

    @Test func aBareNumberOutsideAListIsNotAnId() {
        let r = Self.resolver(["docs/pu.md": "- **PU-03**: Third item"])
        #expect(r.resolve("03", preferredRepo: "r", context: "chapter ", fromPath: "docs/a.md").definitions.isEmpty)
        #expect(r.resolve("03", preferredRepo: "r", context: nil, fromPath: "docs/a.md").definitions.isEmpty)
    }

    // MARK: Property N in bold

    @Test func boldPropertyWithATitleDefinesTheProperty() {
        let r = Self.resolver([
            "specs/a/design.md": "# Design\n\n**Property 1: Nesting token count**\n\nFor any input, it holds.",
            "specs/a/tasks.md": "- [ ] 1.1 Write the test\n  - **Property 1: Cited, not defined**",
            "specs/a/requirements.md": "Validates Property 1.",
        ])
        let defs = Self.shown(r, "Property 1", from: "specs/a/requirements.md")
        #expect(defs.map(\.path) == ["specs/a/design.md"])
        #expect(defs.first?.title == "Nesting token count")
        #expect(defs.first?.line == 3)
    }

    @Test func boldPropertyWithoutATitleOrInTheMiddleOfAnythingIsNotADefinition() {
        for text in ["**Property 1**", "**Property 1:**", "see **Property 1: Title** here", "- **Property 1: Title**", "  **Property 1: Title**",
                     "**Property one: Title**", "**Property 1.2: Title**", "Property 1: Title"] {
            #expect(DefinitionRules.lineDefinition(text) == nil, "\(text)")
        }
        #expect(DefinitionRules.lineDefinition("**Property 12: A title.** For any x")?.id.key == "PROPERTY 12")
    }

    @Test func boldPropertyIsScopedByFolder() {
        let r = Self.resolver([
            "specs/a/design.md": "**Property 1: Of spec a**",
            "specs/b/design.md": "**Property 1: Of spec b**",
            "specs/b/requirements.md": "Property 1",
            "specs/c/requirements.md": "Property 1",
        ])
        #expect(Self.shown(r, "Property 1", from: "specs/b/requirements.md").map(\.path) == ["specs/b/design.md"])
        #expect(Self.shown(r, "Property 1", from: "specs/c/requirements.md").isEmpty)
    }

    @Test func headingPropertyStillBeatsTheBoldOne() {
        let r = Self.resolver(["a/design.md": "### Property 1: From heading\n\n**Property 1: From bold**"])
        #expect(Self.shown(r, "Property 1", from: "a/design.md").first?.title == "From heading")
    }

    // MARK: R4, tracker keys

    @Test func trackerKeysLongerThanThePrefixGrammarAreRecognised() {
        #expect(Self.keys("fixes PLAT-443341 and ACME-527, see LONGPREFIX-1234") == ["PLAT443341", "ACME527", "LONGPREFIX1234"])
        #expect(Self.keys("(PLAT-443341)") == ["PLAT443341"])
        #expect(IDGrammar.parse("PLAT-443341")?.display == "PLAT-443341")
    }

    @Test func datesVersionsPercentsAndPrefixesWithDigitsAreNotKeys() {
        // What the prefix grammar already read stays as it was (`CVE-2024`, `R1`); the new shapes leave these alone.
        #expect(Self.keys("ABCDEF-2026-10-20 and LICENSE-2.0 and 50%PLATFORM-4433 and 100%-PLATFORM-1234").isEmpty)
        #expect(Self.keys("plat-4433 and PLAT-1234567 and PLATFORM-4433-b and PLATFORM-44.3").isEmpty)
        #expect(Self.keys("S3-12345") == ["S3"])
        #expect(Self.keys("GPT-40000 and SHA-256000 and ISO-8601000 and HTTP-200000").isEmpty)
        #expect(!IDGrammar.isTrackerKey("R1-4") && !IDGrammar.isTrackerKey("PLAT-1234567") && !IDGrammar.isTrackerKey("GPT-4"))
        #expect(IDGrammar.isTrackerKey("PLAT-443341") && IDGrammar.isTrackerKey("AB-1"))
    }

    @Test func aLongWordWithAShortNumberOrAZeroIsALabelNotAKey() {
        #expect(Self.keys("NOTIFY-3 and BLOCKING-4 and ACCEPT-01 and ASSUMPTION-001 and PLAT-0443341").isEmpty)
        #expect(Self.keys("INFRENG-812 and HADOOP-19661 and ACME-52111") == ["INFRENG812", "HADOOP19661", "ACME52111"])
        // The short prefixes were already read before this batch, and still are.
        #expect(Self.keys("DP-1 and FLINK-1") == ["DP1", "FLINK1"])
    }

    @Test func labelsAndPaddedNumbersAreNotLookedUpInGit() {
        #expect(!IDGrammar.isTrackerKey("FR-004") && !IDGrammar.isTrackerKey("ACCEPT-01") && !IDGrammar.isTrackerKey("T-001"))
        #expect(IDGrammar.isTrackerKey("FR-4") && IDGrammar.isTrackerKey("INFRENG-812"))
    }

    @Test func aDatedFileInAnAdrFolderIsNotAnAdr() {
        #expect(DefinitionRules.definitions(fileName: "2026-08-16-learnings.md", lines: [], folder: "adr").isEmpty)
        #expect(DefinitionRules.definitions(fileName: "0007-use-foo.md", lines: [], folder: "adr").count == 1)
    }

    @Test func existingShortFormsKeepTheirKeys() {
        #expect(Self.keys("BUG-01, D23, ADR-004, E2-S3b") == ["BUG01", "D23", "ADR004", "E2-S3b"])
    }
}

@Suite(.serialized) struct TrackerKeyCommitTests {
    let root: URL
    let repo: Repo

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-keys-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("atlas")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "- **ACME-527**: Defined in a file\n".write(to: dir.appendingPathComponent("docs/keys.md"), atomically: true, encoding: .utf8)
        repo = Repo(name: "atlas", path: RepoDiscovery.realPath(dir.path))
        if Git.executable != nil {
            git("init", "-q", "-b", "main")
            git("add", ".")
            git("commit", "-q", "-m", "PLAT-443341: first attempt")
            try "x\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "fix crash on save (PLAT-443341)", "-m", "Body text")
            try "y\n".write(to: dir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "ACME-527 is also in a commit")
            try "z\n".write(to: dir.appendingPathComponent("c.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "mentions PLAT-4433412 only")
            git("branch", "feature/PLAT-99887-new-thing")
        }
    }

    @discardableResult
    func git(_ args: String...) -> String? {
        Git.output(repo.path, ["-c", "user.name=T", "-c", "user.email=t@example.com"] + args)
    }

    func resolver() -> Resolver {
        var index = RefIndex()
        index.repos = [repo]
        index.add(text: "- **ACME-527**: Defined in a file\n", fileName: "keys.md", repo: "atlas", relativePath: "docs/keys.md", absolutePath: repo.path + "/docs/keys.md")
        index.rank()
        return Resolver(index: index)
    }

    @Test func aKeyNoFileDefinesShowsTheLatestCommitThatCitesIt() {
        guard Git.executable != nil else { return }
        let r = resolver().resolve("PLAT-443341", preferredRepo: "atlas")
        #expect(r.definitions.first?.rule == .commit)
        #expect(r.definitions.first?.title == "fix crash on save (PLAT-443341)")
        #expect(r.definitions.first?.summary.contains(" · ") == true)
        #expect(r.definitions.first?.repo == "atlas")
    }

    @Test func aDefinitionInAFileBeatsTheCommit() {
        guard Git.executable != nil else { return }
        let r = resolver().resolve("ACME-527", preferredRepo: "atlas")
        #expect(r.definitions.first?.rule == .listOrColon)
    }

    @Test func aLongerNumberIsAnotherKey() {
        guard Git.executable != nil else { return }
        #expect(resolver().resolve("PLAT-44334", preferredRepo: "atlas").definitions.isEmpty)
        #expect(resolver().resolve("PLAT-44334", preferredRepo: "other").definitions.isEmpty)
    }

    @Test func aKeyCitedOnlyInAnotherRepoIsShownFlagged() {
        guard Git.executable != nil else { return }
        let other = resolver().resolve("PLAT-443341", preferredRepo: "other")
        #expect(other.definitions.first?.rule == .commit && other.fromOtherRepo)
        let none = resolver().resolve("PLAT-443341", preferredRepo: nil)
        #expect(none.definitions.first?.rule == .commit && !none.fromOtherRepo)
    }

    @Test func theHighlightUnderlinesAKeyThatSomeCommitCites() {
        guard Git.executable != nil else { return }
        #expect(HighlightPicker.kind(of: "PLAT-443341,", resolver: resolver(), block: "") == .id)
        #expect(HighlightPicker.kind(of: "PLAT-99999", resolver: resolver(), block: "") == nil)
    }

    @Test func aBranchNamedAfterTheKeyIsShownWhenNoCommitCitesIt() {
        guard Git.executable != nil else { return }
        let r = resolver().resolve("PLAT-99887", preferredRepo: "atlas")
        #expect(r.definitions.first?.rule == .branch)
    }

    @Test func standardsAreNotLookedUpInGit() {
        guard Git.executable != nil else { return }
        #expect(resolver().trackerCommit(for: RefID(display: "GPT-4", key: "GPT4", prefix: "GPT"), preferredRepo: "atlas") == nil)
    }
}
