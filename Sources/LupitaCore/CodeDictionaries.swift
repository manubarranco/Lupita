import Foundation

/// The fixed dictionaries of D29 (types 4 and 5), in the languages `Strings.swift` has. They live in code,
/// not in a resource file: a SwiftPM resource bundle has to travel next to the executable (the CLI, the tests
/// and `bundle.sh` would each need to copy it) and a missing bundle crashes at launch.
enum CodeDictionaries {
    struct Entry {
        /// `git status`, `rm`, `ENOENT`, `<dialog>`.
        let key: String
        let en: String
        let es: String
        /// Recognised on its own, without backticks: a name nobody uses as an ordinary word (`git`, `chmod`).
        var safe = true
        var text: String { S.isSpanish ? es : en }
    }

    // MARK: Terminal commands

    static let commands: [String: Entry] = Dictionary(uniqueKeysWithValues: commandList.map { ($0.key, $0) })

    static let commandList: [Entry] = [
        // git
        Entry(key: "git", en: "Git: keeps the history of a project's files.", es: "Git: guarda el historial de los archivos de un proyecto."),
        Entry(key: "git status", en: "Shows which files changed and what is ready to commit.", es: "Muestra qué archivos cambiaron y qué está listo para commitear."),
        Entry(key: "git add", en: "Marks changed files to go into the next commit.", es: "Marca archivos cambiados para que entren en el próximo commit."),
        Entry(key: "git commit", en: "Saves the marked changes as a commit in the history.", es: "Guarda los cambios marcados como un commit en el historial."),
        Entry(key: "git push", en: "Uploads your commits to the remote repository.", es: "Sube tus commits al repositorio remoto."),
        Entry(key: "git pull", en: "Downloads new commits from the remote and merges them into your branch.", es: "Baja los commits nuevos del remoto y los une a tu rama."),
        Entry(key: "git fetch", en: "Downloads the remote's news without changing your files.", es: "Baja las novedades del remoto sin tocar tus archivos."),
        Entry(key: "git clone", en: "Copies a remote repository to this computer.", es: "Copia un repositorio remoto a este ordenador."),
        Entry(key: "git init", en: "Starts a new git repository in this folder.", es: "Crea un repositorio git nuevo en esta carpeta."),
        Entry(key: "git checkout", en: "Switches to another branch or commit (or restores a file).", es: "Cambia a otra rama o commit (o restaura un archivo)."),
        Entry(key: "git switch", en: "Switches to another branch.", es: "Cambia a otra rama."),
        Entry(key: "git branch", en: "Lists, creates or deletes branches.", es: "Lista, crea o borra ramas."),
        Entry(key: "git merge", en: "Joins another branch's commits into the current one.", es: "Une los commits de otra rama a la actual."),
        Entry(key: "git rebase", en: "Replays your commits on top of another branch, rewriting them.", es: "Reaplica tus commits encima de otra rama, reescribiéndolos."),
        Entry(key: "git stash", en: "Sets your unfinished changes aside to come back to them later.", es: "Aparta tus cambios sin terminar para recuperarlos después."),
        Entry(key: "git diff", en: "Shows exactly which lines changed.", es: "Muestra qué líneas cambiaron exactamente."),
        Entry(key: "git log", en: "Lists the commits of the history.", es: "Lista los commits del historial."),
        Entry(key: "git show", en: "Shows one commit: message and changes.", es: "Muestra un commit: mensaje y cambios."),
        Entry(key: "git reset", en: "Moves the branch back to another commit.", es: "Mueve la rama a otro commit anterior."),
        Entry(key: "git restore", en: "Brings a file back to how it was in the last commit.", es: "Devuelve un archivo a como estaba en el último commit."),
        Entry(key: "git revert", en: "Makes a new commit that undoes an earlier one.", es: "Crea un commit nuevo que deshace uno anterior."),
        Entry(key: "git tag", en: "Puts a name (such as a version) on a commit.", es: "Pone un nombre (como una versión) a un commit."),
        Entry(key: "git cherry-pick", en: "Copies one commit from another branch onto this one.", es: "Copia un commit de otra rama a esta."),
        Entry(key: "git worktree", en: "Opens another branch in a separate folder, at the same time.", es: "Abre otra rama en una carpeta aparte, a la vez."),
        Entry(key: "git remote", en: "Shows or changes where the remote repository lives.", es: "Muestra o cambia dónde está el repositorio remoto."),
        Entry(key: "git mv", en: "Moves or renames a file, keeping its history.", es: "Mueve o renombra un archivo conservando su historial."),
        Entry(key: "git rm", en: "Deletes a file and records the deletion.", es: "Borra un archivo y lo registra."),
        Entry(key: "git blame", en: "Shows who last changed each line.", es: "Muestra quién cambió por última vez cada línea."),
        Entry(key: "git clean", en: "Deletes files that git does not track.", es: "Borra los archivos que git no sigue."),
        // shell
        Entry(key: "cd", en: "Moves into a folder.", es: "Entra en una carpeta."),
        Entry(key: "ls", en: "Lists the files of a folder.", es: "Lista los archivos de una carpeta."),
        Entry(key: "pwd", en: "Prints the folder you are in.", es: "Muestra la carpeta en la que estás."),
        Entry(key: "mkdir", en: "Creates a folder.", es: "Crea una carpeta."),
        Entry(key: "rm", en: "Deletes files. There is no trash: they are gone.", es: "Borra archivos. No hay papelera: se pierden."),
        Entry(key: "mv", en: "Moves or renames a file or folder.", es: "Mueve o renombra un archivo o carpeta."),
        Entry(key: "cp", en: "Copies a file or folder.", es: "Copia un archivo o carpeta."),
        Entry(key: "chmod", en: "Changes who may read, write or run a file.", es: "Cambia quién puede leer, escribir o ejecutar un archivo."),
        Entry(key: "curl", en: "Downloads from, or talks to, a web address from the terminal.", es: "Descarga de una dirección web, o habla con ella, desde la terminal."),
        Entry(key: "grep", en: "Searches for text inside files.", es: "Busca texto dentro de archivos."),
        Entry(key: "sudo", en: "Runs the command as administrator.", es: "Ejecuta el comando como administrador."),
        Entry(key: "ssh", en: "Opens a terminal on another computer over the network.", es: "Abre una terminal en otro ordenador por la red."),
        Entry(key: "lsof", en: "Lists open files and ports, e.g. who is using a port.", es: "Lista archivos y puertos abiertos, p. ej. quién usa un puerto."),
        Entry(key: "brew install", en: "Installs a program with Homebrew.", es: "Instala un programa con Homebrew."),
        Entry(key: "brew", en: "Homebrew: installs programs on a Mac.", es: "Homebrew: instala programas en un Mac.", safe: false),
        Entry(key: "python3", en: "Runs a Python program.", es: "Ejecuta un programa de Python."),
        Entry(key: "pip3", en: "Installs Python packages.", es: "Instala paquetes de Python."),
        Entry(key: "pip", en: "Installs Python packages.", es: "Instala paquetes de Python."),
        Entry(key: "xcodebuild", en: "Builds an Xcode project from the terminal.", es: "Compila un proyecto de Xcode desde la terminal."),
        Entry(key: "node", en: "Runs a JavaScript program.", es: "Ejecuta un programa de JavaScript.", safe: false),
        Entry(key: "swift build", en: "Compiles a Swift package.", es: "Compila un paquete de Swift.", safe: false),
        Entry(key: "swift test", en: "Runs a Swift package's tests.", es: "Ejecuta las pruebas de un paquete de Swift.", safe: false),
        Entry(key: "swift", en: "Runs or compiles Swift code.", es: "Ejecuta o compila código Swift.", safe: false),
        Entry(key: "make", en: "Runs the build recipes of a Makefile.", es: "Ejecuta las recetas de compilación de un Makefile.", safe: false),
        Entry(key: "open", en: "Opens a file, folder or address with its default app.", es: "Abre un archivo, carpeta o dirección con su app por defecto.", safe: false),
        Entry(key: "cat", en: "Prints a file's content.", es: "Muestra el contenido de un archivo.", safe: false),
        Entry(key: "find", en: "Looks for files by name or kind.", es: "Busca archivos por nombre o tipo.", safe: false),
        Entry(key: "touch", en: "Creates an empty file.", es: "Crea un archivo vacío.", safe: false),
        Entry(key: "echo", en: "Prints text.", es: "Muestra un texto.", safe: false),
        Entry(key: "kill", en: "Stops a running process.", es: "Detiene un proceso en marcha.", safe: false),
        Entry(key: "head", en: "Prints the first lines of a file.", es: "Muestra las primeras líneas de un archivo.", safe: false),
        Entry(key: "tail", en: "Prints the last lines of a file.", es: "Muestra las últimas líneas de un archivo.", safe: false),
        Entry(key: "tar", en: "Packs or unpacks a bundle of files.", es: "Empaqueta o desempaqueta un conjunto de archivos.", safe: false),
        Entry(key: "export", en: "Sets a variable for the programs you start next.", es: "Fija una variable para los programas que lances después.", safe: false),
        Entry(key: "which", en: "Shows where a command lives on this computer.", es: "Muestra dónde está un comando en este ordenador.", safe: false),
        Entry(key: "npx", en: "Runs a package's command without installing it for good.", es: "Ejecuta el comando de un paquete sin instalarlo para siempre."),
    ]

