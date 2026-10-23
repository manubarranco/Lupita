import CoreGraphics
import Foundation
import Testing
@testable import LupitaCore

// Fixtures copy the shapes of real lines from agent-written repos (see docs/decisions.md, D6);
// repo names and texts are invented.

@Suite struct GrammarTests {
    @Test(arguments: [
        ("D23", "D23"), ("D001", "D001"), ("ADR-004", "ADR004"), ("BUG-01", "BUG01"),
        ("E2-S3b", "E2-S3b"), ("E11-S09", "E11-S09"), ("QL25", "QL25"),
    ])
    func normalizesKeys(text: String, key: String) {
        #expect(IDGrammar.parse(text)?.key == key)
    }

    @Test(arguments: ["GPL3", "UTF8", "2026-04-03", "d23", "D23x9", "hello"])
    func rejectsNonIDs(text: String) {
        #expect(IDGrammar.parse(text) == nil)
    }

    @Test func findsTokensInProse() {
        let ids = IDGrammar.tokens(in: "Ver D23 y ADR-004 (también E2-S3b), no GPL3.").map(\.id.display)
        #expect(ids == ["D23", "ADR-004", "E2-S3b"])
    }
}

@Suite struct DefinitionRuleTests {
    @Test(arguments: [
        ("## D001 — 2026-04-03 — Regla de estilo: sin punto y coma", "D001", DefinitionRule.heading, "Regla de estilo: sin punto y coma"),
        ("## D001 — Nombrar tablas en PLURAL · 2026-06-01", "D001", .heading, "Nombrar tablas en PLURAL · 2026-06-01"),
        ("### **Q07**: ¿Qué hacemos con X?", "Q07", .heading, "¿Qué hacemos con X?"),
        ("## E2-S3b voice input", "E2-S3b", .heading, "voice input"),
        ("- **D001**: sin punto y coma en los textos de la interfaz", "D001", .listOrColon, "sin punto y coma en los textos de la interfaz"),
        ("**L20:** una rama por feature", "L20", .listOrColon, "una rama por feature"),
        ("Q07: ¿cuántos repos?", "Q07", .listOrColon, "¿cuántos repos?"),
        ("| M1 | Fix BUG-01 input micrófono | ⬜ |", "M1", .tableRow, "Fix BUG-01 input micrófono"),
        ("| **E8-S6 Exportar facturas (CSV export) \\[Could\\]**   |", "E8-S6", .tableRow, "Exportar facturas (CSV export) [Could]"),
        ("| E10-S2 ✅ Historial de pedidos (/orders)   |", "E10-S2", .tableRow, "Historial de pedidos (/orders)"),
    ])
    func acceptsDefinitions(line: String, key: String, rule: DefinitionRule, title: String) {
        let hit = DefinitionRules.lineDefinition(line)
        #expect(hit?.id.key == key)
        #expect(hit?.rule == rule)
        #expect(hit?.title == title)
    }

    @Test(arguments: [
        "- **P1 bloqueante**: no hay findings P1 nuevos.",
        "- **A6 era un fallo, no un port.** En el editor el atajo…",
        "Según D23, esto no se reabre.",
        "## Decisiones (ver D23)",
        "| ID | Título |",
        "| **D008** (Caché compartida) | **Alineada** |",
        "|----|--------|",
    ])
    func rejectsMentions(line: String) {
        #expect(DefinitionRules.lineDefinition(line) == nil)
    }

    @Test func fileNames() {
        #expect(DefinitionRules.fileNameDefinition("E2-S3b-voice-input.md")?.id.key == "E2-S3b")
        #expect(DefinitionRules.fileNameDefinition("D23.md")?.id.key == "D23")
        #expect(DefinitionRules.fileNameDefinition("README.md") == nil)
        #expect(DefinitionRules.fileNameDefinition("D23notes.md") == nil)
    }

    @Test func repeatedOrBareHeadingsAreSections() {
        let lines = ["## D034 -- reintentos", "## D034 bloque 2 -- timeouts", "## P1", "- E1", "## D35 — Real"]
        let rules = Dictionary(uniqueKeysWithValues: DefinitionRules.definitions(fileName: "README.md", lines: lines).map { ("\($0.id.key)@\($0.line)", $0.rule) })
        #expect(rules["D034@0"] == .section)
        #expect(rules["D034@1"] == .section)
        #expect(rules["P1@2"] == .section)
        #expect(rules["D35@4"] == .heading)
    }

