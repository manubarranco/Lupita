import Testing
@testable import LupitaCore

// D41: a range of IDs lists what it spans.
@Suite struct RangeTests {
    static func resolver() -> Resolver {
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas"), Repo(name: "liosx", path: "/x/liosx")]
        func add(_ n: Int, to repo: String = "atlas", file: String = "decisions.md") {
            index.add(text: "## D\(String(format: "%03d", n)) — Decisión número \(n)\nTexto.\n", fileName: file, repo: repo,
                      relativePath: "docs/\(file)", absolutePath: "/x/\(repo)/docs/\(file)")
        }
        for n in 22...26 where n != 24 { add(n) }
        add(24, file: "bitacora.md")
        for n in 30...45 { add(n) }
        index.add(text: "## L1 — Una lección\nx\n", fileName: "lessons.md", repo: "liosx", relativePath: "lessons.md", absolutePath: "/x/liosx/lessons.md")
        index.add(text: "## L2 — Otra\nx\n", fileName: "lessons.md", repo: "liosx", relativePath: "lessons.md", absolutePath: "/x/liosx/lessons.md")
        index.rank()
        return Resolver(index: index)
    }

    @Test func aRangeListsEveryID() throws {
        S.language = "en"
        let r = Self.resolver().resolve("D022-D026", preferredRepo: "atlas")
        let list = try #require(r.range)
        #expect(list.count == 5)
        #expect(list.entries.map(\.id) == ["D022", "D023", "D024", "D025", "D026"])
        #expect(list.entries.allSatisfy { $0.definition != nil })
        #expect(list.noun == "decisions")
        #expect(S.rangeHeader(list.count, noun: list.noun) == "Range · 5 decisions")
        #expect(list.sharedRepo == "atlas")
        // D024 lives in another file: the file is not shared, the repo is.
        #expect(list.sharedPath == nil)
    }

    @Test func anEnDashIsARangeToo() throws {
        let list = try #require(Self.resolver().resolve("D022–D026,", preferredRepo: "atlas").range)
        #expect(list.count == 5)
    }

    @Test func aMissingIDKeepsItsLine() throws {
        let list = try #require(Self.resolver().resolve("D030-D035", preferredRepo: "atlas").range)
        #expect(list.count == 6)
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas")]
        for n in [1, 2, 4, 5] {
            index.add(text: "## D00\(n) — T\(n)\nx\n", fileName: "decisions.md", repo: "atlas", relativePath: "decisions.md", absolutePath: "/x/atlas/decisions.md")
        }
        index.rank()
        let gap = try #require(Resolver(index: index).resolve("D001-D005").range)
        #expect(gap.entries.map(\.id) == ["D001", "D002", "D003", "D004", "D005"])
        #expect(gap.entries[2].definition == nil)
        #expect(gap.sharedPath == "decisions.md")
    }

    @Test func aLongRangeKeepsTheFirstThreeAndTheLastTwo() throws {
        let list = try #require(Self.resolver().resolve("D030-D045", preferredRepo: "atlas").range)
        #expect(list.count == 16)
        let rows = list.rows
        #expect(rows.count == 6)
        guard case .more(let n) = rows[3] else { Issue.record("no «more» row"); return }
        #expect(n == 11)
        guard case .entry(let last) = rows[5] else { return }
        #expect(last.id == "D045")
        // Six IDs still show in full.
        let six = try #require(Self.resolver().resolve("D030-D035", preferredRepo: "atlas").range)
        #expect(six.rows.count == 6)
        #expect(Self.resolver().resolve("D030-D036", preferredRepo: "atlas").range?.rows.count == 6)
        #expect(Self.resolver().resolve("D030-D037", preferredRepo: "atlas").range?.rows.count == 6)
    }

    @Test func anEndThatIsNotDefinedIsNotARange() {
        let resolver = Self.resolver()
        // LiOS has lessons L1 and L2 but no L0 or L3.
        #expect(resolver.resolve("L0-L3").range == nil)
        #expect(resolver.resolve("L0-L3").kind != .exact)
        #expect(resolver.rangeList("D022-D999") == nil)
        #expect(resolver.rangeList("D026-D022") == nil)
        #expect(resolver.rangeList("L1-D022") == nil)
        #expect(resolver.resolve("L1-L2").range?.count == 2)
    }

    @Test func ordinaryHyphenatedTextIsUntouched() {
        let resolver = Self.resolver()
        #expect(resolver.resolve("D023").range == nil)
        #expect(resolver.resolve("fast-forward").range == nil)
        #expect(resolver.resolve("E2-S3b").range == nil)
    }

    @Test func spanishTexts() {
        S.language = "es"
        defer { S.language = "en" }
        #expect(S.rangeHeader(5, noun: S.rangeNoun(prefix: "D", file: "x.md")) == "Rango · 5 decisiones")
        #expect(S.rangeMore(11) == "… 11 más")
        #expect(S.notDefined == "no definida")
        #expect(S.rangeNoun(prefix: "ZZ", file: "notes.md") == "IDs")
    }

    @Test func theHighlightKnowsARange() {
        let marks = HighlightPicker.marks(words: HighlightPickerTests.row("see D022-D026 now"), resolver: Self.resolver())
        #expect(marks.count == 1)
    }
}
