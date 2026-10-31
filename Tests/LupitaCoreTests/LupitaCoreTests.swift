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

    @Test func dropsAlgorithmsAndProducts() {
        let ids = IDGrammar.tokens(in: "Firma RS256 y HS512, PKCE S256, AES-256, K8s, DB2; RS101 y EOF001 sí.").map(\.id.display)
        #expect(ids == ["RS101", "EOF001"])
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
        ("- [x] T001 Crear modelo de Foo en src/foo.py", "T001", .listOrColon, "Crear modelo de Foo en src/foo.py"),
        ("- [X] T004 [P] [US2] Escribir pruebas de Bar", "T004", .listOrColon, "Escribir pruebas de Bar"),
        ("- [ ] T007 [P] Revisar con T003 y T004 el modelo", "T007", .listOrColon, "Revisar con T003 y T004 el modelo"),
        ("### User Story 1 - Crear Foo (Priority: P1)", "US1", .heading, "Crear Foo"),
        ("## User Story 12 — Borrar Bar", "US12", .heading, "Borrar Bar"),
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
        "- [ ] Revisar D23 con el equipo",
        "- [x] T001",
        "## Phase 3: User Story 1 — Crear Foo (P1)",
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

    @Test func specKitTasksAndStoriesResolvePerFeature() {
        var index = RefIndex()
        for feature in ["001-foo", "002-bar"] {
            index.add(text: "## Phase 1: User Story 1 — Base (P1)\n- [x] T001 [US1] Crear \(feature)\n- US1: T001 completa.",
                      fileName: "tasks.md", repo: "atlas", relativePath: "specs/\(feature)/tasks.md",
                      absolutePath: "/x/atlas/specs/\(feature)/tasks.md")
            index.add(text: "### User Story 1 - Historia de \(feature) (Priority: P1)\nComo usuario…",
                      fileName: "spec.md", repo: "atlas", relativePath: "specs/\(feature)/spec.md",
                      absolutePath: "/x/atlas/specs/\(feature)/spec.md")
        }
        index.rank()
        let r = Resolver(index: index)
        let task = r.resolve("T001", preferredRepo: "atlas", fromPath: "specs/002-bar/plan.md").definitions.first
        #expect(task?.path == "specs/002-bar/tasks.md")
        let story = r.resolve("US1", preferredRepo: "atlas", fromPath: "specs/001-foo/tasks.md").definitions.first
        #expect(story?.path == "specs/001-foo/spec.md")
        #expect(story?.title == "Historia de 001-foo")
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

    @Test func switchedOffReposAreLeftOutOfTheIndex() throws {
        let a = try Self.makeRepo("alpha", files: ["decisions.md": "## D001 — Alfa"])
        let parent = URL(fileURLWithPath: a.path).deletingLastPathComponent().path
        let b = Repo(name: "beta", path: RepoDiscovery.realPath(parent) + "/beta")
        try FileManager.default.createDirectory(atPath: b.path + "/.git", withIntermediateDirectories: true)
        try "## D002 — Beta".write(toFile: b.path + "/decisions.md", atomically: true, encoding: .utf8)
        let all = RepoDiscovery.repos(under: [parent])
        #expect(Set(all.map(\.name)) == ["alpha", "beta"])
        let some = RepoDiscovery.repos(under: [parent], excluding: [b.path])
        #expect(some.map(\.name) == ["alpha"])
        let index = RefIndex.build(roots: [parent], excluding: [b.path])
        #expect(index.definitions["D001"] != nil && index.definitions["D002"] == nil)
        #expect(RepoDiscovery.repos(under: [parent], excluding: Set(all.map(\.path))).isEmpty)
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
        S.withLanguage("es-ES") {
            #expect(S.notAReference == "No es una referencia conocida")
            #expect(S.cited(1, files: 1) == "Citado 1 vez en 1 archivo")
            #expect(S.updated(seconds: 90) == "Actualizado hace 1 min")
        }
        S.withLanguage("en-GB") {
            #expect(S.notAReference == "Not a known reference")
            #expect(S.cited(3, files: 2) == "Cited 3 times in 2 files")
            #expect(S.didYouMean("D5", read: "DS") == "Did you mean D5?  (read: DS)")
        }
        // anything else falls back to English
        S.withLanguage("fr-FR") { #expect(S.quit == "Quit") }
    }
}

// D22, D23: glossary terms.

@Suite struct GlossaryTests {
    static let harborGlossary = """
    # Glosario

    ## Conceptos

    - **Banco / Banco de Pagos** — el banco de pruebas de facturas
      con todas las cuentas a la vez.
    - **cuenta** *(canónico)* — la pluma elíptica del motor
    - **`Ledger`** — el saldo del mes [?]
    - **harbor** — también un término homónimo del repo

    **plan**: lo que se paga
    **saldo:** lo que queda
    | **cobro** | cuando se cobra |
    | Término | Definición |
    - **D001** — nunca un término
    """

    static let otherGlossary = """
    - **Banco** — otra banco, la de otro repo
    - **pipeline** — una palabra genérica
    """

    static func makeResolver() -> Resolver {
        var index = RefIndex()
        index.repos = [Repo(name: "harbor", path: "/x/harbor"), Repo(name: "atlas", path: "/x/atlas")]
        index.add(text: harborGlossary, fileName: "glosario.md", repo: "harbor", relativePath: "docs/glosario.md", absolutePath: "/x/harbor/docs/glosario.md")
        index.add(text: otherGlossary, fileName: "glossary.md", repo: "atlas", relativePath: "docs/glossary.md", absolutePath: "/x/atlas/docs/glossary.md")
        index.add(text: "## D001 — Usar SQLite\nPorque sí.\n", fileName: "decisions.md", repo: "atlas", relativePath: "docs/decisions.md", absolutePath: "/x/atlas/docs/decisions.md")
        index.add(text: "- **ignorado** — fuera de un glosario\n", fileName: "notes.md", repo: "atlas", relativePath: "notes.md", absolutePath: "/x/atlas/notes.md")
        index.rank()
        return Resolver(index: index)
    }

    @Test func recognisesGlossaryFiles() {
        for name in ["glossary.md", "glosario.md", "nomenclatura-partes.md", "Terminología.md", "TERMINOLOGY.md"] {
            #expect(Glossary.isGlossaryFile(name), "\(name)")
        }
        #expect(!Glossary.isGlossaryFile("decisions.md"))
        #expect(!Glossary.isGlossaryFile("glossary.txt"))
    }

    @Test func parsesTheFourFormatsAndAliases() {
        let hits = Glossary.terms(fileName: "glosario.md", lines: Self.harborGlossary.components(separatedBy: "\n"))
        let names = hits.flatMap(\.names)
        #expect(names == ["Banco", "Banco de Pagos", "cuenta", "Ledger", "harbor", "plan", "saldo", "cobro"])
        let banco = hits.first
        #expect(banco?.definition == "el banco de pruebas de facturas con todas las cuentas a la vez.")
        #expect(banco?.line == 4)
    }

    @Test func headingTermsOnlyWithoutListEntries() {
        let headings = ["# Glossary", "### Cuenta", "Una cuenta es un usuario.", "### Plan", "Lo que se paga."]
        let hits = Glossary.terms(fileName: "glossary.md", lines: headings)
        #expect(hits.map(\.names) == [["Cuenta"], ["Plan"]])
        #expect(hits.first?.definition == "Una cuenta es un usuario.")
        let sections = ["### Contabilidad", "- **saldo** — vertical"]
        #expect(Glossary.terms(fileName: "glosario.md", lines: sections).flatMap(\.names) == ["saldo"])
    }

    @Test func genericPatternIsOffByDefault() {
        #expect(Glossary.terms(fileName: "notes.md", lines: ["- **x1** — algo"]).isEmpty)
        #expect(GlossaryTests.makeResolver().resolve("ignorado").kind == .notAnID)
    }

    @Test(arguments: ["Banco", "banco", "la Banco", "La  banco", "los bancos", "the Banco", "`banco`", "BANCO."])
    func normalizesCaseArticlesAndPlurals(text: String) {
        let r = Self.makeResolver().resolve(text, preferredRepo: "harbor")
        #expect(r.kind == .exact)
        #expect(r.definitions.first?.repo == "harbor")
        #expect(r.definitions.first?.rule == .term)
    }

    @Test func foldsAccents() {
        #expect(Glossary.normalize("Contabilidad") == Glossary.normalize("contabilidad"))
        #expect(Glossary.normalize("los plans") == "plan")
        #expect(Glossary.lookupKeys("ciudades").contains("ciudad"))
        #expect(Glossary.normalize("census") == "census")
        #expect(Glossary.normalize("glass") == "glass")
    }

    @Test func aliasesResolveToTheSameDefinition() {
        let r = Self.makeResolver()
        #expect(r.resolve("Banco de Pagos", preferredRepo: "harbor").definitions.first?.line == 5)
        #expect(r.resolve("el banco de pagos", preferredRepo: "harbor").definitions.first?.title == "Banco de Pagos")
        #expect(r.resolve("Ledger", preferredRepo: "harbor").definitions.first?.summary == "el saldo del mes [?]")
    }

    @Test func termInTwoReposPutsTheWindowRepoFirst() {
        let r = Self.makeResolver()
        let harbor = r.resolve("banco", preferredRepo: "harbor")
        #expect(harbor.definitions.map(\.repo) == ["atlas", "harbor"].sorted { $0 == "harbor" ? true : $1 != "harbor" })
        #expect(!harbor.fromOtherRepo)
        let atlas = r.resolve("banco", preferredRepo: "atlas")
        #expect(atlas.definitions.first?.repo == "atlas")
        #expect(!atlas.fromOtherRepo)
        let third = r.resolve("pipeline", preferredRepo: "harbor")
        #expect(third.definitions.first?.repo == "atlas")
        #expect(third.fromOtherRepo)
    }

    @Test func idsRepoNamesAndFilesBeatAHomonymousTerm() {
        var index = GlossaryTests.makeResolver().index
        index.add(text: "- **d001** — homónimo\n- **atlas** — homónimo\n- **docs/a.md** — homónimo\n- **harbor** — otro\n",
                  fileName: "glossary.md", repo: "harbor", relativePath: "glossary.md", absolutePath: "/x/harbor/glossary.md")
        index.rank()
        let r = Resolver(index: index)
        #expect(r.resolve("D001", preferredRepo: "atlas").definitions.first?.rule == .heading)
        #expect(r.resolve("harbor", preferredRepo: "atlas").definitions.first?.rule == .repo)
        #expect(r.resolve("atlas", preferredRepo: "atlas").definitions.first?.rule == .repo)
    }

    @Test func pickerFindsAMultiWordTermFromAnyWordOfIt() {
        let r = Self.makeResolver()
        let line = "Abre el Banco de Pagos para ver la cuenta, luego sigue."
        // Cursor on "el", "Banco", "de" and "Pagos".
        for offset in [5, 9, 15, 19] {
            let hit = CandidatePicker.pick(line: line, cursorOffset: offset, resolver: r, preferredRepo: "harbor")
            #expect(hit?.definitions.first?.title == "Banco de Pagos", "offset \(offset)")
        }
        // Cursor on "cuenta": a one-word term.
        #expect(CandidatePicker.pick(line: line, cursorOffset: 37, resolver: r, preferredRepo: "harbor")?.definitions.first?.title == "cuenta")
        // A word that is no term.
        #expect(CandidatePicker.pick(line: line, cursorOffset: 29, resolver: r, preferredRepo: "harbor")?.kind == .notAnID)
    }

    @Test func pickerStopsAtPunctuation() {
        let r = Self.makeResolver()
        // "Banco, de Pagos" is not the term: the comma closes the phrase, so the single word wins.
        let hit = CandidatePicker.pick(line: "el Banco, de Pagos", cursorOffset: 5, resolver: r, preferredRepo: "harbor")
        #expect(hit?.definitions.first?.title == "Banco")
    }

    @Test func pickerKeepsIDsOverLongerWindows() {
        let r = Self.makeResolver()
        let hit = CandidatePicker.pick(line: "ver D001 cuenta", cursorOffset: 5, resolver: r, preferredRepo: "atlas")
        #expect(hit?.key == "D001")
    }

    @Test func pickerFromOCRRows() {
        let r = Self.makeResolver()
        let words = ["abre", "la", "Banco", "de", "Pagos", "ya"].enumerated().map { i, text in
            OCRWord(text: text, box: CGRect(x: CGFloat(i) * 50, y: 100, width: 44, height: 14))
        }
        let hit = CandidatePicker.pick(words: words, cursor: CGPoint(x: 160, y: 106), resolver: r, preferredRepo: "harbor")
        #expect(hit?.definitions.first?.title == "Banco de Pagos")
        let far = CandidatePicker.pick(words: words, cursor: CGPoint(x: 10, y: 106), resolver: r, preferredRepo: "harbor")
        #expect(far?.kind == .notAnID)
    }

    @Test func oldSavedIndexesStillLoad() throws {
        var index = Self.makeResolver().index
        index.terms = [:]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(index)) as! [String: Any]
        json["terms"] = nil
        let data = try JSONSerialization.data(withJSONObject: json)
        let loaded = try JSONDecoder().decode(RefIndex.self, from: data)
        #expect(loaded.terms.isEmpty)
        #expect(loaded.definitions.count == index.definitions.count)
    }
}