    @Test func ignoresCodeFencesAndReadsFrontmatter() {
        let lines = ["---", "id: ADR-004", "---", "# Use SQLite", "```markdown", "## D{N} — Template", "## D99 — Example", "```"]
        let hits = DefinitionRules.definitions(fileName: "notes.md", lines: lines)
        #expect(hits.map(\.id.key) == ["ADR004"])
        #expect(hits.first?.rule == .frontmatter)
    }
}

@Suite struct IndexAndResolverTests {
    static func makeIndex() -> RefIndex {
        var index = RefIndex()
        index.add(text: """
            # Decisions
            ## D001 — Sin punto y coma
            Nada de punto y coma en la interfaz.
            ## QL25 — Cola de revisión
            Una sola cola.
            """, fileName: "decisions.md", repo: "atlas", relativePath: "memory/decisions.md", absolutePath: "/x/atlas/memory/decisions.md")
        index.add(text: "- **D001**: sin punto y coma (ver memory/decisions.md)\nAplica D001 y QL25.",
                  fileName: "CLAUDE.md", repo: "atlas", relativePath: "CLAUDE.md", absolutePath: "/x/atlas/CLAUDE.md")
        index.add(text: "## D001 — Base de datos: SQLite\nUsamos SQLite.",
                  fileName: "decisions.md", repo: "harbor", relativePath: "docs/decisions.md", absolutePath: "/x/harbor/docs/decisions.md")
        index.rank()
        return index
    }

    @Test func headingBeatsRestatementAndCountsMentions() {
        let index = Self.makeIndex()
        let defs = index.definitions["D001"]!
        #expect(defs.count == 3)
        #expect(defs.first?.rule == .heading)
        #expect(index.definitions["D001"]!.first { $0.repo == "atlas" }?.path == "memory/decisions.md")
        #expect(index.mentions["D001"]?.count == 1)
        #expect(index.definitions["QL25"]?.first?.summary == "Una sola cola.")
    }

    @Test func preferredRepoComesFirst() {
        let r = Resolver(index: Self.makeIndex())
        #expect(r.resolve("D001", preferredRepo: "harbor").definitions.first?.repo == "harbor")
        #expect(r.resolve("D001", preferredRepo: "atlas").definitions.first?.path == "memory/decisions.md")
    }

    @Test func repoNamedInContextWins() {
        let r = Resolver(index: Self.makeIndex())
        let res = r.resolve("D001", preferredRepo: "atlas", context: "commit directo a harbor docs/decisions.md D001")
        #expect(res.definitions.first?.repo == "harbor")
        #expect(!res.fromOtherRepo)
    }

    @Test func weakLocalSectionLosesToRealDefinitionElsewhere() {
        var index = Self.makeIndex()
        index.add(text: "## QL25 -- paso 1\n## QL25 -- paso 2", fileName: "README.md", repo: "compass",
                  relativePath: "README.md", absolutePath: "/x/compass/README.md")
        index.rank()
        let res = Resolver(index: index).resolve("QL25", preferredRepo: "compass")
        #expect(res.definitions.first?.repo == "atlas")
        #expect(res.fromOtherRepo)
    }

    @Test func nearestFolderWinsInsideARepo() {
        var index = Self.makeIndex()
        index.add(text: "## D001 — Facturación mensual", fileName: "decisions.md", repo: "atlas",
                  relativePath: "domains/billing/decisions.md", absolutePath: "/x/atlas/domains/billing/decisions.md")
        index.rank()
        let r = Resolver(index: index)
        #expect(r.resolve("D001", preferredRepo: "atlas", fromPath: "domains/billing/poc.md").definitions.first?.path == "domains/billing/decisions.md")
        #expect(r.resolve("D001", preferredRepo: "atlas", fromPath: "memory/lessons.md").definitions.first?.path == "memory/decisions.md")
    }

    @Test func weakSectionsFromOtherReposAreDropped() {
        var index = Self.makeIndex()
        index.add(text: "## P1\n- algo", fileName: "backlog.md", repo: "ds", relativePath: "backlog.md", absolutePath: "/x/ds/backlog.md")
        index.rank()
        #expect(Resolver(index: index).resolve("P1", preferredRepo: "atlas").kind == .undefined)
    }

