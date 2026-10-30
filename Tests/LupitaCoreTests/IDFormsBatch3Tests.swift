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

    @Test func aBareNumberOutsideAListIsNotAnId() {
        let r = Self.resolver(["docs/pu.md": "- **PU-03**: Third item"])
        #expect(r.resolve("03", preferredRepo: "r", context: "chapter ", fromPath: "docs/a.md").definitions.isEmpty)
        #expect(r.resolve("03", preferredRepo: "r", context: nil, fromPath: "docs/a.md").definitions.isEmpty)
    }
}