    /// Subcommands shared by npm, pnpm, yarn and bun.
    static let packageCommands: [String: (en: String, es: String)] = [
        "install": ("Installs the project's packages.", "Instala los paquetes del proyecto."),
        "i": ("Installs the project's packages.", "Instala los paquetes del proyecto."),
        "ci": ("Installs exactly the packages in the lock file; for clean, repeatable builds.", "Instala exactamente los paquetes del archivo de bloqueo; para compilaciones limpias y repetibles."),
        "test": ("Runs the project's tests.", "Ejecuta las pruebas del proyecto."),
        "start": ("Starts the project.", "Arranca el proyecto."),
        "audit": ("Checks the packages for known security problems.", "Revisa si los paquetes tienen problemas de seguridad conocidos."),
        "update": ("Updates the packages to their newest allowed versions.", "Actualiza los paquetes a sus versiones más nuevas permitidas."),
        "outdated": ("Lists packages that have a newer version.", "Lista los paquetes que tienen una versión más nueva."),
        "init": ("Creates a new package.json.", "Crea un package.json nuevo."),
        "publish": ("Publishes the package so others can install it.", "Publica el paquete para que otros lo instalen."),
        "uninstall": ("Removes a package from the project.", "Quita un paquete del proyecto."),
        "add": ("Adds a package to the project.", "Añade un paquete al proyecto."),
        "remove": ("Removes a package from the project.", "Quita un paquete del proyecto."),
        "run": ("Runs one of the scripts of package.json.", "Ejecuta uno de los scripts del package.json."),
        "exec": ("Runs a package's command.", "Ejecuta el comando de un paquete."),
    ]

