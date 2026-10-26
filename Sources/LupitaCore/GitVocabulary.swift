import Foundation

/// The git vocabulary package (D42): what agents and colleagues say about git in prose, explained in plain
/// language for people who do not read a terminal. Fixed table in code (D32), no index, no language model
/// (D26). The first of the «vocabulary between trades» packages: it works from the first minute, whatever
/// glossaries the user has.
public enum GitVocabulary {
    /// The menu switch «Git». The app sets it at launch and when the switch moves.
    public static var isEnabled: Bool {
        get { TermPackages.isOn(.git) }
        set { TermPackages.set(.git, on: newValue) }
    }

    struct Alias {
        let text: String
        /// Never ordinary English or Spanish (`rebase`, `stash`, `pushear`): counts on its own. A weak alias
        /// (`push`, `main`, `rama`) counts only with another word of the package in the same block of text, or
        /// between backticks.
        var strong = true
        /// Matched as written (`HEAD`, `PR`, `CI`), not folded to lower case.
        var exact = false
    }

    struct Term {
        /// Shown over the explanation.
        let names: String
        let en: String
        let es: String
        let seenEn: String
        let seenEs: String
        let aliases: [Alias]
    }

    // MARK: Word forms

    /// `push` → pushes, pushed, pushing. `double` repeats the last letter (`commit` → committed).
    static func english(_ base: String, double: Bool = false) -> [String] {
        let stem = double ? base + String(base.last!) : base
        if base.hasSuffix("e") { return [base, base + "s", base + "d", String(base.dropLast()) + "ing"] }
        if base.hasSuffix("sh") || base.hasSuffix("ch") { return [base, base + "es", base + "ed", base + "ing"] }
        return [base, base + "s", stem + "ed", stem + "ing"]
    }

    /// `pushear` → pushear, pusheo, pushea, pusheado, pusheé… (regular -ar verb).
    static func spanish(_ infinitive: String) -> [String] {
        let stem = String(infinitive.dropLast(2))
        let endings = ["ar", "o", "as", "a", "amos", "an", "ado", "ada", "ados", "adas", "ando", "é", "ó", "aron", "aré", "ará", "arán", "aba"]
        return endings.map { stem + $0 }
    }

    static func strong(_ words: [String]) -> [Alias] { words.map { Alias(text: $0) } }
    static func weak(_ words: [String]) -> [Alias] { words.map { Alias(text: $0, strong: false) } }

    // MARK: The 40 terms (validated by Manu, 2026-10-25; rewritten 2026-10-26 so no line leans on another git word)

