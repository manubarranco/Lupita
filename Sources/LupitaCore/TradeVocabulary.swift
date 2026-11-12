import Foundation

/// The «vocabulary between trades» packages after git (D42, D62): design for people who do not design, development
/// (front and back) for people who do not program. Same machinery and same rules as `GitVocabulary`: a fixed table in
/// code (D32), no index, no language model (D26), and a word that is also ordinary language counts only with another
/// word of the package around it.
public enum TradeVocabulary {
    struct Pack {
        let package: TermPackage
        /// Prefix of the definition's key: says which package answered, for the tooltip's label.
        let name: String
        let terms: [GitVocabulary.Term]
        /// A file or a branch in the block, or a git term, says the text is about code. Not about design.
        let codeCounts: Bool
        let folded: [String: GitVocabulary.Hit]
        let exact: [String: GitVocabulary.Hit]
        let longest: Int

        init(package: TermPackage, name: String, terms: [GitVocabulary.Term], codeCounts: Bool) {
            self.package = package; self.name = name; self.terms = terms; self.codeCounts = codeCounts
            var folded: [String: GitVocabulary.Hit] = [:], exact: [String: GitVocabulary.Hit] = [:], longest = 1
            for (n, term) in terms.enumerated() {
                for alias in term.aliases {
                    let hit = GitVocabulary.Hit(term: n, strong: alias.strong)
                    if alias.exact { exact[alias.text] = hit; continue }
                    let key = GitVocabulary.fold(alias.text)
                    if let old = folded[key], old.strong, !alias.strong { continue }
                    folded[key] = hit
                    longest = max(longest, key.split(separator: " ").count)
                }
            }
            self.folded = folded; self.exact = exact; self.longest = longest
        }

        func lookup(_ words: ArraySlice<GitVocabulary.Token>) -> GitVocabulary.Hit? {
            let joined = words.map(\.text).joined(separator: " ")
            return exact[joined] ?? folded[GitVocabulary.fold(joined)]
        }

        /// Every term of the package written in `block`, longest phrase first at each place.
        func found(in block: String) -> [GitVocabulary.Hit] {
            let words = GitVocabulary.tokens(block)
            var out: [GitVocabulary.Hit] = []
            var i = 0
            while i < words.count {
                var matched = 0
                for length in stride(from: min(longest, words.count - i), through: 1, by: -1) {
                    let slice = words[i..<i + length]
                    if slice.dropLast().contains(where: \.closes) { continue }
                    if let hit = lookup(slice) { out.append(hit); matched = length; break }
                }
                i += max(matched, 1)
            }
            return out
        }

        func definition(_ phrase: String, block: String, marked: Bool) -> Definition? {
            guard TermPackages.isOn(package) else { return nil }
            let words = GitVocabulary.tokens(phrase)
            guard !words.isEmpty, words.count <= longest, !words.dropLast().contains(where: \.closes),
                  let hit = lookup(words[...]) else { return nil }
            if !hit.strong, !marked, !phrase.contains("`") {
                let around = block.isEmpty ? phrase : block
                let backed = found(in: around).count >= 2
                    || (codeCounts && (GitVocabulary.hasCodeToken(in: around) || GitVocabulary.found(in: around).contains(where: \.strong)))
                guard backed else { return nil }
            }
            let term = terms[hit.term]
            return Definition(id: term.names, key: "\(name):\(hit.term)", repo: "", path: "", line: 0, rule: .vocabulary,
                              title: S.isSpanish ? term.es : term.en,
                              summary: S.seenIn(S.isSpanish ? term.seenEs : term.seenEn),
                              absolutePath: "")
        }
    }

    static let development = Pack(package: .development, name: "development", terms: developmentTerms, codeCounts: true)
    static let design = Pack(package: .design, name: "design", terms: designTerms, codeCounts: false)

    static func definition(_ phrase: String, block: String, marked: Bool) -> Definition? {
        development.definition(phrase, block: block, marked: marked) ?? design.definition(phrase, block: block, marked: marked)
    }