    static let managers: Set<String> = ["npm", "pnpm", "yarn", "bun"]

    /// Words that make a command more careful: shown under the description.
    static let flagNotes: [String: (en: String, es: String)] = [
        "--hard": ("--hard throws away every uncommitted change.", "--hard descarta todos los cambios sin commitear."),
        "--force": ("--force overwrites what is on the other side.", "--force sobrescribe lo que hay al otro lado."),
        "-f": ("-f forces it, skipping the safety checks.", "-f lo fuerza, saltándose las comprobaciones."),
        "-rf": ("-rf deletes folders and everything in them without asking.", "-rf borra carpetas y todo lo que contienen sin preguntar."),
        "-fr": ("-fr deletes folders and everything in them without asking.", "-fr borra carpetas y todo lo que contienen sin preguntar."),
        "-r": ("-r goes into folders too.", "-r también entra en las carpetas."),
        "-A": ("-A takes every changed file.", "-A toma todos los archivos cambiados."),
        "--all": ("--all takes every changed file.", "--all toma todos los archivos cambiados."),
        "-b": ("-b creates the branch as it switches.", "-b crea la rama al cambiar."),
        "-m": ("-m gives the message on the spot.", "-m da el mensaje en el momento."),
        "--amend": ("--amend rewrites the last commit.", "--amend reescribe el último commit."),
        "--no-verify": ("--no-verify skips the checks before committing.", "--no-verify se salta las comprobaciones antes de commitear."),
        "--rebase": ("--rebase replays your commits instead of merging.", "--rebase reaplica tus commits en vez de unir."),
        "-D": ("-D deletes even if not merged.", "-D borra aunque no esté fusionada."),
    ]