    static let terms: [Term] = [
        Term(names: "repo · repositorio",
             en: "A project's folder that also remembers every saved version.", es: "La carpeta de un proyecto, que además recuerda cada versión guardada.",
             seenEn: "“clone the repo”", seenEs: "«clona el repo»",
             aliases: weak(["repo", "repos", "repositorio", "repositorios", "repository", "repositories"])),
        Term(names: "commit · commitear",
             en: "A save of the project: a snapshot of the changes with a note on what was done.", es: "Un guardado del proyecto: una foto de los cambios con una nota de qué se hizo.",
             seenEn: "“I'll commit it and let you know”", seenEs: "«lo commiteo y te aviso»",
             aliases: weak(english("commit", double: true)) + strong(spanish("commitear"))),
        Term(names: "rama · branch",
             en: "A parallel version of the project, to work without touching the main one.", es: "Una versión paralela del proyecto, para trabajar sin tocar la principal.",
             seenEn: "“it's on its own branch”", seenEs: "«está en su rama»",
             aliases: weak(["rama", "ramas", "branch", "branches"])),
        Term(names: "main · master",
             en: "The project's main version, the one that counts.", es: "La versión principal del proyecto, la que vale.",
             seenEn: "“it's already in main”", seenEs: "«ya está en main»",
             aliases: weak(["main", "master"])),
        Term(names: "remoto · origin · remote",
             en: "The project's copy online (usually GitHub), the one the team shares.", es: "La copia del proyecto en internet (normalmente GitHub), la que comparte el equipo.",
             seenEn: "“push it to origin”", seenEs: "«súbelo a origin»",
             aliases: weak(["remoto", "remotos", "origin", "remote", "remotes"])),
        Term(names: "clonar · clone",
             en: "Download a copy of the project, with all its versions, to your computer.", es: "Bajar a tu ordenador una copia del proyecto con todas sus versiones.",
             seenEn: "when you start on a project", seenEs: "al empezar en un proyecto",
             aliases: weak(spanish("clonar") + english("clone"))),
        Term(names: "diff",
             en: "What changed between two versions, line by line: what was removed and what was added.", es: "Lo que cambió entre dos versiones, línea a línea: lo quitado y lo añadido.",
             seenEn: "“look at the diff”", seenEs: "«mira el diff»",
             aliases: weak(["diff", "diffs"])),
        Term(names: "historial · log",
             en: "The list of every save of the project, with who made it and when.", es: "La lista de todos los guardados del proyecto, con quién y cuándo.",
             seenEn: "“look for it in the log”", seenEs: "«búscalo en el log»",
             aliases: weak(["historial", "log", "logs"])),
        Term(names: "push · pushear",
             en: "Upload your saves to the project's copy online.", es: "Subir tus guardados a la copia del proyecto en internet.",
             seenEn: "“I've already pushed it”", seenEs: "«ya lo he pusheado»",
             aliases: weak(english("push")) + strong(spanish("pushear"))),
        Term(names: "pull",
             en: "Download what's new from the online copy and add it to your work.", es: "Bajar lo nuevo de la copia en internet y juntarlo con tu trabajo.",
             seenEn: "“pull before you start”", seenEs: "«haz pull antes de empezar»",
             aliases: weak(english("pull")) + strong(spanish("pullear"))),
        Term(names: "fetch",
             en: "Check for anything new in the online copy, without changing your files.", es: "Mirar si hay algo nuevo en la copia en internet, sin cambiar tus archivos.",
             seenEn: "agent notices", seenEs: "avisos del agente",
             aliases: weak(english("fetch")) + strong(spanish("fetchear"))),
        Term(names: "upstream",
             en: "The online version yours is compared and kept in step with.", es: "La versión en internet con la que se compara y sincroniza la tuya.",
             seenEn: "“it has no upstream”", seenEs: "«no tiene upstream»",
             aliases: strong(["upstream"])),
        Term(names: "ahead · behind",
             en: "How many saves you have that aren't online yet (ahead), or the other way round (behind).", es: "Cuántos guardados tienes que aún no están en internet (por delante), o al revés (por detrás).",
             seenEn: "“2 commits ahead”", seenEs: "«2 commits por delante»",
             aliases: weak(["ahead", "behind", "por delante", "por detrás"])),
        Term(names: "fork",
             en: "Your own copy of someone else's project, in your GitHub account.", es: "Tu copia propia del proyecto de otra persona, en tu cuenta de GitHub.",
             seenEn: "on GitHub", seenEs: "en GitHub",
             aliases: weak(english("fork")) + strong(spanish("forkear"))),
        Term(names: "merge · mergear",
             en: "Bring the work of a parallel version into another, usually the main one.", es: "Juntar el trabajo de una versión paralela en otra, normalmente en la principal.",
             seenEn: "“merge it into main”", seenEs: "«mergea a main»",
             aliases: weak(english("merge")) + strong(spanish("mergear"))),
        Term(names: "merge commit",
             en: "The save left behind as a mark that two versions were joined.", es: "El guardado que queda como marca de que se juntaron dos versiones.",
             seenEn: "in the history", seenEs: "en el historial",
             aliases: strong(["merge commit", "merge commits"])),
        Term(names: "fast-forward",
             en: "Joining with nothing to mix: the main version hadn't changed, so it just moves forward to the new work.", es: "Juntar sin mezclar nada: la principal no había cambiado y solo avanza hasta el trabajo nuevo.",
             seenEn: "“fast-forward merge”", seenEs: "«fast-forward merge»",
             aliases: strong(["fast-forward", "fast forward", "fast-forward merge", "fast-forwarded", "ff-only"])),
        Term(names: "conflicto · merge conflict",
             en: "Two people changed the same line; someone has to decide which one stays.", es: "Dos personas cambiaron la misma línea; alguien tiene que decidir cuál se queda.",
             seenEn: "“there are conflicts”", seenEs: "«hay conflictos»",
             aliases: weak(["conflicto", "conflictos", "conflict", "conflicts"])
                + strong(["merge conflict", "merge conflicts", "conflicto de merge", "conflictos de merge"])),
        Term(names: "rebase · rebasear",
             en: "Redo your work on top of the latest main version, as if you had started now.", es: "Rehacer tu trabajo encima de lo último de la principal, como si hubieras empezado ahora.",
             seenEn: "“rebase onto main”", seenEs: "«rebasea sobre main»",
             aliases: strong(english("rebase")) + strong(spanish("rebasear"))),
        Term(names: "rebase interactivo · interactive rebase",
             en: "Reorder, combine or fix your saves before showing them to anyone.", es: "Ordenar, juntar o corregir tus guardados antes de enseñarlos.",
             seenEn: "“clean up with an interactive rebase”", seenEs: "«limpia con un rebase interactivo»",
             aliases: strong(["interactive rebase", "rebase interactivo", "rebase interactive", "rebase -i", "rebase --interactive"])),
        Term(names: "squash",
             en: "Combine several saves into one.", es: "Juntar varios guardados en uno solo.",
             seenEn: "“squash and merge”", seenEs: "«squash and merge»",
             aliases: strong(english("squash") + spanish("squashear") + ["squash and merge", "squash & merge", "squash merge"])),
        Term(names: "cherry-pick",
             en: "Copy one specific save from one parallel version to another.", es: "Copiar un único guardado concreto de una versión paralela a otra.",
             seenEn: "“cherry-pick the fix”", seenEs: "«cherry-pickea el fix»",
             aliases: strong(english("cherry-pick") + spanish("cherry-pickear") + ["cherrypick", "cherry pick"])),
        Term(names: "PR · pull request",
             en: "A proposal of changes for someone to review before it joins the main version.", es: "Una propuesta de cambios para que alguien la revise antes de juntarla con la principal.",
             seenEn: "“opening a PR”", seenEs: "«abro PR»",
             aliases: [Alias(text: "PR", exact: true), Alias(text: "PRs", exact: true)] + strong(["pull request", "pull requests"])),
        Term(names: "review",
             en: "Someone else checks your proposed changes and approves them or asks for fixes.", es: "Otra persona revisa tu propuesta de cambios y la aprueba o pide arreglos.",
             seenEn: "“pending review”", seenEs: "«pendiente de review»",
             aliases: weak(["review", "reviews"])),
        Term(names: "stage · staging area",
             en: "The changes you've picked for the next save.", es: "Los cambios que has elegido para el próximo guardado.",
             seenEn: "“add it to the stage”", seenEs: "«añádelo al stage»",
             aliases: weak(["stage", "staged"]) + strong(["staging area"])),
        Term(names: "stash · stashear",
             en: "Put unfinished changes away in a drawer, to get them back later.", es: "Apartar cambios a medias en un cajón, para recuperarlos más tarde.",
             seenEn: "“I stash and switch branch”", seenEs: "«stasheo y cambio de rama»",
             aliases: strong(english("stash") + spanish("stashear"))),
        Term(names: "descartar cambios · discard",
             en: "Throw away changes you haven't saved yet; they can't be recovered.", es: "Tirar los cambios que aún no has guardado; no se pueden recuperar.",
             seenEn: "in VS Code", seenEs: "en VS Code",
             aliases: weak(english("discard")) + strong(["descartar cambios", "discard changes"])),
        Term(names: "amend",
             en: "Fix the last save instead of making a new one.", es: "Corregir el último guardado en lugar de hacer uno nuevo.",
             seenEn: "“I'll put it in with amend”", seenEs: "«lo meto con amend»",
             aliases: strong(english("amend"))),
        Term(names: "revert",
             en: "Undo an earlier save by adding one that does the opposite; nothing is deleted.", es: "Deshacer un guardado anterior añadiendo otro que hace lo contrario; no se borra nada.",
             seenEn: "“revert it”", seenEs: "«reviértelo»",
             aliases: weak(english("revert") + ["revertir", "revierte", "revierto", "revertí", "revertido"])),
        Term(names: "reset",
             en: "Go back to an earlier save, as if the later ones hadn't happened.", es: "Volver a un guardado anterior, como si los posteriores no se hubieran hecho.",
             seenEn: "“do a reset”", seenEs: "«haz un reset»",
             aliases: weak(["reset", "resets", "resetear", "resetea", "reseteo"])),
        Term(names: "reset --hard",
             en: "Go back to an earlier save and throw away everything unsaved. There's no undo.", es: "Volver a un guardado anterior y tirar todo lo que no estaba guardado. No tiene vuelta atrás.",
             seenEn: "when something broke", seenEs: "cuando algo se rompió",
             aliases: strong(["reset --hard", "reset hard"])),
        Term(names: "force push",
             en: "Upload your version and overwrite the one online, even if it has other people's work.", es: "Subir tu versión a internet y pisar la que había, aunque tenga trabajo de otros.",
             seenEn: "“I need a force push”", seenEs: "«necesito un force push»",
             aliases: strong(["force push", "force-push", "forcepush", "force pushed", "force-pushed", "push --force", "push -f", "push forzado"])),
        Term(names: "HEAD",
             en: "Where you are now: the version and the save you have open.", es: "Dónde estás ahora: la versión y el guardado que tienes abiertos.",
             seenEn: "git messages", seenEs: "mensajes de git",
             aliases: [Alias(text: "HEAD", exact: true)] + weak(["head"])),
        Term(names: "detached HEAD",
             en: "You're looking at an old save on its own; whatever you change there doesn't belong to any version.", es: "Estás mirando un guardado antiguo suelto; lo que cambies ahí no queda en ninguna versión.",
             seenEn: "notice when switching to a commit", seenEs: "aviso al cambiar de commit",
             aliases: strong(["detached head", "head desacoplado", "head separado"])),
        Term(names: "untracked",
             en: "New files that aren't being saved with the project's versions yet.", es: "Archivos nuevos que todavía no se guardan con las versiones del proyecto.",
             seenEn: "in `git status`", seenEs: "en `git status`",
             aliases: strong(["untracked", "untracked files"])),
        Term(names: "working tree clean · nothing to commit",
             en: "Everything is saved: there are no pending changes.", es: "Todo está guardado: no hay cambios pendientes.",
             seenEn: "“nothing to commit”", seenEs: "«nothing to commit»",
             aliases: strong(["working tree clean", "nothing to commit", "working directory clean"])),
        Term(names: "worktree",
             en: "Another folder with another parallel version of the same project, open at the same time.", es: "Otra carpeta con otra versión paralela del mismo proyecto, abierta a la vez.",
             seenEn: "with parallel agents", seenEs: "con agentes en paralelo",
             aliases: strong(["worktree", "worktrees", "work tree"])),
        Term(names: "tag",
             en: "A fixed label on a specific save, like “v1.0”.", es: "Una etiqueta fija en un guardado concreto, como «v1.0».",
             seenEn: "“v0.5.0”", seenEs: "«v0.5.0»",
             aliases: weak(["tag", "tags", "tagged", "tagging"])),
        Term(names: ".gitignore",
             en: "The list of files the project must never save (passwords, temporary files…).", es: "La lista de archivos que el proyecto no debe guardar nunca (contraseñas, archivos temporales…).",
             seenEn: "at the root of the repo", seenEs: "en la raíz del repo",
             aliases: strong([".gitignore", "gitignore"])),
        Term(names: "CI",
             en: "Automatic checks that run when changes are uploaded; red means something failed.", es: "Comprobaciones automáticas que se lanzan al subir cambios; en rojo, algo falla.",
             seenEn: "“CI is red”", seenEs: "«CI en rojo»",
             // Italic CI is read by the OCR as `C/` or `Cl`: only as a capital word on its own.
             aliases: [Alias(text: "CI", exact: true), Alias(text: "C/", exact: true), Alias(text: "Cl", exact: true)]),
    ]

