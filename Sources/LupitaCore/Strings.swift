import Foundation

/// Every user-facing text, in English and Spanish. Spanish when the Mac's first preferred
/// language is Spanish, English otherwise. The app name lives here only, so a rename is one line.
public enum S {
    public static let appName = "Lupita"

    /// The Mac's first preferred language; settable for tests.
    nonisolated(unsafe) public static var language = Locale.preferredLanguages.first ?? "en"
    static var isSpanish: Bool { language.hasPrefix("es") }
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
    public static var lens: String { t("Lens while holding", "Lupa al mantener") }
    public static var folders: String { t("Folders", "Carpetas") }
    public static var remove: String { t("Remove", "Quitar") }
    public static var addFolder: String { t("Add folder…", "Añadir carpeta…") }
    public static var add: String { t("Add", "Añadir") }
    public static var reindex: String { t("Reindex", "Reindexar") }
    public static var accessibility: String { t("Accessibility", "Accesibilidad") }
    public static var screenRecording: String { t("Screen Recording (OCR)", "Grabación de pantalla (OCR)") }
    public static func grant(_ permission: String) -> String { t("Grant \(permission)…", "Conceder \(permission)…") }
    public static var quit: String { t("Quit", "Salir") }

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
}

