import Foundation
import Testing
@testable import LupitaCore

// Batch 5, part 1: `§4.7` points at a numbered heading, and the reader's file and folders say which document.
@Suite struct SectionRefsTests {
    static func resolver(_ files: [String: String], repo: String = "r") -> Resolver {
        var index = RefIndex()
        for (path, text) in files.sorted(by: { $0.key < $1.key }) {
            index.add(text: text, fileName: (path as NSString).lastPathComponent, repo: repo, relativePath: path, absolutePath: "/\(repo)/" + path)
        }
        index.rank()
        return Resolver(index: index)
    }

    static func lookup(_ r: Resolver, _ text: String, from path: String?) -> (paths: [String], route: SectionRoute?) {
        let id = IDGrammar.tokens(in: text).first { $0.id.scope == .section }!.id
        let found = r.sectionLookup(for: id, preferredRepo: "r", fromPath: path)
        return (found.defs.map(\.path), found.route)
    }

    static let spec = "# Spec\n\n## 4. Rules\n\n### 4.4 Autonomy\n\nText.\n\n## 5 Output\n"

    @Test func tokensReadTheSectionNumber() {
        let ids = IDGrammar.tokens(in: "see §4.4, § 5 and (§3) but not §A, §4a or § Background").filter { $0.id.scope == .section }
        #expect(ids.map(\.id.key) == ["§4.4", "§5", "§3"])
        #expect(IDGrammar.tokens(in: "x §5#5 y").first?.id.key == "§5")
    }

    @Test func numberedHeadingsDefineSections() {
        let r = Self.resolver(["spec/spec.md": Self.spec])
        #expect(r.index.definitions["§4.4"]?.first?.title == "Autonomy")
        #expect(r.index.definitions["§4"]?.first?.title == "Rules")
        #expect(r.index.definitions["§5"]?.first?.line == 9)
        #expect(r.index.definitions["§2024"] == nil)
    }

    @Test func aHeadingInsideFencedCodeDefinesNothing() {
        let r = Self.resolver(["a.md": "```\n## 4.4 Template\n```\n"])
        #expect(r.index.definitions["§4.4"] == nil)
    }

    // Path (a): the sentence names the document.
    @Test func theNamedDocumentWins() {
        let r = Self.resolver(["spec/spec.md": Self.spec, "docs/other.md": "## 4.4 Else\n", "notes/n.md": "spec §4.4"])
        let got = Self.lookup(r, "spec §4.4", from: "notes/n.md")
        #expect(got.paths == ["spec/spec.md"] && got.route == .named)
        #expect(Self.lookup(r, "§4.4 of other", from: "notes/n.md").paths == ["docs/other.md"])
        #expect(Self.lookup(r, "[x](docs/other.md) §4.4", from: "notes/n.md").paths == ["docs/other.md"])
    }

    @Test func aNamedPathMustEndTheDocumentsPath() {
        let r = Self.resolver(["specs/108/quickstart.md": "## 6 Six\n", "specs/107/quickstart.md": "## 7 Seven\n"])
        #expect(Self.lookup(r, "`specs/107/quickstart.md` §7", from: "specs/108/quickstart.md").paths == ["specs/107/quickstart.md"])
        // The named spec does not number a §6: nothing is shown from the neighbour's file of the same name.
        #expect(Self.lookup(r, "`specs/107/quickstart.md` §6", from: "specs/108/quickstart.md").paths.isEmpty)
    }

    @Test func aSectionOfSomethingElseIsNotTakenFromTheNeighbours() {
        let r = Self.resolver(["docs/spec.md": Self.spec, "docs/n.md": "see spec.md"])
        for cite in ["per RFC 7009 §4.4", "agent2 §4.4", "see Open Questions §4.4", "spec 2 §4.4"] {
            #expect(Self.lookup(r, cite, from: "docs/n.md").paths.isEmpty, "\(cite)")
        }
        #expect(Self.lookup(r, "per the §4.4", from: "docs/n.md").paths == ["docs/spec.md"])
        // A document written with `.md` that has no such section is a precise reference too.
        #expect(Self.lookup(r, "`other.md` §4.4", from: "docs/n.md").paths.isEmpty)
    }

    @Test func aListOfSectionsKeepsTheDocumentOfItsFirst() {
        let r = Self.resolver(["docs/arch.md": "## 4.1 One\n## 4.4 Four\n", "docs/guide.md": "## 4.4 Else\n", "docs/n.md": "x"])
        let ids = IDGrammar.tokens(in: "see `arch.md` §4.1 / §4.4 and [arch](arch.md) §4–§5").filter { $0.id.scope == .section }
        #expect(ids.map(\.id.document) == ["arch.md", "arch.md", "arch.md", "arch.md"])
        #expect(Self.lookup(r, "arch.md §4.1 / §4.4", from: "docs/n.md").paths == ["docs/arch.md"])
    }

    @Test func aNamedDocumentWithoutThatSectionShowsNothing() {
        let r = Self.resolver(["docs/spec.md": Self.spec, "docs/inbound-from-122.md": "## 3 Three\n", "docs/n.md": "see spec.md"])
        #expect(Self.lookup(r, "the inbound §3", from: "docs/n.md").paths.isEmpty)
        #expect(Self.lookup(r, "wordpress-thesis inbound §3", from: "docs/n.md").paths.isEmpty)
        #expect(Self.lookup(r, "the plan §4.4", from: "docs/n.md").paths.isEmpty)
        #expect(Self.lookup(r, "see §4.4", from: "docs/n.md").paths == ["docs/spec.md"])
    }