    @Test func correctsOCRConfusions() {
        let r = Resolver(index: Self.makeIndex())
        for garbled in ["QL2S", "D0O1", "DOO1", "QLZ5"] {
            let res = r.resolve(garbled)
            #expect(res.kind == .corrected, "\(garbled)")
            #expect(res.key != nil)
        }
        #expect(r.resolve("QL2S").key == "QL25")
        // Slashed zero from monospaced fonts (seen in real OCR: "LØ15").
        #expect(r.resolve("DØØ1").kind == .exact)
        #expect(r.resolve("D\u{041E}01").key == "D001")  // Cyrillic О as the first zero
        // Three look-alikes at once, seen in real OCR of VS Code: "LOoz" for "L002".
        var withLesson = Self.makeIndex()
        withLesson.add(text: "## L002 — Lección", fileName: "l.md", repo: "v", relativePath: "l.md", absolutePath: "/x/l.md")
        withLesson.rank()
        #expect(Resolver(index: withLesson).resolve("LOoz").key == "L002")
        #expect(Resolver(index: withLesson).resolve("LOS").kind != .corrected)
        #expect(r.resolve("D00|").key == "D001")
        #expect(r.resolve("| D001 |").key == "D001")
    }

    @Test func shortCorrectionsAreSuggestions() {
        var index = Self.makeIndex()
        index.add(text: "## D5 — Cinco", fileName: "d.md", repo: "x", relativePath: "d.md", absolutePath: "/x/d.md")
        index.rank()
        let r = Resolver(index: index)
        #expect(r.resolve("DS").isSuggestion)
        #expect(!r.resolve("QL2S").isSuggestion)
        #expect(!r.resolve("D5").isSuggestion)
    }

    @Test func leavesUnknownsAlone() {
        let r = Resolver(index: Self.makeIndex())
        #expect(r.resolve("D2").kind == .undefined)
        #expect(r.resolve("hola").kind == .notAnID)
        #expect(r.resolve("GPL3").kind == .notAnID)
    }

    @Test func picksNearestIDInOCRLine() {
        let r = Resolver(index: Self.makeIndex())
        let line = "según D001 y también QL2S, ok"
        let results = r.resolveLine(line, cursorOffset: 25)
        #expect(results.first?.key == "QL25")
    }
}

@Suite struct CandidatePickerTests {
    let resolver = Resolver(index: IndexAndResolverTests.makeIndex())

    @Test func picksOnlyTheWordUnderTheCursor() {
        let line = "Aplica D001 y la cola QL25 siempre."
        // Cursor inside "D001" (offset 8).
        #expect(CandidatePicker.pick(line: line, cursorOffset: 8, resolver: resolver)?.key == "D001")
        // Cursor on "cola": a normal word, never the ID next to it.
        #expect(CandidatePicker.pick(line: line, cursorOffset: 18, resolver: resolver)?.kind == .notAnID)
        // Cursor right after "QL25" still counts (AX offsets land on the space).
        #expect(CandidatePicker.pick(line: line, cursorOffset: 26, resolver: resolver)?.key == "QL25")
    }

    @Test func trimsPunctuationAndBold() {
        #expect(CandidatePicker.pick(line: "- **D001**: sin punto y coma", cursorOffset: 5, resolver: resolver)?.key == "D001")
    }

    @Test func picksFromOCRWordBoxes() {
        let words = [
            OCRWord(text: "según", box: CGRect(x: 0, y: 100, width: 40, height: 14)),
            OCRWord(text: "D0O1", box: CGRect(x: 46, y: 100, width: 36, height: 14)),
            OCRWord(text: "harbor", box: CGRect(x: 0, y: 130, width: 60, height: 14)),
        ]
        let hit = CandidatePicker.pick(words: words, cursor: CGPoint(x: 60, y: 106), resolver: resolver)
        #expect(hit?.key == "D001")
        #expect(hit?.kind == .corrected)
        #expect(CandidatePicker.pick(words: words, cursor: CGPoint(x: 300, y: 106), resolver: resolver) == nil)
        // In the gap after the word, and just below the line.
        #expect(CandidatePicker.pick(words: words, cursor: CGPoint(x: 100, y: 106), resolver: resolver)?.key == "D001")
        #expect(CandidatePicker.pick(words: words, cursor: CGPoint(x: 60, y: 120), resolver: resolver)?.key == "D001")
        // Cyrillic Е from OCR.
        let cyrillic = [OCRWord(text: "\u{0415}9", box: CGRect(x: 0, y: 0, width: 20, height: 14))]
        #expect(CandidatePicker.pick(words: cyrillic, cursor: CGPoint(x: 5, y: 7), resolver: resolver)?.query == "E9")
    }
}

