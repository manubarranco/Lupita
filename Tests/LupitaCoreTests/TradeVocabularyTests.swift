import Foundation
import Testing
@testable import LupitaCore

// D62: the design and development packages. Same rules as git (D42).
@Suite(.serialized, .language("es")) struct TradeVocabularyTests {
    static func resolver(glossary: String? = nil) throws -> Resolver {
        guard let glossary else { return Resolver(index: RefIndex()) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-trade-\(UUID().uuidString)")
        let repo = root.appendingPathComponent("atlas")
        try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try glossary.write(to: repo.appendingPathComponent("glossary.md"), atomically: true, encoding: .utf8)
        return Resolver(index: RefIndex.build(roots: [root.path]))
    }

    /// `⟦word⟧` marks what the pointer is on.
    static func pick(_ sentence: String, _ resolver: Resolver) -> Resolution? {
        let start = sentence.range(of: "⟦")!
        let offset = sentence.distance(from: sentence.startIndex, to: start.lowerBound) + 1
        let line = sentence.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: "")
        return CandidatePicker.pick(line: line, cursorOffset: offset, resolver: resolver)
    }

    static func answer(_ sentence: String, _ resolver: Resolver) -> String? {
        guard let r = pick(sentence, resolver), r.isShown else { return nil }
        return r.definitions.first?.id
    }

    /// One sentence per term, in the order of the table: the term must be explained, by that term.
    static let design: [String] = [
        "cambia la ⟦tipografía⟧ de los títulos", "súbele el ⟦peso⟧ y el contraste al título", "el ⟦interlineado⟧ está muy apretado",
        "abre el ⟦tracking⟧ y el kerning", "el logo tiene mal el ⟦kerning⟧", "los títulos en ⟦serif⟧", "no está en la ⟦escala tipográfica⟧",
        "falta ⟦jerarquía⟧ en el layout", "el ⟦layout⟧ de la ficha", "se sale de la ⟦retícula⟧", "usa la ⟦escala de espaciado⟧",
        "le falta ⟦aire⟧ al layout", "no hay ⟦alineación⟧ en el layout", "tiene que estar ⟦above the fold⟧", "ese azul no es de la ⟦paleta⟧ del sistema de diseño",
        "no pasa ⟦contraste⟧ en el mockup", "usa el ⟦color de acento⟧", "baja a un ⟦neutro⟧ de la paleta", "está en el ⟦sistema de diseño⟧",
        "usa el ⟦design token⟧", "falta la ⟦variante⟧ del mockup", "has despegado la ⟦instancia⟧ del mockup", "ponle ⟦auto layout⟧",
        "está en el ⟦artboard⟧", "publica la ⟦librería⟧ del sistema de diseño", "el ⟦handoff⟧ es el jueves", "mira las ⟦redlines⟧",
        "falta el ⟦empty state⟧", "no hace falta que sea ⟦pixel perfect⟧", "un problema de ⟦UX⟧", "la ⟦UI⟧ está cerrada", "primero un ⟦wireframe⟧",
        "te paso el ⟦mockup⟧", "lo probamos con un ⟦prototipo⟧", "el ⟦user flow⟧ tiene seis pasos", "mira el ⟦user journey⟧", "para esa ⟦user persona⟧",
        "salió en el ⟦test de usabilidad⟧", "ese enlace no tiene ⟦affordance⟧", "revisa la ⟦a11y⟧", "el ⟦microcopy⟧ del botón",
    ]

    static let development: [String] = [
        "el ⟦build⟧ falla", "es una ⟦regresión⟧ de la 0.9", "he encontrado un ⟦bug⟧", "sale un ⟦hotfix⟧ esta tarde", "⟦desplegamos⟧ el viernes",
        "en ⟦prod⟧ no pasa", "está en ⟦staging⟧, pruébalo", "en mi ⟦entorno⟧ falla el deploy", "entra en la ⟦próxima release⟧", "los ⟦tests⟧ están en verde",
        "es solo un ⟦refactor⟧", "eso es ⟦deuda técnica⟧", "hay que actualizar ⟦dependencias⟧ del build", "está detrás de un ⟦feature flag⟧", "¿y el ⟦edge case⟧ de la lista?",
        "eso ⟦es legacy⟧, mejor no tocar", "el color está ⟦hardcodeado⟧", "¿⟦qué stack⟧ usáis?", "es un cambio de ⟦frontend⟧", "buscamos un ⟦full stack⟧",
        "con ese ⟦framework⟧ no se puede", "en ⟦responsive⟧ se rompe", "tarda en ⟦renderizar⟧", "se pierde el ⟦estado⟧ del framework", "pásale el tamaño por ⟦props⟧",
        "borra la ⟦caché⟧ y recarga", "mira si sale algo ⟦en consola⟧", "falta en ⟦backend⟧", "⟦el servidor⟧ está caído", "eso lo da la ⟦API⟧",
        "falta el ⟦endpoint⟧ de pedidos", "está en ⟦base de datos⟧", "⟦la query⟧ va lenta", "la ⟦petición⟧ al servidor tarda", "falla el ⟦auth⟧",
        "te mando el ⟦JSON⟧", "corre la ⟦migración⟧ en la base de datos", "hay mucha ⟦latencia⟧", "eso ⟦no escala⟧", "lo hace un ⟦cron⟧ por la noche",
        "Stripe nos avisa por ⟦webhook⟧", "da ⟦timeout⟧",
    ]

    @Test func everyTermIsExplainedInItsSentence() throws {
        let resolver = try Self.resolver()
        #expect(TradeVocabulary.designTerms.count == 41)
        #expect(TradeVocabulary.developmentTerms.count == 42)
        #expect(Self.design.count == 41)
        #expect(Self.development.count == 42)
        for (sentence, term) in zip(Self.design, TradeVocabulary.designTerms) {
            #expect(Self.answer(sentence, resolver) == term.names, "\(sentence)")
        }
        for (sentence, term) in zip(Self.development, TradeVocabulary.developmentTerms) {
            #expect(Self.answer(sentence, resolver) == term.names, "\(sentence)")
        }
    }

    @Test func manusOwnSentencesWork() throws {
        let resolver = try Self.resolver()
        for (sentence, expected) in [("el ⟦build⟧ falla", "build · compilar"), ("te paso la ⟦build⟧ nueva", "build · compilar"),
                                     ("the ⟦build⟧ is failing", "build · compilar"), ("es una ⟦regresión⟧", "regresión · regression"),
                                     ("falta que ⟦back⟧ lo devuelva", "backend · back"), ("un cambio solo de ⟦front⟧", "frontend · front")] {
            #expect(Self.answer(sentence, resolver) == expected, "\(sentence)")
        }
    }

    @Test func ordinaryProseResolvesNothing() throws {
        let resolver = try Self.resolver()
        for sentence in ["we ⟦build⟧ houses", "go ⟦back⟧ home", "in ⟦front⟧ of the door", "el ⟦peso⟧ del paquete", "una ⟦persona⟧ amable",
                         "el ⟦estado⟧ de la carretera", "the ⟦state⟧ of play", "the ⟦test⟧ was hard", "the ⟦release⟧ of the film", "un ⟦flujo⟧ de agua",
                         "aire", "hace ⟦aire⟧ fuera", "tienes ⟦acento⟧ andaluz", "a ⟦stack⟧ of paper", "la ⟦fuente⟧ de la plaza", "fix ⟦dinner⟧ tonight",
                         "voy a ⟦consulta⟧ del médico", "la ⟦librería⟧ de la esquina"] where sentence.contains("⟦") {
            #expect(Self.answer(sentence, resolver) == nil, "\(sentence)")
        }
    }

    @Test func noWordBelongsToTwoPackages() {
        func aliases(_ terms: [GitVocabulary.Term]) -> Set<String> {
            Set(terms.flatMap(\.aliases).map { GitVocabulary.fold($0.text) })
        }
        let git = aliases(GitVocabulary.terms), design = aliases(TradeVocabulary.designTerms), development = aliases(TradeVocabulary.developmentTerms)
        #expect(git.intersection(design).isEmpty, "\(git.intersection(design))")
        #expect(git.intersection(development).isEmpty, "\(git.intersection(development))")
        #expect(design.intersection(development).isEmpty, "\(design.intersection(development))")
    }

    @Test func stagingAreaIsGitAndStagingIsDevelopment() throws {
        let resolver = try Self.resolver()
        #expect(Self.answer("el ⟦staging area⟧ está vacío", resolver) == "stage · staging area")
        #expect(Self.answer("está en ⟦staging⟧", resolver) == "staging · preproducción")
    }

    @Test func aRepoGlossaryWins() throws {
        let resolver = try Self.resolver(glossary: "- **handoff** — la reunión de los jueves\n")
        let r = try #require(Self.pick("el ⟦handoff⟧ es hoy", resolver))
        #expect(r.definitions.first?.rule == .term)
    }

    /// With no window repo a glossary answers before a package, also with the article (`el build`). With one, see D66.
    @Test func aGlossaryWordOfTheSameNameStillWins() throws {
        let resolver = try Self.resolver(glossary: "- **Build** — crear y mantener las piezas\n")
        #expect(Self.pick("el ⟦build⟧ falla", resolver)?.definitions.first?.rule == .term)
    }

    @Test func eachSwitchSilencesItsOwnPackage() throws {
        let resolver = try Self.resolver()
        TermPackages.$off.withValue([.design]) {
            #expect(Self.answer("el ⟦kerning⟧ está mal", resolver) == nil)
            #expect(Self.answer("he encontrado un ⟦bug⟧", resolver) != nil)
        }
        TermPackages.$off.withValue([.development]) {
            #expect(Self.answer("he encontrado un ⟦bug⟧", resolver) == nil)
            #expect(Self.answer("el ⟦kerning⟧ está mal", resolver) != nil)
        }
    }

    @Test func theUnderlineMarksThem() throws {
        let resolver = try Self.resolver()
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("el kerning y el bug"), resolver: resolver).count == 2)
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("una persona amable en la plaza"), resolver: resolver).isEmpty)
        TermPackages.$off.withValue([.design, .development]) {
            #expect(HighlightPicker.marks(words: HighlightPickerTests.row("el kerning y el bug"), resolver: resolver).isEmpty)
        }
    }

    @Test func theTooltipSaysWhichPackageAnswered() {
        #expect(TradeVocabulary.label(forKey: "design:3") == S.kindDesign)
        #expect(TradeVocabulary.label(forKey: "development:3") == S.kindDevelopment)
        #expect(TradeVocabulary.label(forKey: "git:3") == S.kindGit)
    }
}
