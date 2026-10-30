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
}