@Suite struct IncrementalIndexTests {
    /// A throwaway repo on disk: `.git` folder plus the given markdown files.
    static func makeRepo(_ name: String, files: [String: String]) throws -> Repo {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-tests-\(UUID().uuidString)/\(name)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return Repo(name: name, path: root.path)
    }

    @Test func rebuildingOneRepoLeavesTheOthersAlone() throws {
        let a = try Self.makeRepo("alpha", files: ["decisions.md": "## D001 — Alfa\nVer Q01."])
        let b = try Self.makeRepo("beta", files: ["decisions.md": "## D001 — Beta\nVer Q01."])
        var index = RefIndex.build(repos: [a, b])
        #expect(index.definitions["D001"]?.count == 2)
        #expect(index.mentions["Q01"]?.count == 2)

        // New file and edited title in alpha.
        try "## Q01 — Nueva".write(toFile: a.path + "/questions.md", atomically: true, encoding: .utf8)
        try "## D001 — Alfa editada".write(toFile: a.path + "/decisions.md", atomically: true, encoding: .utf8)
        index.rebuild(repo: a)
        #expect(index.definitions["Q01"]?.first?.repo == "alpha")
        #expect(index.definitions["D001"]?.first { $0.repo == "alpha" }?.title == "Alfa editada")
        #expect(index.definitions["D001"]?.first { $0.repo == "beta" }?.title == "Beta")
        #expect(index.mentions["Q01"]?.files == ["beta/decisions.md"])
        #expect(index.fileCount == 3)

        // Deleted file disappears.
        try FileManager.default.removeItem(atPath: a.path + "/questions.md")
        index.rebuild(repo: a)
        #expect(index.definitions["Q01"] == nil)
    }

    @Test func syncDropsVanishedReposAndAddsNewOnes() throws {
        let a = try Self.makeRepo("alpha", files: ["d.md": "## D001 — Alfa"])
        let b = try Self.makeRepo("beta", files: ["d.md": "## D002 — Beta"])
        var index = RefIndex.build(repos: [a])
        index.sync(repos: [b])
        #expect(index.definitions["D001"] == nil)
        #expect(index.definitions["D002"]?.first?.repo == "beta")
        #expect(index.repos == [b])
    }

    @Test func plainFolderWithoutGitIsOneRepo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-tests-\(UUID().uuidString)/notes")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "## Q01 — Pregunta".write(to: root.appendingPathComponent("q.md"), atomically: true, encoding: .utf8)
        let index = RefIndex.build(roots: [root.path])
        #expect(index.repos.map(\.name) == ["notes"])
        #expect(index.definitions["Q01"]?.first?.repo == "notes")
    }

    @Test func watcherFilterMatchesTheIndexer() {
        let repo = Repo(name: "r", path: "/x/r")
        #expect(RepoDiscovery.isIndexed(path: "/x/r/docs/decisions.md", in: repo))
        #expect(!RepoDiscovery.isIndexed(path: "/x/r/node_modules/a/README.md", in: repo))
        #expect(!RepoDiscovery.isIndexed(path: "/x/r/.claude/worktrees/a/d.md", in: repo))
        #expect(!RepoDiscovery.isIndexed(path: "/x/r/src/main.swift", in: repo))
        #expect(!RepoDiscovery.isIndexed(path: "/x/other/d.md", in: repo))
    }
}

@Suite(.serialized) struct StringsTests {
    @Test func followsTheMacLanguage() {
        let saved = S.language
        defer { S.language = saved }
        S.language = "es-ES"
        #expect(S.notAReference == "No es una referencia conocida")
        #expect(S.cited(1, files: 1) == "Citado 1 vez en 1 archivo")
        #expect(S.updated(seconds: 90) == "Actualizado hace 1 min")
        S.language = "en-GB"
        #expect(S.notAReference == "Not a known reference")
        #expect(S.cited(3, files: 2) == "Cited 3 times in 2 files")
        #expect(S.didYouMean("D5", read: "DS") == "Did you mean D5?  (read: DS)")
        S.language = "fr-FR"  // anything else falls back to English
        #expect(S.quit == "Quit")
    }
}
