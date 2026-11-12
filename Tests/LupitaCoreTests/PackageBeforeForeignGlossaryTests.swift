import Foundation
import Testing
@testable import LupitaCore

// D66: the glossary of the repo being read wins over a vocabulary package; a glossary of another repo does not.

@Suite struct PackageBeforeForeignGlossaryTests {
    let resolver: Resolver

    init() {
        var index = RefIndex()
        index.repos = [Repo(name: "pieces", path: "/tmp/pieces"), Repo(name: "reader", path: "/tmp/reader")]
        index.add(text: "# Glossary\n\n- **build** — crear y mantener las piezas\n- **zorblax** — a word no package knows\n",
                  fileName: "glossary.md", repo: "pieces", relativePath: "docs/glossary.md", absolutePath: "/tmp/pieces/docs/glossary.md")
        index.rank()
        resolver = Resolver(index: index)
    }

    @Test func thePackageAnswersWhenTheGlossaryIsOfAnotherRepo() {
        let r = resolver.resolve("el build", preferredRepo: "reader", block: "el build falla en staging")
        #expect(r.definitions.first?.rule == .vocabulary)
        #expect(!r.fromOtherRepo)
    }

    @Test func theOwnGlossaryStillWins() {
        let r = resolver.resolve("el build", preferredRepo: "pieces", block: "el build falla en staging")
        #expect(r.definitions.first?.rule == .term)
        #expect(r.definitions.first?.repo == "pieces")
    }

    @Test func withNoWindowRepoTheGlossaryAnswersAsBefore() {
        let r = resolver.resolve("el build", block: "el build falla en staging")
        #expect(r.definitions.first?.rule == .term)
    }

    @Test func theArticleBeforeAPackageWordDoesNotBringTheForeignGlossaryBack() {
        var index = RefIndex()
        index.repos = [Repo(name: "pieces", path: "/tmp/pieces"), Repo(name: "reader", path: "/tmp/reader")]
        index.add(text: "- **handoff** — la reunión de los jueves\n", fileName: "glossary.md", repo: "pieces",
                  relativePath: "docs/glossary.md", absolutePath: "/tmp/pieces/docs/glossary.md")
        index.rank()
        let r = CandidatePicker.pick(line: "el handoff es hoy", cursorOffset: 5, resolver: Resolver(index: index), preferredRepo: "reader")
        #expect(r?.definitions.first?.rule == .vocabulary)
    }

    @Test func aWordNoPackageKnowsKeepsTheForeignGlossary() {
        let r = resolver.resolve("zorblax", preferredRepo: "reader", block: "the zorblax of the build")
        #expect(r.definitions.first?.rule == .term)
        #expect(r.fromOtherRepo)
    }

    @Test func aWeakWordWithNothingAroundKeepsTheForeignGlossary() {
        // Bare `build` is ordinary English: the package only speaks with context, so the glossary still answers.
        let r = resolver.resolve("build", preferredRepo: "reader", block: "build")
        #expect(r.definitions.first?.rule == .term)
    }

    @Test func theNewFormsAreRecognised() {
        for phrase in ["front end", "doesn't scale", "does not scale", "times out", "timed out"] {
            #expect(TradeVocabulary.knows(phrase, block: phrase), "\(phrase)")
        }
    }
}