    // MARK: Errors

    static let errors: [String: Entry] = Dictionary(uniqueKeysWithValues: errorList.map { ($0.key, $0) })

    static let errorList: [Entry] = [
        Entry(key: "ENOENT", en: "No such file or folder: the path does not exist.", es: "No existe ese archivo o carpeta: la ruta no existe."),
        Entry(key: "EACCES", en: "Permission denied: this user may not do that.", es: "Permiso denegado: este usuario no puede hacer eso."),
        Entry(key: "EPERM", en: "Operation not permitted by the system.", es: "El sistema no permite esa operación."),
        Entry(key: "EADDRINUSE", en: "The port is already taken by another program.", es: "El puerto ya lo usa otro programa."),
        Entry(key: "EEXIST", en: "The file or folder already exists.", es: "El archivo o carpeta ya existe."),
        Entry(key: "ECONNREFUSED", en: "Nothing is listening at that address: the server is off.", es: "Nada escucha en esa dirección: el servidor está apagado."),
        Entry(key: "ECONNRESET", en: "The other side closed the connection abruptly.", es: "El otro lado cortó la conexión de golpe."),
        Entry(key: "ETIMEDOUT", en: "The connection took too long and gave up.", es: "La conexión tardó demasiado y se abandonó."),
        Entry(key: "ENOTFOUND", en: "The address name could not be resolved: wrong host or no network.", es: "No se pudo resolver el nombre de la dirección: servidor equivocado o sin red."),
        Entry(key: "EISDIR", en: "It is a folder, but a file was expected.", es: "Es una carpeta, pero se esperaba un archivo."),
        Entry(key: "ENOTDIR", en: "It is a file, but a folder was expected.", es: "Es un archivo, pero se esperaba una carpeta."),
        Entry(key: "EMFILE", en: "Too many files open at once.", es: "Hay demasiados archivos abiertos a la vez."),
        Entry(key: "ENOSPC", en: "The disk is full.", es: "El disco está lleno."),
        Entry(key: "MODULE_NOT_FOUND", en: "Node cannot find a package or file it was asked to load.", es: "Node no encuentra un paquete o archivo que le pidieron cargar."),
        Entry(key: "ERR_MODULE_NOT_FOUND", en: "Node cannot find a package or file it was asked to import.", es: "Node no encuentra un paquete o archivo que le pidieron importar."),
        Entry(key: "TypeError", en: "A value is not of the kind the code needs (e.g. calling something that is not a function).", es: "Un valor no es del tipo que el código necesita (p. ej. llamar a algo que no es una función)."),
        Entry(key: "ReferenceError", en: "The code uses a name that does not exist.", es: "El código usa un nombre que no existe."),
        Entry(key: "SyntaxError", en: "The code is written wrongly and cannot be read.", es: "El código está mal escrito y no se puede leer."),
        Entry(key: "RangeError", en: "A number is outside the allowed range.", es: "Un número está fuera del rango permitido."),
        Entry(key: "AbortError", en: "The operation was cancelled on purpose before it finished.", es: "La operación se canceló a propósito antes de terminar."),
        Entry(key: "NotAllowedError", en: "The browser refused: the user or the page did not give permission.", es: "El navegador lo rechazó: el usuario o la página no dio permiso."),
        Entry(key: "SecurityError", en: "The browser blocked it for security reasons.", es: "El navegador lo bloqueó por seguridad."),
        Entry(key: "NetworkError", en: "The network request failed.", es: "Falló la petición de red."),
        Entry(key: "QuotaExceededError", en: "The browser's storage is full.", es: "El almacenamiento del navegador está lleno."),
        Entry(key: "TimeoutError", en: "The operation took longer than allowed.", es: "La operación tardó más de lo permitido."),
        Entry(key: "KeyError", en: "Python: that key is not in the dictionary.", es: "Python: esa clave no está en el diccionario."),
        Entry(key: "ValueError", en: "Python: the value is of the right kind but not acceptable.", es: "Python: el valor es del tipo correcto pero no es aceptable."),
        Entry(key: "AttributeError", en: "Python: the object has no such attribute or method.", es: "Python: el objeto no tiene ese atributo o método."),
        Entry(key: "ImportError", en: "Python: a module could not be imported.", es: "Python: no se pudo importar un módulo."),
        Entry(key: "ModuleNotFoundError", en: "Python: the module is not installed or the name is wrong.", es: "Python: el módulo no está instalado o el nombre es incorrecto."),
        Entry(key: "IndexError", en: "Python: the position is past the end of the list.", es: "Python: la posición está más allá del final de la lista."),
        Entry(key: "NameError", en: "Python: the code uses a name that does not exist.", es: "Python: el código usa un nombre que no existe."),
        Entry(key: "ZeroDivisionError", en: "Python: a division by zero.", es: "Python: una división entre cero."),
        Entry(key: "FileNotFoundError", en: "Python: the file does not exist.", es: "Python: el archivo no existe."),
        Entry(key: "PermissionError", en: "Python: this user may not do that.", es: "Python: este usuario no puede hacer eso."),
        Entry(key: "NotImplementedError", en: "That part has not been written yet.", es: "Esa parte todavía no está escrita."),
        Entry(key: "AssertionError", en: "A check that had to be true was false.", es: "Una comprobación que debía cumplirse falló."),
        Entry(key: "RuntimeError", en: "Python: a problem found while running that fits no other kind.", es: "Python: un problema al ejecutar que no encaja en otro tipo."),
        Entry(key: "IndentationError", en: "Python: the spaces at the start of a line are wrong.", es: "Python: los espacios al inicio de una línea están mal."),
        Entry(key: "RecursionError", en: "Python: a function called itself too many times.", es: "Python: una función se llamó a sí misma demasiadas veces."),
        Entry(key: "UnicodeDecodeError", en: "Python: the bytes are not valid text in that encoding.", es: "Python: los bytes no son texto válido en esa codificación."),
        Entry(key: "KeyboardInterrupt", en: "Python: stopped by the user with Ctrl+C.", es: "Python: el usuario lo detuvo con Ctrl+C."),
    ]