    /// Whether `phrase` would be explained, for the highlight (D39).
    static func knows(_ phrase: String, block: String, marked: Bool = false) -> Bool {
        definition(phrase, block: block, marked: marked) != nil
    }

    /// The word the tooltip shows over a package's answer: `key` is the definition's key.
    public static func label(forKey key: String?) -> String {
        switch key?.split(separator: ":").first {
        case "design": S.kindDesign
        case "development": S.kindDevelopment
        default: S.kindGit
        }
    }

    // MARK: Word forms

    static func strong(_ words: [String]) -> [GitVocabulary.Alias] { GitVocabulary.strong(words) }
    static func weak(_ words: [String]) -> [GitVocabulary.Alias] { GitVocabulary.weak(words) }
    static func exact(_ words: [String]) -> [GitVocabulary.Alias] { words.map { GitVocabulary.Alias(text: $0, exact: true) } }

    /// An English word used in Spanish (`el build`, `la query`): after a Spanish determiner it can only be the loan.
    /// The bare word stays weak, because in English it is ordinary language.
    static func loan(_ words: [String]) -> [GitVocabulary.Alias] {
        let determiners = ["el", "la", "los", "las", "un", "una", "este", "esta", "ese", "esa", "tu", "su", "mi", "del", "al"]
        return strong(words.flatMap { word in determiners.map { "\($0) \(word)" } })
    }

    static func term(_ names: String, _ es: String, _ en: String, _ seenEs: String, _ seenEn: String,
                     _ aliases: [GitVocabulary.Alias]) -> GitVocabulary.Term {
        GitVocabulary.Term(names: names, en: en, es: es, seenEn: seenEn, seenEs: seenEs, aliases: aliases)
    }

    // MARK: Design (validated by Manu, 2026-11-02)

