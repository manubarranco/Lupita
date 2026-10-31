import Foundation

/// Every user-facing text, in English and Spanish. Spanish when the Mac's first preferred
/// language is Spanish, English otherwise. The app name lives here only, so a rename is one line.
public enum S {
    public static let appName = "Lupita"

    /// The Mac's first preferred language; settable for tests.
    nonisolated(unsafe) private static var systemLanguage = Locale.preferredLanguages.first ?? "en"
    /// A language that holds only inside `withLanguage`, for the task that runs it: tests in parallel never see each other's.
    public static let languageOverride = TaskLocal<String?>(wrappedValue: nil)

    public static var language: String {
        get { languageOverride.get() ?? systemLanguage }
        set { systemLanguage = newValue }
    }
    public static func withLanguage<R>(_ language: String, _ body: () throws -> R) rethrows -> R {
        try languageOverride.withValue(language, operation: body)
    }
    public static var isSpanish: Bool { language.hasPrefix("es") }
    private static func t(_ en: String, _ es: String) -> String { isSpanish ? es : en }

    // MARK: Lookup
    public static var indexing: String { t("Indexing…", "Indexando…") }
    public static var indexingTryAgain: String { t("Indexing… try again in a moment", "Indexando… prueba en un momento") }
    public static var notAReference: String { t("Not a known reference", "No es una referencia conocida") }