    /// HTTP status codes: only recognised with a hint that the number is a status (D29).
    static let httpStatus: [Int: Entry] = Dictionary(uniqueKeysWithValues: httpList.map { (Int($0.key)!, $0) })

    static let httpList: [Entry] = [
        Entry(key: "200", en: "200 OK: the request worked.", es: "200 OK: la petición funcionó."),
        Entry(key: "201", en: "201 Created: the request worked and made something new.", es: "201 Created: la petición funcionó y creó algo nuevo."),
        Entry(key: "204", en: "204 No Content: it worked and there is nothing to send back.", es: "204 No Content: funcionó y no hay nada que devolver."),
        Entry(key: "301", en: "301 Moved Permanently: this address has a new home.", es: "301 Moved Permanently: esta dirección tiene un hogar nuevo."),
        Entry(key: "302", en: "302 Found: temporarily redirected to another address.", es: "302 Found: redirigido temporalmente a otra dirección."),
        Entry(key: "304", en: "304 Not Modified: nothing changed, use your saved copy.", es: "304 Not Modified: no cambió nada, usa tu copia guardada."),
        Entry(key: "400", en: "400 Bad Request: the server could not understand what was sent.", es: "400 Bad Request: el servidor no entendió lo que se envió."),
        Entry(key: "401", en: "401 Unauthorized: you are not signed in or the login is wrong.", es: "401 Unauthorized: no has iniciado sesión o el acceso es incorrecto."),
        Entry(key: "403", en: "403 Forbidden: you are known, but not allowed in.", es: "403 Forbidden: te conoce, pero no te deja entrar."),
        Entry(key: "404", en: "404 Not Found: nothing exists at that address.", es: "404 Not Found: no hay nada en esa dirección."),
        Entry(key: "405", en: "405 Method Not Allowed: that address does not accept this kind of request.", es: "405 Method Not Allowed: esa dirección no acepta este tipo de petición."),
        Entry(key: "409", en: "409 Conflict: the request clashes with the current state.", es: "409 Conflict: la petición choca con el estado actual."),
        Entry(key: "422", en: "422 Unprocessable Content: understood, but the data is not valid.", es: "422 Unprocessable Content: se entendió, pero los datos no son válidos."),
        Entry(key: "429", en: "429 Too Many Requests: slow down, the limit was reached.", es: "429 Too Many Requests: más despacio, se alcanzó el límite."),
        Entry(key: "500", en: "500 Internal Server Error: the server failed on its own.", es: "500 Internal Server Error: el servidor falló por su cuenta."),
        Entry(key: "502", en: "502 Bad Gateway: a server in the middle got a bad answer.", es: "502 Bad Gateway: un servidor intermedio recibió una mala respuesta."),
        Entry(key: "503", en: "503 Service Unavailable: the server is down or overloaded.", es: "503 Service Unavailable: el servidor está caído o saturado."),
        Entry(key: "504", en: "504 Gateway Timeout: a server in the middle waited too long.", es: "504 Gateway Timeout: un servidor intermedio esperó demasiado."),
    ]