    static let designTerms: [GitVocabulary.Term] = [
        // Type
        term("tipografía · fuente · typeface", "El tipo de letra. La forma de las letras de un texto.", "The style of lettering. The shape of a text's letters.",
             "«cambia la tipografía de los títulos»", "“change the headings' typeface”",
             strong(["tipografía", "tipografías", "typeface", "typefaces", "typography", "font", "fonts"]) + weak(["fuente", "fuentes"])),
        term("peso · weight · bold", "Lo gruesas que son las letras, de finas a muy negras.", "How thick the letters are, from thin to very heavy.",
             "«súbele el peso al título»", "“make the heading's weight heavier”",
             weak(["peso", "weight", "bold", "negrita"])),
        term("interlineado · line-height · leading", "El espacio entre una línea de texto y la siguiente.", "The space between one line of text and the next.",
             "«el interlineado está muy apretado»", "“the leading is too tight”",
             strong(["interlineado", "line-height", "line height"]) + weak(["leading"])),
        term("tracking · letter-spacing", "El aire entre todas las letras de una palabra.", "The air between all the letters of a word.",
             "«abre un poco el tracking de las mayúsculas»", "“open up the tracking on the capitals”",
             strong(["letter-spacing", "letter spacing"]) + weak(["tracking"])),
        term("kerning", "El ajuste del hueco entre dos letras concretas, como «AV».", "Adjusting the gap between two particular letters, like “AV”.",
             "«el logo tiene mal el kerning»", "“the logo's kerning is off”",
             strong(["kerning"])),
        term("serif · sans serif · palo seco", "Letras con pequeños remates en las puntas (serif) o sin ellos (sans).", "Letters with small finishing strokes at the ends (serif) or without them (sans).",
             "«los títulos en serif, el texto en sans»", "“serif headings, sans body text”",
             strong(["serif", "serifs", "sans serif", "sans-serif", "palo seco"])),
        term("escala tipográfica · type scale", "La lista fija de tamaños de letra que se usan, y ninguno más.", "The fixed list of text sizes in use, and no others.",
             "«ese 15 no está en la escala»", "“that 15 isn't on the scale”",
             strong(["escala tipográfica", "type scale"])),
        term("jerarquía · hierarchy", "El orden en que el ojo lee: qué ves primero y qué después.", "The order the eye reads in: what you see first and what next.",
             "«falta jerarquía, todo pesa igual»", "“it lacks hierarchy, everything weighs the same”",
             weak(["jerarquía", "hierarchy"])),
        // Space and composition
        term("layout · maquetación", "Cómo se colocan las cosas en la pantalla.", "How things are placed on the screen.",
             "«el layout de la ficha»", "“the card's layout”",
             strong(["layout", "layouts", "maquetación"])),
        term("grid · retícula · columnas", "Las columnas invisibles que marcan dónde va cada cosa.", "The invisible columns that set where each thing goes.",
             "«se sale de la retícula»", "“it breaks out of the grid”",
             strong(["retícula"]) + weak(["grid", "columnas"])),
        term("escala de espaciado · spacing", "Los tamaños de hueco permitidos entre cosas, siempre los mismos (4, 8, 16…).", "The allowed gap sizes between things, always the same ones (4, 8, 16…).",
             "«usa un 16, no un 13»", "“use a 16, not a 13”",
             strong(["escala de espaciado", "spacing scale"]) + weak(["spacing", "espaciado"])),
        term("aire · whitespace · espacio en blanco", "El hueco vacío que deja respirar al contenido.", "The empty room that lets content breathe.",
             "«le falta aire»", "“it needs more whitespace”",
             strong(["whitespace", "white space"]) + weak(["aire", "espacio en blanco"])),
        term("alineación · alignment", "Que los bordes de las cosas caigan en la misma línea.", "Making the edges of things fall on the same line.",
             "«el icono no está alineado con el texto»", "“the icon isn't aligned with the text”",
             weak(["alineación", "alignment", "alineado", "alineada", "aligned"])),
        term("above the fold", "Lo que se ve al abrir la página, sin bajar.", "What you see when the page opens, without scrolling.",
             "«el botón tiene que estar above the fold»", "“the button has to be above the fold”",
             strong(["above the fold"])),
        // Colour
        term("paleta · palette", "El conjunto fijo de colores de un producto.", "A product's fixed set of colours.",
             "«ese azul no es de la paleta»", "“that blue isn't in the palette”",
             weak(["paleta", "paletas", "palette", "palettes"])),
        term("contraste · contrast", "Cuánto se distingue un color de otro, por ejemplo el texto del fondo.", "How much one colour stands out from another, like text from its background.",
             "«no pasa contraste»", "“it fails contrast”",
             weak(["contraste", "contrast"])),
        term("color de acento · accent", "El color que llama la atención, reservado para lo importante.", "The colour that draws the eye, kept for what matters.",
             "«el acento solo en la acción principal»", "“the accent only on the main action”",
             strong(["color de acento", "accent color", "accent colour"]) + weak(["acento", "accent"])),
        term("neutros · neutrals", "Los grises, blancos y negros de fondos, textos y bordes.", "The greys, whites and blacks used for backgrounds, text and borders.",
             "«baja ese gris a un neutro más claro»", "“take that grey down to a lighter neutral”",
             weak(["neutros", "neutro", "neutrals", "neutral"])),
        // Design systems and Figma
        term("sistema de diseño · design system", "El conjunto de piezas, reglas y estilos que comparte un producto para verse igual en todas partes.", "The set of pieces, rules and styles a product shares so it looks the same everywhere.",
             "«eso ya está en el sistema de diseño»", "“that's already in the design system”",
             strong(["sistema de diseño", "sistemas de diseño", "design system", "design systems"])),
        term("token · design token", "Un valor con nombre, como un color o un tamaño, que se usa en vez del número suelto.", "A named value, like a colour or a size, used instead of the bare number.",
             "«usa el token, no el hex»", "“use the token, not the hex”",
             strong(["design token", "design tokens"]) + weak(["token", "tokens"])),
        term("variante · variant", "Cada versión de una misma pieza: botón grande, pequeño, desactivado.", "Each version of the same piece: big button, small, disabled.",
             "«falta la variante de error»", "“the error variant is missing”",
             weak(["variante", "variantes", "variant", "variants"])),
        term("instancia · instance", "Una copia de una pieza que sigue a la original: si cambia la original, cambia la copia.", "A copy of a piece that follows the original: change the original and the copy changes.",
             "«has despegado la instancia»", "“you've detached the instance”",
             weak(["instancia", "instancias", "instance", "instances"])),
        term("auto layout", "En Figma, cajas que se recolocan solas cuando cambia lo que tienen dentro.", "In Figma, boxes that rearrange themselves when what's inside changes.",
             "«ponle auto layout»", "“give it auto layout”",
             strong(["auto layout", "auto-layout", "autolayout"])),
        term("frame · artboard · mesa de trabajo", "El lienzo de una pantalla en Figma.", "The canvas of one screen in Figma.",
             "«está en el frame de móvil»", "“it's in the mobile frame”",
             strong(["artboard", "artboards"]) + weak(["frame", "frames", "mesa de trabajo"])),
        term("librería · library", "Las piezas compartidas que usan todos los archivos de Figma de un equipo.", "The shared pieces every Figma file of a team uses.",
             "«publica la librería»", "“publish the library”",
             weak(["librería", "librerías", "library", "libraries"])),
        term("handoff", "La entrega del diseño a quien lo construye, con medidas y notas.", "Handing the design to whoever builds it, with measurements and notes.",
             "«el handoff es el jueves»", "“the handoff is on Thursday”",
             strong(["handoff", "hand-off"])),
        term("specs · redlines", "Las medidas y notas apuntadas encima del diseño.", "The measurements and notes marked on top of the design.",
             "«mira las specs del modal»", "“check the modal's specs”",
             strong(["redlines", "redline"]) + weak(["specs"])),
        term("estado vacío · empty state", "Lo que muestra una pantalla cuando aún no hay nada que enseñar.", "What a screen shows when there's nothing to show yet.",
             "«falta el empty state de la lista»", "“the list's empty state is missing”",
             strong(["estado vacío", "estados vacíos", "empty state", "empty states"])),
        term("pixel perfect", "Que lo construido sea idéntico al diseño, hasta el último punto.", "That what's built matches the design exactly, down to the last dot.",
             "«no hace falta que sea pixel perfect»", "“it doesn't have to be pixel perfect”",
             strong(["pixel perfect", "pixel-perfect"])),
        // Experience and process
        term("UX · experiencia de usuario", "Cómo se siente usar un producto: si se entiende y si cuesta.", "How using a product feels: whether it makes sense and how hard it is.",
             "«es un problema de UX, no de código»", "“it's a UX problem, not a code one”",
             exact(["UX"]) + strong(["experiencia de usuario", "user experience"])),
        term("UI · interfaz", "Lo que se ve y se toca: pantallas, botones, textos.", "What you see and touch: screens, buttons, text.",
             "«la UI está cerrada»", "“the UI is final”",
             exact(["UI"]) + weak(["interfaz", "interfaces"])),
        term("wireframe", "Un boceto de la pantalla en cajas grises, sin estilo, para decidir qué va dónde.", "A sketch of the screen in grey boxes, unstyled, to decide what goes where.",
             "«primero un wireframe»", "“a wireframe first”",
             strong(["wireframe", "wireframes"])),
        term("mockup · maqueta", "La pantalla dibujada con su aspecto final, pero sin funcionar.", "The screen drawn with its final look, but not working.",
             "«te paso el mockup»", "“I'll send you the mockup”",
             strong(["mockup", "mockups", "mock-up", "mock-ups"]) + weak(["maqueta", "maquetas"])),
        term("prototipo · prototype", "Pantallas enlazadas que se pueden pulsar como si fuera la app.", "Linked screens you can tap through as if it were the app.",
             "«lo probamos con un prototipo»", "“we'll try it with a prototype”",
             strong(["prototipo", "prototipos", "prototype", "prototypes"])),
        term("flujo · user flow", "Los pasos que da alguien para hacer una tarea.", "The steps someone takes to do a task.",
             "«el flujo de alta tiene seis pasos»", "“the sign-up flow has six steps”",
             strong(["user flow", "user flows", "flujo de usuario"]) + weak(["flujo", "flujos", "flow", "flows"])),
        term("user journey", "El recorrido entero de alguien con el producto, de principio a fin, también fuera de la pantalla.", "Someone's whole path with the product, start to finish, off the screen too.",
             "«en el journey se pierde aquí»", "“they get lost here in the journey”",
             strong(["user journey", "customer journey", "user journeys", "customer journeys"]) + weak(["journey", "journeys"])),
        // Bare «persona» is an everyday Spanish word: only the phrases.
        term("persona", "Un usuario inventado que resume a un tipo de gente real.", "A made-up user who sums up a kind of real people.",
             "«para la persona de administración»", "“for the admin persona”",
             strong(["user persona", "user personas", "buyer persona", "buyer personas", "persona de usuario"])),
        term("test de usabilidad · usability test", "Ver a gente real usar el diseño para encontrar dónde se atasca.", "Watching real people use the design to find where they get stuck.",
             "«salió en el test de usabilidad»", "“it came up in the usability test”",
             strong(["test de usabilidad", "tests de usabilidad", "usability test", "usability tests", "usability testing"])),
        term("affordance", "Lo que una cosa sugiere que puedes hacer con ella: un botón parece pulsable.", "What a thing suggests you can do with it: a button looks pressable.",
             "«ese enlace no tiene affordance»", "“that link has no affordance”",
             strong(["affordance", "affordances"])),
        term("accesibilidad · a11y", "Que lo pueda usar todo el mundo, también quien ve mal o no usa ratón.", "That everyone can use it, including people who see poorly or don't use a mouse.",
             "«revisa la a11y del formulario»", "“check the form's a11y”",
             strong(["accesibilidad", "accessibility", "a11y"])),
        term("microcopy", "Los textos pequeños de la pantalla: botones, avisos, errores.", "The small bits of text on screen: buttons, notices, errors.",
             "«el microcopy del botón»", "“the button's microcopy”",
             strong(["microcopy"])),
    ]