    // MARK: Lookup tables

    struct Hit { let term: Int; let strong: Bool }

    private static let tables: (folded: [String: Hit], exact: [String: Hit], longest: Int) = {
        var folded: [String: Hit] = [:], exact: [String: Hit] = [:], longest = 1
        for (n, term) in terms.enumerated() {
            for alias in term.aliases {
                let hit = Hit(term: n, strong: alias.strong)
                if alias.exact { exact[alias.text] = hit; continue }
                let key = fold(alias.text)
                // A strong meaning is never replaced by a weak one (`merge commit` vs a plain `commit`).
                if let old = folded[key], old.strong, !alias.strong { continue }
                folded[key] = hit
                longest = max(longest, key.split(separator: " ").count)
            }
        }
        return (folded, exact, longest)
    }()

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    // MARK: Reading text

    struct Token {
        let text: String
        /// Ends in `. , ; : ! ? …`: a phrase does not go past it.
        let closes: Bool
    }

    static let wrappers = CharacterSet(charactersIn: "`\"'“”‘’«»()[]{}<>*¿¡")
    static let punctuation = CharacterSet(charactersIn: ".,;:!?…")

    static func tokens(_ text: String) -> [Token] {
        text.split(whereSeparator: \.isWhitespace).compactMap { piece in
            var s = String(piece).trimmingCharacters(in: wrappers)
            var closes = false
            while let last = s.unicodeScalars.last, punctuation.contains(last) {
                s.removeLast(); closes = true
                s = s.trimmingCharacters(in: wrappers)
            }
            s = Resolver.latinize(s)
            return s.isEmpty ? nil : Token(text: s, closes: closes)
        }
    }