    // MARK: HTML tags

    static let tags: [String: Entry] = Dictionary(uniqueKeysWithValues: tagList.map { ($0.key, $0) })

    static let tagList: [Entry] = [
        Entry(key: "div", en: "A generic box to group things; it shows nothing by itself.", es: "Una caja genérica para agrupar cosas; no muestra nada por sí sola."),
        Entry(key: "span", en: "A generic piece of text inside a line, to style or mark it.", es: "Un trozo genérico de texto dentro de una línea, para darle estilo o marcarlo."),
        Entry(key: "p", en: "A paragraph.", es: "Un párrafo."),
        Entry(key: "a", en: "A link to another page or place.", es: "Un enlace a otra página o lugar."),
        Entry(key: "img", en: "An image.", es: "Una imagen."),
        Entry(key: "ul", en: "A bulleted list.", es: "Una lista con viñetas."),
        Entry(key: "ol", en: "A numbered list.", es: "Una lista numerada."),
        Entry(key: "li", en: "One item of a list.", es: "Un elemento de una lista."),
        Entry(key: "h1", en: "The main heading of the page.", es: "El título principal de la página."),
        Entry(key: "h2", en: "A section heading.", es: "El título de una sección."),
        Entry(key: "h3", en: "A subsection heading.", es: "El título de una subsección."),
        Entry(key: "h4", en: "A small heading.", es: "Un título pequeño."),
        Entry(key: "h5", en: "A smaller heading.", es: "Un título más pequeño."),
        Entry(key: "h6", en: "The smallest heading.", es: "El título más pequeño."),
        Entry(key: "button", en: "A button you can click.", es: "Un botón en el que se puede hacer clic."),
        Entry(key: "input", en: "A field where the user types or picks something.", es: "Un campo donde el usuario escribe o elige algo."),
        Entry(key: "textarea", en: "A box for typing several lines of text.", es: "Una caja para escribir varias líneas de texto."),
        Entry(key: "select", en: "A drop-down list of choices.", es: "Una lista desplegable de opciones."),
        Entry(key: "form", en: "A group of fields that are sent together.", es: "Un grupo de campos que se envían juntos."),
        Entry(key: "label", en: "The text that names a form field.", es: "El texto que nombra un campo de formulario."),
        Entry(key: "table", en: "A table of rows and columns.", es: "Una tabla de filas y columnas."),
        Entry(key: "nav", en: "A block of navigation links.", es: "Un bloque de enlaces de navegación."),
        Entry(key: "header", en: "The top part of a page or section.", es: "La parte de arriba de una página o sección."),
        Entry(key: "footer", en: "The bottom part of a page or section.", es: "La parte de abajo de una página o sección."),
        Entry(key: "main", en: "The main content of the page.", es: "El contenido principal de la página."),
        Entry(key: "section", en: "A thematic section of a page.", es: "Una sección temática de una página."),
        Entry(key: "article", en: "A piece of content that stands on its own, like a post.", es: "Un contenido que se entiende solo, como una entrada."),
        Entry(key: "aside", en: "Content on the side, related but not essential.", es: "Contenido al margen, relacionado pero no esencial."),
        Entry(key: "dialog", en: "A pop-up window (a dialog box) on top of the page.", es: "Una ventana emergente (un cuadro de diálogo) sobre la página."),
        Entry(key: "details", en: "A block the reader can open and close.", es: "Un bloque que el lector puede abrir y cerrar."),
        Entry(key: "summary", en: "The always-visible title of a details block.", es: "El título siempre visible de un bloque details."),
        Entry(key: "video", en: "A video player.", es: "Un reproductor de vídeo."),
        Entry(key: "audio", en: "An audio player.", es: "Un reproductor de audio."),
        Entry(key: "canvas", en: "A blank area that code draws on.", es: "Un área en blanco sobre la que el código dibuja."),
        Entry(key: "svg", en: "A drawing made of shapes that scales without blurring.", es: "Un dibujo hecho de formas que escala sin perder nitidez."),
        Entry(key: "iframe", en: "Another web page shown inside this one.", es: "Otra página web mostrada dentro de esta."),
        Entry(key: "script", en: "Code that runs in the page.", es: "Código que se ejecuta en la página."),
        Entry(key: "style", en: "The look rules (CSS) of the page.", es: "Las reglas de aspecto (CSS) de la página."),
        Entry(key: "link", en: "Connects the page to another file, usually its styles.", es: "Conecta la página con otro archivo, normalmente sus estilos."),
        Entry(key: "meta", en: "Information about the page that is not shown, such as its encoding.", es: "Información sobre la página que no se muestra, como su codificación."),
        Entry(key: "head", en: "The hidden part of the page: title, styles and settings.", es: "La parte oculta de la página: título, estilos y ajustes."),
        Entry(key: "body", en: "The visible part of the page.", es: "La parte visible de la página."),
        Entry(key: "html", en: "The root: everything on the page lives inside it.", es: "La raíz: todo lo de la página vive dentro."),
        Entry(key: "br", en: "A line break.", es: "Un salto de línea."),
        Entry(key: "hr", en: "A horizontal dividing line.", es: "Una línea horizontal divisoria."),
        Entry(key: "template", en: "A piece of markup kept aside, not shown until code uses it.", es: "Un trozo de marcado guardado aparte, que no se muestra hasta que el código lo usa."),
        Entry(key: "figure", en: "An image or diagram with its caption.", es: "Una imagen o diagrama con su pie."),
        Entry(key: "picture", en: "An image with alternatives for different screens.", es: "Una imagen con alternativas para distintas pantallas."),
        Entry(key: "title", en: "The page's name, shown in the browser tab.", es: "El nombre de la página, que se ve en la pestaña del navegador."),
    ]
}