    @Test func aNameCanBeTheLastWordOfTheFileName() {
        let r = Self.resolver(["docs/design-outline.md": "## 7.2 Contract\n", "docs/n.md": "x"])
        #expect(Self.lookup(r, "outline § 7.2", from: "docs/n.md").route == .named)
    }

    @Test func aWordThatNamesNoDocumentIsIgnored() {
        let r = Self.resolver(["docs/spec.md": Self.spec, "docs/n.md": "in §4.4, see spec.md"])
        let got = Self.lookup(r, "in §4.4", from: "docs/n.md")
        #expect(got.paths == ["docs/spec.md"] && got.route == .nearby)
        #expect(Self.lookup(r, "Section §4.4", from: "docs/n.md").route == .nearby)
    }

    // Path (b): the file being read.
    @Test func theReadersOwnFileDefinesFirst() {
        let r = Self.resolver(["docs/a.md": "## 4.4 In a\n", "docs/b.md": "## 4.4 In b\n"])
        let got = Self.lookup(r, "§4.4", from: "docs/b.md")
        #expect(got.paths == ["docs/b.md"] && got.route == .ownFile)
    }

    // Path (c): the nearest folder going up.
    @Test func theNearestFolderGoingUpWins() {
        let r = Self.resolver(["docs/spec.md": Self.spec, "docs/deep/x.md": "see §4.4 in spec.md", "docs/deep/sub/y.md": "## 4.4 Near\n", "docs/deep/sub/q.md": "see y.md", "other/z.md": "## 4.4 Far\n"])
        #expect(Self.lookup(r, "§4.4", from: "docs/deep/x.md").paths == ["docs/spec.md"])
        #expect(Self.lookup(r, "§4.4", from: "docs/deep/sub/q.md").paths == ["docs/deep/sub/y.md"])
    }

    @Test func aNeighbourTheReaderNeverNamesIsNotTaken() {
        let r = Self.resolver(["docs/spec.md": Self.spec, "docs/n.md": "see §4.4 and other.md"])
        #expect(Self.lookup(r, "see §4.4", from: "docs/n.md").paths.isEmpty)
    }

    @Test func severalDocumentsAtTheNearestLevelAreAmbiguous() {
        let r = Self.resolver(["docs/a.md": "## 4.4 A\n", "docs/b.md": "## 4.4 B\n", "docs/c.md": "§4.4 (a.md, b.md)"])
        let got = Self.lookup(r, "§4.4", from: "docs/c.md")
        #expect(got.paths == ["docs/a.md", "docs/b.md"] && got.route == .nearby)
    }

    @Test func withNoFileKnownEveryDocumentOfTheRepoIsListed() {
        let r = Self.resolver(["docs/a.md": "## 4.4 A\n", "x/b.md": "## 4.4 B\n"])
        let got = Self.lookup(r, "§4.4", from: nil)
        #expect(Set(got.paths) == ["docs/a.md", "x/b.md"] && got.route == .repoWide)
    }

    @Test func aSectionNoHeadingNumbersShowsNothing() {
        let r = Self.resolver(["docs/spec.md": Self.spec])
        #expect(Self.lookup(r, "§9", from: "docs/spec.md").paths.isEmpty)
        #expect(!r.resolve("§9", preferredRepo: "r", fromPath: "docs/spec.md", block: "see §9").isShown)
    }

    @Test func aSubSectionFallsBackToItsParent() {
        let r = Self.resolver(["docs/spec.md": Self.spec])
        #expect(Self.lookup(r, "§4.4.2", from: "docs/spec.md").paths == ["docs/spec.md"])
    }

    @Test func resolveShowsTheHeadingForTheWordUnderTheCursor() {
        let r = Self.resolver(["spec/spec.md": Self.spec, "n/n.md": "ok"])
        let res = r.resolve("§4.4", preferredRepo: "r", context: "as in spec ", fromPath: "n/n.md", block: "as in spec §4.4 above")
        #expect(res.isShown && res.definitions.first?.title == "Autonomy" && res.definitions.first?.path == "spec/spec.md")
    }

    @Test func thePickerReadsTheSectionUnderTheCursor() {
        let r = Self.resolver(["spec/spec.md": Self.spec, "n/n.md": "ok"])
        let line = "as in spec §4.4 above"
        let at = (line as NSString).range(of: "§4.4").location + 1
        let res = CandidatePicker.pick(line: line, cursorOffset: at, resolver: r, preferredRepo: "r", fromPath: "n/n.md")
        #expect(res?.definitions.first?.title == "Autonomy" && res?.definitions.first?.path == "spec/spec.md")
        // With no file known, every document of the repo that numbers it is listed.
        let any = CandidatePicker.pick(line: "see §4.4", cursorOffset: 5, resolver: r, preferredRepo: "r")
        #expect(any?.definitions.first?.title == "Autonomy")
    }

    @Test func requirementFormsKeepWorking() {
        let r = Self.resolver(["docs/spec.md": "### Requirement 3: Login\n\n- **FR-001**: Do it\n"])
        let a = r.resolve("FR-001", preferredRepo: "r", fromPath: "docs/spec.md")
        let b = r.resolve("Requirement 3", preferredRepo: "r", fromPath: "docs/spec.md")
        #expect(a.isShown && b.isShown)
    }
}

extension SectionRefsTests {
    @Test func documentsNamedFindsMarkdownFileStems() {
        #expect(SectionRefs.documentsNamed(in: "see `Data-Model.md`, [x](docs/spec.md#a) and notes.md. Not foo.mdx or bar.md5 or .md") == ["data-model", "notes", "spec"])
        #expect(SectionRefs.documentsNamed(in: "nothing here").isEmpty)
    }
}