    /// The term for the tokens `words`, if they are exactly one of its names.
    static func lookup(_ words: ArraySlice<Token>) -> Hit? {
        let joined = words.map(\.text).joined(separator: " ")
        if let hit = tables.exact[joined] { return hit }
        return tables.folded[fold(joined)]
    }

    /// Every term of the package written in `block`, longest phrase first at each place.
    static func found(in block: String) -> [Hit] {
        let words = tokens(block)
        var out: [Hit] = []
        var i = 0
        while i < words.count {
            var matched = 0
            for length in stride(from: min(tables.longest, words.count - i), through: 1, by: -1) {
                let slice = words[i..<i + length]
                if slice.dropLast().contains(where: \.closes) { continue }
                if let hit = lookup(slice) { out.append(hit); matched = length; break }
            }
            i += max(matched, 1)
        }
        return out
    }

    // MARK: Resolution

    /// The explanation of `phrase`, or nil. `block` is the text it was read in (the line, or the lines
    /// around it): a word that is also ordinary English counts only if the block holds another word of the
    /// package, or `marked` says the writer put it in backticks.
    static func definition(_ phrase: String, block: String, marked: Bool) -> Definition? {
        guard isEnabled else { return nil }
        let words = tokens(phrase)
        guard !words.isEmpty, words.count <= tables.longest, !words.dropLast().contains(where: \.closes),
              let hit = lookup(words[...]) else { return nil }
        if !hit.strong, !marked, !phrase.contains("`") {
            let around = block.isEmpty ? phrase : block
            guard found(in: around).count >= 2 || hasCodeToken(in: around) else { return nil }
        }
        let term = terms[hit.term]
        return Definition(id: term.names, key: "git:\(hit.term)", repo: "", path: "", line: 0, rule: .vocabulary,
                          title: S.isSpanish ? term.es : term.en,
                          summary: S.seenIn(S.isSpanish ? term.seenEs : term.seenEn),
                          absolutePath: "")
    }