    // MARK: Tooltip
    public static func didYouMean(_ key: String, read: String) -> String {
        t("Did you mean \(key)?  (read: \(read))", "¿Querías decir \(key)?  (leído: \(read))")
    }
    public static func unclearReading(_ query: String) -> String {
        t("Unclear reading of “\(query)”: which one?", "Lectura dudosa de “\(query)”: ¿cuál es?")
    }
    public static func moreDefinitions(_ n: Int) -> String {
        t("+\(n) more \(n == 1 ? "definition" : "definitions")", "+\(n) \(n == 1 ? "definición más" : "definiciones más")")
    }
    public static func cited(_ times: Int, files: Int) -> String {
        t("Cited \(times) \(times == 1 ? "time" : "times") in \(files) \(files == 1 ? "file" : "files")",
          "Citado \(times) \(times == 1 ? "vez" : "veces") en \(files) \(files == 1 ? "archivo" : "archivos")")
    }
    // Ranges of IDs (D41)
    public static func rangeHeader(_ n: Int, noun: String) -> String { t("Range · \(n) \(noun)", "Rango · \(n) \(noun)") }
    public static func rangeMore(_ n: Int) -> String { t("… \(n) more", "… \(n) más") }
    public static var notDefined: String { t("not defined", "no definida") }
    /// «decisions» for `decisions.md` or a `D` prefix, and so on; «IDs» when neither says.
    public static func rangeNoun(prefix: String, file: String) -> String {
        let stem = ((file as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
        switch (stem, prefix) {
        case ("decisions", _), (_, "D"), (_, "ADR"): return t("decisions", "decisiones")
        case ("lessons", _), (_, "L"): return t("lessons", "lecciones")
        case ("questions", _), (_, "Q"): return t("questions", "preguntas")
        default: return "IDs"
        }
    }
    public static var fromAnotherRepo: String { t("from another repo", "de otro repo") }
    public static func openAt(_ path: String, line: Int) -> String {
        t("Open \(path) at line \(line)", "Abrir \(path) en la línea \(line)")
    }

    // MARK: Repo references (D19)
    public static var kindRepo: String { t("repo", "repo") }
    public static func onBranch(_ branch: String) -> String { t("On \(branch)", "En \(branch)") }
    public static func uncommitted(_ n: Int) -> String {
        t("\(n) uncommitted \(n == 1 ? "change" : "changes")", "\(n) \(n == 1 ? "cambio" : "cambios") sin commitear")
    }
    public static var kindCommit: String { t("commit", "commit") }
    public static var kindBranch: String { t("branch", "rama") }
    public static var kindFile: String { t("file", "archivo") }
    public static var kindCommand: String { t("command", "comando") }
    public static var kindTerm: String { t("term", "término") }
    public static func inBranch(_ main: String) -> String { t("in \(main)", "en \(main)") }
    public static func onlyInBranch(_ branch: String) -> String { t("only in \(branch)", "solo en \(branch)") }
    public static var inNoBranch: String { t("in no branch", "en ninguna rama") }
    public static func lastCommit(_ date: String) -> String { t("Last commit \(date)", "Último commit \(date)") }
    public static func mergedInto(_ main: String) -> String { t("merged into \(main)", "fusionada en \(main)") }
    public static func ahead(_ n: Int, of main: String) -> String {
        t("\(n) \(n == 1 ? "commit" : "commits") ahead of \(main)", "\(n) \(n == 1 ? "commit" : "commits") por delante de \(main)")
    }
    public static var branchDeleted: String { t("Deleted branch", "Rama borrada") }
    public static func branchMergedOn(_ date: String, _ subject: String) -> String {
        t("Merged \(date): \(subject)", "Fusionada el \(date): \(subject)")
    }
    public static func branchCitedIn(_ date: String, _ subject: String) -> String {
        t("Named in a commit of \(date): \(subject)", "Citada en un commit del \(date): \(subject)")
    }
    public static func lastChange(_ date: String, _ subject: String) -> String {
        t("Last change \(date): \(subject)", "Último cambio \(date): \(subject)")
    }
    public static func folder(_ items: Int) -> String {
        t("Folder · \(items) \(items == 1 ? "item" : "items")", "Carpeta · \(items) \(items == 1 ? "elemento" : "elementos")")
    }
    public static var openOnGitHub: String { t("Open on GitHub", "Abrir en GitHub") }
    public static var openFolder: String { t("Open the repo folder", "Abrir la carpeta del repo") }
    public static var showFolder: String { t("Show the repo folder", "Mostrar la carpeta del repo") }

    // MARK: Code (D29)
    public static var kindSymbol: String { t("symbol", "símbolo") }
    public static var noComment: String { t("no comment", "sin comentario") }
    public static var kindAddress: String { t("local address", "dirección local") }
    public static func servedByConfig(_ name: String) -> String { t("Started by “\(name)”", "La arranca «\(name)»") }
    public static func servedByProcess(_ command: String) -> String { t("Served by \(command)", "La sirve \(command)") }
    public static var addressUnknown: String { t("No repo declares this address", "Ningún repo declara esta dirección") }
    public static func page(_ route: String) -> String { t("page \(route)", "página \(route)") }
    public static var homePage: String { t("home page", "página de inicio") }
    public static func running(pid: Int) -> String { t("running (pid \(pid))", "encendido (pid \(pid))") }
    public static var kindToken: String { t("CSS token", "token CSS") }
    public static var kindColor: String { t("colour", "color") }
    public static var light: String { t("light", "claro") }
    public static var dark: String { t("dark", "oscuro") }
    public static func writtenAs(_ value: String) -> String { t("written as \(value)", "escrito como \(value)") }
    public static func definedAs(_ names: String) -> String { t("defined as \(names)", "definido como \(names)") }
    public static var noTokenUsesIt: String { t("no token has this colour", "ningún token tiene este color") }
    public static var kindTerminal: String { t("terminal command", "comando de terminal") }
    public static func runsScript(_ body: String) -> String { t("Runs: \(body)", "Ejecuta: \(body)") }
    public static var kindGit: String { "git" }
    public static func seenIn(_ example: String) -> String { t("Example: \(example)", "Ejemplo: \(example)") }
    public static var kindError: String { t("error", "error") }
    public static var kindTag: String { t("HTML tag", "etiqueta HTML") }
    public static var kindPullRequest: String { t("pull request", "pull request") }
    public static var prNotInHistory: String { t("Not in the local history", "No está en el historial local") }
    public static func mergedOn(_ date: String) -> String { t("Merged \(date)", "Fusionada el \(date)") }
    public static var notRunning: String { t("not running", "apagado") }

    // MARK: Menu
    public static var noIndex: String { t("No index", "Sin índice") }
    public static func summary(ids: Int, repos: Int, files: Int) -> String {
        t("\(ids) IDs · \(repos) repos · \(files) files", "\(ids) IDs · \(repos) repos · \(files) archivos")
    }
    public static func updated(seconds: Int) -> String {
        if seconds < 60 { return t("Updated \(max(seconds, 1)) s ago", "Actualizado hace \(max(seconds, 1)) s") }
        if seconds < 3600 { return t("Updated \(seconds / 60) min ago", "Actualizado hace \(seconds / 60) min") }
        return t("Updated \(seconds / 3600) h ago", "Actualizado hace \(seconds / 3600) h")
    }
    public static func shortcut(_ keys: String) -> String {
        t("Shortcut: \(keys) with the pointer on an ID", "Atajo: \(keys) con el ratón sobre un ID")
    }
    public static var pressAndRelease: String { t("press and release", "pulsar y soltar") }
    public static var lens: String { t("Show Lupita", "Mostrar a Lupita") }
    public static var openAtLogin: String { t("Open at login", "Abrir al iniciar sesión") }
    public static var explainTermsOf: String { t("Explain terms of:", "Explicar términos de:") }
    public static var gitPackage: String { "Git" }
    public static var terminalPackage: String { "Terminal" }
    public static var developmentPackage: String { t("Development", "Desarrollo") }
    public static var folders: String { t("Folders to search", "Carpetas de búsqueda") }
    public static var permissions: String { t("Permissions", "Permisos") }
    /// The question around the folder path, which the alert draws in its own style.
    public static var removeFolderAround: (before: String, after: String) {
        isSpanish ? ("¿Quitar la carpeta ", " de Lupita?") : ("Remove the folder ", " from Lupita?")
    }
    public static var removeFolderBody: String {
        t("Lupita will stop searching it. You can add it back any time.",
          "Lupita dejará de buscar en ella. Puedes añadirla de nuevo cuando quieras.")
    }
    public static var removeFromLupita: String { t("Remove from Lupita", "Quitar de Lupita") }
    public static var cancel: String { t("Cancel", "Cancelar") }
    public static var expand: String { t("Show repos", "Mostrar repos") }
    public static var remove: String { t("Remove", "Quitar") }
    public static var addFolder: String { t("Add folder…", "Añadir carpeta…") }
    public static var add: String { t("Add", "Añadir") }
    public static var reindex: String { t("Reindex", "Reindexar") }
    public static var accessibility: String { t("Accessibility", "Accesibilidad") }
    public static var screenRecording: String { t("Screen Recording (OCR)", "Grabación de pantalla (OCR)") }
    public static func grant(_ permission: String) -> String { t("Grant \(permission)…", "Conceder \(permission)…") }
    public static var quit: String { t("Quit", "Salir") }
    public static var folderMissing: String {
        t("Lupita can't find this folder. Was it moved? Click to find it.",
          "Lupita no encuentra esta carpeta. ¿La has movido? Pulsa para buscarla.")
    }
    public static var hideRepo: String { t("Hide from the list (and from searches)", "Ocultar de la lista (y de las búsquedas)") }
    public static var showRepo: String { t("Show again", "Volver a mostrar") }
    public static func hiddenGroup(_ n: Int) -> String { t("Hidden (\(n))", "Ocultos (\(n))") }
    public static var findFolder: String { t("Find", "Buscar") }
    public static func whereIsFolder(_ path: String) -> String { t("Where is \(path) now?", "¿Dónde está ahora \(path)?") }

    // MARK: Permissions
    public static var permissionsTitle: String {
        t("\(appName) needs to read the text under the pointer", "\(appName) necesita leer el texto bajo el ratón")
    }
    public static var permissionsBody: String {
        t("""
          • Accessibility: for the shortcut (⌃⌥⌘: press the three and release) and to read the exact \
          text under the pointer in native apps.
          • Screen Recording: in apps such as VS Code, Cursor, Claude or a browser, \(appName) captures \
          a small strip around the pointer and reads it with OCR on your Mac.
          Only when you press the shortcut. Nothing leaves your Mac and nothing is stored.
          """,
          """
          • Accesibilidad: para el atajo (⌃⌥⌘: pulsar las tres y soltar) y para leer el texto \
          exacto bajo el cursor en las apps nativas.
          • Grabación de pantalla: en apps como VS Code, Cursor, Claude o el navegador, \(appName) \
          captura una franja pequeña alrededor del cursor y la lee con OCR en tu Mac.
          Solo cuando pulsas el atajo. Nada sale del equipo y no se guarda nada.
          """)
    }
    public static var openAccessibility: String { t("Open Accessibility", "Abrir Accesibilidad") }
    public static var later: String { t("Later", "Más tarde") }

    // MARK: Onboarding (D21, D24)
    public static var prepareRepos: String { t("Prepare your repos…", "Prepara tus repos…") }
    public static var onboardingTitle: String { t("Prepare your repos (optional)", "Prepara tus repos (opcional)") }
    public static func onboardingIntro(percent: Int?) -> String {
        let p = percent.map { "\($0) %" }
        let en = p.map { "Lupita already explains \($0) of what your agents cite. With this rule, also what they create from now on, and their internal vocabulary." }
            ?? "With this rule, Lupita also explains what your agents create from now on, and their internal vocabulary."
        let es = p.map { "Lupita ya explica el \($0) de lo que citan tus agentes. Con esta regla, también lo que creen a partir de ahora, y su vocabulario interno." }
            ?? "Con esta regla, Lupita también explica lo que tus agentes creen a partir de ahora, y su vocabulario interno."
        return t(en, es)
    }
    public static var promptLabel: String { t("Prompt for your agent (it reads it in English)", "Prompt para tu agente (lo lee en inglés)") }
    public static var copy: String { t("Copy", "Copiar") }
    public static var openWith: String { t("Open with", "Abrir con") }
    public static var finder: String { "Finder" }
    public static var modeManual: String { t("By hand", "A mano") }
    public static var modeAgent: String { t("With your agent", "Con tu agente") }
    public static var blockLabel: String {
        t("Block for your agents' instructions file", "Bloque para el archivo de instrucciones de tus agentes")
    }
    public static func copyBlockAndOpen(_ file: String) -> String { t("Copy block and open \(file)", "Copiar bloque y abrir \(file)") }
    public static var copyPromptAndOpen: String { t("Copy prompt and open repo", "Copiar prompt y abrir repo") }
    public static var blockCopied: String { t("Block copied", "Bloque copiado") }
    public static var promptCopied: String { t("Prompt copied", "Prompt copiado") }
    public static func pasteBlock(_ file: String) -> String {
        t("Block copied: paste it at the end of \(file) and save.", "Bloque copiado: pégalo al final de \(file) y guarda.")
    }
    public static func pastePrompt(_ repo: String) -> String {
        t("Prompt copied: paste it in your agent's chat in \(repo).", "Prompt copiado: pégalo en el chat de tu agente en \(repo).")
    }
    public static func undefinedCitations(_ n: Int) -> String {
        n == 0 ? t("everything explained", "todo explicado")
               : t("\(n) \(n == 1 ? "citation" : "citations") unexplained", "\(n) \(n == 1 ? "cita sin explicar" : "citas sin explicar")")
    }
    public static var ruleInstalled: String { t("rule in place", "regla puesta") }
    public static var ruleMissing: String { t("no rule", "sin regla") }
    public static var noAgentRepos: String {
        t("No repos with an AGENTS.md or CLAUDE.md found in your folders.", "No hay repos con AGENTS.md o CLAUDE.md en tus carpetas.")
    }

    // MARK: First run: welcome (D56)
    public static var showTutorial: String { t("Show the tutorial…", "Ver el tutorial…") }
    public static var welcomeWindowTitle: String { t("Welcome to Lupita", "Te damos la bienvenida a Lupita") }
    public static var welcomeTitle: String { t("Hi, I'm Lupita", "Hola, soy Lupita") }
    public static var welcomeIntro: String {
        t("Your coding agents write decisions, questions and lessons in .md files and cite them by code. Lupita tells you what each one is, right where you are reading.",
          "Tus agentes de código escriben decisiones, preguntas y lecciones en archivos .md y las citan por su código. Lupita te dice qué es cada una justo donde estás leyendo.")
    }
    public static var welcomeNoteFile: String { t("agent-notes.md", "notas-del-agente.md") }
    /// The three lines of the sample note, each with the reference the user can point at.
    public static var welcomeNote: [(before: String, id: String, after: String)] {
        isSpanish
            ? [("Seguimos la ", "D001", " para el índice."), ("Sigue abierta la ", "Q01", " sobre los permisos."), ("Antes de tocarlo, lee la ", "L01", ".")]
            : [("We follow ", "D001", " for the index."), ("Still open: ", "Q01", ", about permissions."), ("Before touching it, read ", "L01", ".")]
    }
    public static var welcomeHold: String { t("Press and hold", "Mantén pulsado") }
    public static var welcomePoint: String { t("Now point at a reference", "Ahora apunta a una referencia") }
    public static var welcomeRelease: String { t("Let go to see what it is", "Suelta para ver qué es") }
    public static var welcomeDone: String { t("That's it: you know how to use Lupita", "Eso es todo: ya sabes usar Lupita") }
    public static var welcomeHoldSub: String {
        t("A magnifier appears and underlines the references it knows.", "Aparecerá una lupa y subrayará las referencias que conoce.")
    }
    public static var welcomePointSub: String {
        t("Keep holding. Underlined means Lupita can explain it.", "Sigue sin soltar. Subrayado significa que Lupita puede explicarlo.")
    }
    public static var welcomeDoneSub: String {
        t("Try the other two if you like. Then tell Lupita where your repos are.", "Prueba con las otras dos si quieres. Luego dile dónde están tus repos.")
    }
    public static var welcomeTooShort: String {
        t("Hold a little longer, until the references are underlined.", "Mantenlo un poco más, hasta que se subrayen las referencias.")
    }
    public static var welcomeNoTarget: String {
        t("Point at an underlined reference before you let go.", "Apunta a una referencia subrayada antes de soltar.")
    }
    public static var welcomeOpened: String {
        t("In your repos, a click opens the file in your editor.", "En tus repos, un clic abre el archivo en tu editor.")
    }
    public static var welcomeSkip: String { t("I already know how", "Ya sé usarla") }
    /// The definitions behind the three references: each one teaches a part of the gesture.
    public static var welcomeDefinitions: [String: (title: String, summary: String, repo: String)] {
        let repo = t("your-project", "tu-proyecto")
        return [
            "D001": (t("Letting go over a reference shows its definition",
                       "Al soltar el atajo sobre una referencia, se muestra su definición"),
                     t("Click the definition to open its file. To close it, click anywhere else or press Esc.",
                       "Haz clic en la definición para abrir su archivo. Para cerrarla, pulsa fuera o Esc."), repo),
            "Q01": (t("What will I see with the references in my repos?", "¿Qué veré con las referencias de mis repos?"),
                    t("The same as here: its title, a summary and the file where it lives. Lupita reads it from your files, on your Mac.",
                      "Lo mismo que aquí: su título, un resumen y el archivo donde vive. Lupita lo lee de tus archivos, en tu Mac."), repo),
            "L01": (t("What is underlined, Lupita knows", "Lo que está subrayado, Lupita lo conoce"),
                    t("A solid line marks codes like D12 or Q07; a dashed one marks terms from your vocabulary.",
                      "Un trazo continuo marca códigos como D12 o Q07; uno discontinuo, términos de tu vocabulario."), repo),
        ]
    }

    // MARK: First run: folders (D24)
    public static var foldersTitle: String { t("Add your repo folders", "Añade tus carpetas de repos") }
    public static var foldersIntro: String {
        t("Pick the folders where you keep your repos. Lupita reads them on your Mac and nothing leaves it.",
          "Elige las carpetas donde guardas tus repos. Lupita las lee en tu Mac y nada sale de él.")
    }
    public static func repoCount(_ n: Int) -> String { t("\(n) \(n == 1 ? "repo" : "repos")", "\(n) \(n == 1 ? "repo" : "repos")") }
    public static var addOtherFolder: String { t("Add another folder…", "Añadir otra carpeta…") }
    public static var continueLabel: String { t("Continue", "Continuar") }
    public static var noCandidates: String {
        t("No usual repo folders found on this Mac.", "No he encontrado carpetas habituales de repos en este Mac.")
    }

    // MARK: ID report (D40)
    public static var idReportMenu: String { t("Create ID report…", "Crear informe de IDs…") }
    public static var idReportTitle: String { t("ID report", "Informe de IDs") }
    public static var idReportIntro: String {
        t("This report helps find ID formats Lupita does not know yet. It holds only the shape of each ID (letters as A, digits as 9), its prefix, the name of the file where it is written, and counts. It never holds titles, definitions, lines of text or folder paths; your repos are just «repo 1», «repo 2». Lupita sends nothing: you review it, save it and send the email yourself.",
          "Este informe ayuda a descubrir formatos de ID que Lupita aún no conoce. Solo lleva la forma de cada ID (letras como A, dígitos como 9), su prefijo, el nombre del archivo donde está escrito y recuentos. Nunca lleva títulos, definiciones, líneas de texto ni rutas de carpetas; tus repos son solo «repo 1», «repo 2». Lupita no envía nada: tú lo revisas, lo guardas y envías el correo.")
    }
    public static var idReportBuilding: String { t("Reading your files…", "Leyendo tus archivos…") }
    public static var idReportEmpty: String { t("No rows to report.", "No hay filas que informar.") }
    public static func idReportRows(_ n: Int) -> String { t("\(n) \(n == 1 ? "row" : "rows")", "\(n) \(n == 1 ? "fila" : "filas")") }
    public static var idReportRemove: String { t("Remove this row", "Quitar esta fila") }
    public static var idReportSave: String { t("Save file…", "Guardar archivo…") }
    public static var idReportPrepareEmail: String { t("Prepare email", "Preparar correo") }
    public static var idReportSubject: String { t("Lupita ID report", "Informe de IDs de Lupita") }
    public static var idReportDrag: String { t("Drag this file into the email", "Arrastra este archivo al correo") }
    public static var idReportSaveFailed: String { t("Couldn't save the file.", "No se pudo guardar el archivo.") }
    public static func idReportRow(shape: String, prefix: String, place: String, file: String, repo: Int,
                                   ids: Int, mentions: Int, recognised: Bool, resolved: Bool) -> String {
        let pre = prefix.isEmpty ? "" : t(" with prefix “\(prefix)”", " con prefijo «\(prefix)»")
        let status = !recognised ? t("Lupita does not recognise this", "Lupita no lo reconoce")
            : resolved ? t("Lupita finds it", "Lupita lo encuentra") : t("Lupita finds no definition", "Lupita no encuentra su definición")
        let count = recognised
            ? t("\(ids) \(ids == 1 ? "ID" : "IDs"), cited \(mentions)×", "\(ids) \(ids == 1 ? "ID" : "IDs"), citados \(mentions)×")
            : t("appears \(mentions)×", "aparece \(mentions)×")
        return t("Shape \(shape)\(pre), written in \(place) · \(file) · repo \(repo) · \(count) · \(status)",
                 "Forma \(shape)\(pre), escrito en \(place) · \(file) · repo \(repo) · \(count) · \(status)")
    }
    public static func place(_ p: String) -> String {
        switch p {
        case "heading": t("a heading", "un encabezado")
        case "table": t("a table", "una tabla")
        case "list": t("a list", "una lista")
        case "fileName": t("a file name", "un nombre de archivo")
        case "frontmatter": t("frontmatter", "el frontmatter")
        default: t("running text", "texto corrido")
        }
    }

    // MARK: Appearance window (D55)
    public static var appearanceMenu: String { t("Appearance…", "Aspecto…") }
    public static var appearanceTitle: String { t("Appearance", "Aspecto") }
    public static var appearanceTheme: String { t("Theme", "Tema") }
    public static var appearanceMode: String { t("Mode", "Modo") }
    public static var appearanceSize: String { t("Size", "Tamaño") }
    public static var appearanceDensity: String { t("Density", "Densidad") }
    public static var appearanceSample: String { t("Sample", "Muestra") }
    public static var appearancePrevious: String { t("Previous theme", "Tema anterior") }
    public static var appearanceNext: String { t("Next theme", "Tema siguiente") }
    public static var modeSystem: String { t("System", "Sistema") }
    public static var modeLight: String { t("Light", "Claro") }
    public static var modeDark: String { t("Dark", "Oscuro") }
    public static var densityCompact: String { t("Compact", "Compacta") }
    public static var densityNormal: String { t("Normal", "Normal") }
    public static var densityAiry: String { t("Airy", "Amplia") }

    // MARK: About, help, updates (D25)
    public static var about: String { t("About \(appName)", "Acerca de \(appName)") }
    public static var help: String { t("Help", "Ayuda") }
    public static var checkForUpdates: String { t("Check for updates…", "Buscar actualizaciones…") }
    public static func downloadUpdate(_ version: String) -> String { t("Download \(appName) \(version)…", "Descargar \(appName) \(version)…") }
    public static func upToDate(_ version: String) -> String { t("You're up to date (\(version))", "Estás al día (\(version))") }
    public static func newVersion(_ version: String) -> String { t("There is a new version: \(version)", "Hay una versión nueva: \(version)") }
    public static var download: String { t("Download", "Descargar") }
    public static var installAndRestart: String { t("Install and restart", "Instalar y reiniciar") }
    public static func installUpdate(_ version: String) -> String { t("Install \(appName) \(version)…", "Instalar \(appName) \(version)…") }
    public static var installing: String { t("Installing the update…", "Instalando la actualización…") }
    public static var permissionsKept: String {
        t("Your macOS permissions carry over: you don't need to grant them again.",
          "Los permisos de macOS se mantienen: no hace falta volver a darlos.")
    }
    public static var installFailed: String {
        t("Couldn't install the update. You can download it and replace the app by hand.",
          "No se pudo instalar la actualización. Puedes descargarla y sustituir la app a mano.")
    }
    public static var updateCheckFailed: String {
        t("Couldn't check for updates. Check your connection and try again.", "No se pudo buscar actualizaciones. Revisa tu conexión y vuelve a intentarlo.")
    }
}