    // MARK: Development, front and back (validated by Manu, 2026-11-02)

    static let developmentTerms: [GitVocabulary.Term] = [
        // How the work goes
        term("build · compilar", "Convertir el código en algo que se puede abrir o instalar. «El build» es ese resultado.", "Turning code into something you can open or install. “The build” is that result.",
             "«el build falla» · «te paso la build nueva»", "“the build is failing” · “I'll send you the new build”",
             loan(["build", "builds"]) + strong(["the build", "a build", "compilación", "compilar", "compilado", "compila", "compilando", "buildear"]) + weak(["build", "builds"])),
        term("regresión · regression", "Algo que funcionaba y se ha roto con un cambio nuevo.", "Something that used to work and broke with a new change.",
             "«es una regresión de la 0.9»", "“it's a regression from 0.9”",
             strong(["regresión", "regresiones", "regression", "regressions"])),
        term("bug", "Un fallo: el programa hace algo que no debía.", "A fault: the program does something it shouldn't.",
             "«he encontrado un bug»", "“I found a bug”",
             strong(["bug", "bugs"])),
        term("fix · hotfix", "El arreglo de un fallo. Hotfix es uno urgente que se publica enseguida.", "The repair of a fault. A hotfix is an urgent one released right away.",
             "«sale un hotfix esta tarde»", "“a hotfix goes out this afternoon”",
             loan(["fix", "fixes"]) + strong(["hotfix", "hotfixes"]) + weak(["fix", "fixes"])),
        term("deploy · desplegar", "Publicar una versión nueva para que la use la gente.", "Putting a new version live for people to use.",
             "«desplegamos el viernes»", "“we deploy on Friday”",
             strong(["deploy", "deploys", "deployed", "deploying", "deployment", "deployar", "desplegamos", "desplegar", "despliegue", "despliegues", "desplegado", "desplegada"])),
        term("producción · prod", "La versión que usa la gente de verdad.", "The version real people use.",
             "«en prod no pasa»", "“it doesn't happen in prod”",
             strong(["prod", "en producción", "in production"]) + weak(["producción", "production"])),
        term("staging · preproducción", "Una copia de la web real donde se prueba antes de publicar.", "A copy of the real site where things are tried before going live.",
             "«está en staging, pruébalo»", "“it's on staging, try it”",
             strong(["staging", "preproducción", "preprod"])),
        term("entorno · environment", "Cada sitio donde corre el programa: tu ordenador, el de pruebas, el real.", "Each place the program runs: your computer, the test copy, the real one.",
             "«en mi entorno funciona»", "“it works in my environment”",
             weak(["entorno", "entornos", "environment", "environments"])),
        term("release · versión", "Una versión publicada, con su número.", "A published version, with its number.",
             "«entra en la próxima release»", "“it goes in the next release”",
             loan(["release", "releases"]) + strong(["próxima release", "next release"]) + weak(["release", "releases"])),
        term("test", "Una comprobación automática de que algo sigue funcionando.", "An automatic check that something still works.",
             "«los tests están en verde»", "“the tests are green”",
             loan(["test", "tests"]) + weak(["test", "tests", "testing"])),
        term("refactor · refactorizar", "Reordenar el código por dentro sin cambiar lo que hace.", "Reorganising the code inside without changing what it does.",
             "«es solo un refactor, no cambia nada visible»", "“it's just a refactor, nothing visible changes”",
             strong(["refactor", "refactors", "refactoring", "refactored"] + GitVocabulary.spanish("refactorizar"))),
        term("deuda técnica · tech debt", "Atajos tomados hoy que costarán trabajo mañana.", "Shortcuts taken today that will cost work tomorrow.",
             "«eso es deuda técnica»", "“that's tech debt”",
             strong(["deuda técnica", "tech debt", "technical debt"])),
        term("dependencia · dependency", "Código hecho por otros que tu proyecto usa.", "Code made by others that your project uses.",
             "«hay que actualizar dependencias»", "“the dependencies need updating”",
             weak(["dependencia", "dependencias", "dependency", "dependencies"])),
        term("feature flag", "Un interruptor para encender o apagar algo nuevo sin publicar otra vez.", "A switch to turn something new on or off without releasing again.",
             "«está detrás de un feature flag»", "“it's behind a feature flag”",
             strong(["feature flag", "feature flags"])),
        term("caso límite · edge case", "Una situación rara que casi nadie provoca, pero que rompe cosas.", "A rare situation almost nobody triggers, but that breaks things.",
             "«¿y el edge case de la lista vacía?»", "“what about the empty-list edge case?”",
             strong(["caso límite", "casos límite", "edge case", "edge cases"])),
        term("legacy", "Código viejo que sigue en uso y que nadie quiere tocar.", "Old code still in use that nobody wants to touch.",
             "«eso es legacy, mejor no tocar»", "“that's legacy, better not touch it”",
             strong(["es legacy", "código legacy", "legacy code"]) + weak(["legacy"])),
        term("hardcodeado · hardcoded", "Un valor escrito a mano dentro del código en vez de salir de un ajuste o de un token.", "A value typed straight into the code instead of coming from a setting or a token.",
             "«el color está hardcodeado»", "“the colour is hardcoded”",
             strong(["hardcoded", "hard-coded", "hardcode"] + GitVocabulary.spanish("hardcodear"))),
        term("stack", "Las herramientas y lenguajes con que está hecho un producto.", "The tools and languages a product is made with.",
             "«¿qué stack usáis?»", "“what stack do you use?”",
             loan(["stack"]) + strong(["qué stack", "tech stack"]) + weak(["stack"])),
        // Front: what you see
        // Bare «front» and «back» are everyday English: only after a Spanish word.
        term("frontend · front", "La parte que ves y tocas: pantallas y botones.", "The part you see and touch: screens and buttons.",
             "«es un cambio solo de front»", "“it's a front-end-only change”",
             strong(["frontend", "front-end", "front end", "el front", "del front", "de front", "en front", "al front", "que front"])),
        term("full stack", "Quien trabaja en lo que se ve y en lo que no se ve.", "Someone who works on both what you see and what you don't.",
             "«buscamos un full stack»", "“we're looking for a full stack”",
             strong(["full stack", "full-stack", "fullstack"])),
        term("framework", "Una base ya hecha sobre la que se construye la app, como Next.js o Django.", "A ready-made base the app is built on, like Next.js or Django.",
             "«con ese framework no se puede»", "“that framework can't do it”",
             strong(["framework", "frameworks"])),
        term("responsive", "Que la pantalla se adapta al tamaño: móvil, tablet, ordenador.", "That the screen adapts to its size: phone, tablet, computer.",
             "«en responsive se rompe»", "“it breaks in responsive”",
             strong(["responsive"])),
        term("renderizar · render", "Dibujar en pantalla lo que dice el código.", "Drawing on screen what the code says.",
             "«tarda en renderizar»", "“it takes a while to render”",
             strong(["renderizado"] + GitVocabulary.spanish("renderizar")) + weak(["render", "renders", "rendered", "rendering"])),
        term("estado · state", "Lo que la pantalla recuerda ahora mismo: qué está abierto, qué has escrito.", "What the screen remembers right now: what's open, what you typed.",
             "«se pierde el estado al volver»", "“the state is lost on going back”",
             weak(["estado", "state"])),
        term("props", "Los datos que se le pasan a una pieza para que se muestre de una forma u otra.", "The data handed to a piece so it shows one way or another.",
             "«pásale el tamaño por props»", "“pass the size as props”",
             strong(["props"])),
        term("caché · cache", "Una copia guardada para no pedir lo mismo otra vez. Por eso a veces ves lo viejo.", "A saved copy so the same thing isn't fetched again. That's why you sometimes see the old one.",
             "«borra la caché y recarga»", "“clear the cache and reload”",
             strong(["caché", "cachés", "caches", "cached", "caching"] + GitVocabulary.spanish("cachear"))),
        term("consola · console", "El panel donde salen los avisos y errores del código, en el navegador o en el terminal.", "The panel where the code's warnings and errors show up, in the browser or in the terminal.",
             "«mira si sale algo en consola»", "“see if anything shows up in the console”",
             strong(["en consola", "in the console"]) + weak(["consola", "console"])),
        // Back: what you do not see
        term("backend · back", "La parte que no se ve: guarda los datos y hace las cuentas.", "The part you don't see: it keeps the data and does the work.",
             "«falta que back lo devuelva»", "“the back end still has to return it”",
             strong(["backend", "back-end", "back end", "el back", "del back", "de back", "en back", "al back", "que back"])),
        term("servidor · server", "Un ordenador siempre encendido que responde a lo que le piden otros programas.", "A computer that's always on, answering what other programs ask for.",
             "«el servidor está caído»", "“the server is down”",
             strong(["el servidor", "del servidor", "al servidor"]) + weak(["servidor", "servidores", "server", "servers"])),
        term("API", "La forma acordada en que un programa le pide cosas a otro.", "The agreed way one program asks another for things.",
             "«eso lo da la API»", "“the API gives you that”",
             exact(["API", "APIs"])),
        term("endpoint", "Una dirección concreta a la que un programa pide una cosa: una para usuarios, otra para pedidos.", "A specific address a program asks one thing from: one for users, another for orders.",
             "«falta el endpoint de pedidos»", "“the orders endpoint is missing”",
             strong(["endpoint", "endpoints"])),
        term("base de datos · database · BD", "Donde se guarda la información, ordenada para encontrarla rápido.", "Where information is kept, ordered so it can be found fast.",
             "«está en base de datos»", "“it's in the database”",
             strong(["base de datos", "bases de datos", "database", "databases"]) + exact(["BD"])),
        term("query · consulta", "Una pregunta a donde se guardan los datos: «dame los pedidos de hoy».", "A question to where the data is kept: “give me today's orders”.",
             "«la query va lenta»", "“the query is slow”",
             loan(["query", "queries"]) + weak(["query", "queries", "consulta", "consultas"])),
        term("petición · request", "Un mensaje de un programa a otro pidiendo algo.", "A message from one program to another asking for something.",
             "«la petición tarda 3 segundos»", "“the request takes 3 seconds”",
             loan(["request", "requests"]) + weak(["petición", "peticiones", "request", "requests"])),
        term("autenticación · auth · login", "Comprobar quién eres antes de dejarte entrar.", "Checking who you are before letting you in.",
             "«falla el auth»", "“auth is failing”",
             strong(["autenticación", "authentication", "auth"]) + weak(["login", "logins"])),
        term("JSON", "Un formato de texto para pasar datos entre programas.", "A text format for passing data between programs.",
             "«te mando el JSON»", "“I'll send you the JSON”",
             exact(["JSON"])),
        term("migración · migration", "Un cambio en cómo se guardan los datos, aplicado con cuidado a todo lo que ya hay.", "A change in how data is stored, applied carefully to everything already there.",
             "«hay que correr la migración»", "“the migration has to be run”",
             weak(["migración", "migraciones", "migration", "migrations"])),
        term("latencia · latency", "Lo que tarda en llegar una respuesta.", "How long an answer takes to arrive.",
             "«hay mucha latencia»", "“there's a lot of latency”",
             strong(["latencia", "latency"])),
        term("escalar · escalabilidad", "Que siga funcionando cuando lo usa muchísima más gente.", "That it keeps working when far more people use it.",
             "«eso no escala»", "“that doesn't scale”",
             strong(["escalabilidad", "scalability", "scalable", "no escala", "doesn't scale", "does not scale", "won't scale"]) + weak(["escalar"])),
        term("tarea en segundo plano · background job · cron", "Trabajo que el programa hace solo, sin que esperes, o a una hora fija.", "Work the program does on its own, without you waiting, or at a set time.",
             "«lo hace un cron por la noche»", "“a cron does it at night”",
             strong(["tarea en segundo plano", "tareas en segundo plano", "background job", "background jobs", "cron", "cron job", "cron jobs", "crons"])),
        term("webhook", "Un aviso automático que un programa manda a otro cuando pasa algo.", "An automatic notice one program sends another when something happens.",
             "«Stripe nos avisa por webhook»", "“Stripe tells us by webhook”",
             strong(["webhook", "webhooks"])),
        term("timeout", "Cuando una respuesta tarda tanto que se da por perdida.", "When an answer takes so long it's given up on.",
             "«da timeout»", "“it times out”",
             strong(["timeout", "timeouts", "time-out", "times out", "timed out", "timing out"])),
    ]
}

extension Resolver {
    /// The answer of the vocabulary packages for `phrase`, or nil: git first (D42), then the other trades (D62).
    /// Last in the order: ID, repo reference, code, glossary term, packages.
    public func resolveVocabulary(_ phrase: String, block: String, marked: Bool = false) -> Resolution? {
        if let git = resolveGit(phrase, block: block, marked: marked) { return git }
        guard let d = TradeVocabulary.definition(phrase, block: block, marked: marked) else { return nil }
        return Resolution(query: phrase.trimmingCharacters(in: .whitespacesAndNewlines), kind: .exact, key: d.key,
                          definitions: [d], mentions: nil, alternatives: [])
    }
}