    /// Whether `phrase` would be explained, for the highlight (D39).
    static func knows(_ phrase: String, block: String, marked: Bool = false) -> Bool {
        definition(phrase, block: block, marked: marked) != nil
    }

    /// The word is a git word that is also ordinary language (`main`, `rama`): it needs context to be explained.
    public static func isAmbiguous(_ word: String) -> Bool {
        guard isEnabled else { return false }
        let words = tokens(word)
        guard words.count == 1, let hit = lookup(words[...]) else { return false }
        return !hit.strong
    }

    /// Why `phrase` was or was not explained, for the debug log (`Debug.isOn` only: it holds the user's text).
    public static func diagnose(_ phrase: String, block: String, marked: Bool) -> String {
        guard isEnabled else { return "package off" }
        let words = tokens(phrase)
        guard !words.isEmpty, words.count <= tables.longest, let hit = lookup(words[...]) else { return "not a git word" }
        if hit.strong { return "strong term \(terms[hit.term].names)" }
        let spans = found(in: block).count
        return "weak term \(terms[hit.term].names): backticks/code-style=\(marked), git words in block=\(spans), file-or-branch token=\(hasCodeToken(in: block))"
    }

    // MARK: Code in the block

    static let branchPrefixes: Set<String> = ["feature", "feat", "fix", "hotfix", "bugfix", "chore", "release", "claude", "codex",
                                              "docs", "src", "sources", "tests", "scripts", "origin", "refs", "backup", "users"]
    static let domain = try! NSRegularExpression(pattern: #"^[\w-]+(\.[\w-]+)*\.(com|org|net|io|dev|app|es|co|ai|me|edu|gov)(/|:|$)"#, options: [.caseInsensitive])
    static let segment = try! NSRegularExpression(pattern: #"^[\w.~-]+$"#)
    static let fileName = try! NSRegularExpression(pattern: #"^[\w-]+\.([A-Za-z0-9]+)$"#)

    /// A file or branch written in the block (`src/app.js`, `feature/login`, `README.md`) says the text is
    /// about code: it counts as git context. A URL, `and/or`, `input/output` or a date does not.
    static func hasCodeToken(in block: String) -> Bool {
        tokens(block).contains { isFileOrBranch($0.text) }
    }

    static func isFileOrBranch(_ token: String) -> Bool {
        func matches(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil }
        guard !token.contains("://"), !token.contains("@"), !token.lowercased().hasPrefix("www."), !matches(domain, token) else { return false }
        if token.contains("/") {
            let parts = token.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty && matches(segment, $0) }) else { return false }
            // Dates and fractions: `10/12`, `24/7`.
            guard !parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return false }
            return parts.count >= 3 || branchPrefixes.contains(parts[0].lowercased())
                || parts.contains { $0.contains { "-_.".contains($0) || $0.isNumber } }
        }
        guard matches(fileName, token), let ext = token.split(separator: ".").last else { return false }
        return RepoRefs.fileExtensions.contains(ext.lowercased())
    }

    /// A font name that is monospaced (`SF Mono`, `Menlo`, `JetBrains Mono`): code, not prose.
    public static func isMonospacedFont(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["mono", "menlo", "courier", "consolas", "monaco", "code", "terminal", "typewriter"].contains { n.contains($0) }
    }
}

extension Resolver {
    /// The git package's explanation of `phrase` (D42), or nil. Last in the order: ID, repo reference, code,
    /// glossary term, git.
    public func resolveGit(_ phrase: String, block: String, marked: Bool = false) -> Resolution? {
        guard let d = GitVocabulary.definition(phrase, block: block, marked: marked) else { return nil }
        return Resolution(query: phrase.trimmingCharacters(in: .whitespacesAndNewlines), kind: .exact, key: d.key,
                          definitions: [d], mentions: nil, alternatives: [])
    }
}
