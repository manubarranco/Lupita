import Foundation

/// The git vocabulary package (D42): what agents and colleagues say about git in prose, explained in plain
/// language for people who do not read a terminal. Fixed table in code (D32), no index, no language model
/// (D26). The first of the «vocabulary between trades» packages: it works from the first minute, whatever
/// glossaries the user has.
public enum GitVocabulary {
    /// The menu switch «Git». The app sets it at launch and when the switch moves.
    nonisolated(unsafe) public static var isEnabled = true

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

    // MARK: The 40 terms (validated by Manu, 2026-10-25)

    static let terms: [Term] = [
        Term(names: "repo · repositorio",
             en: "A project's folder with all its history.", es: "La carpeta de un proyecto con todo su historial.",
             seenEn: "“clone the repo”", seenEs: "«clona el repo»",
             aliases: weak(["repo", "repos", "repositorio", "repositorios", "repository", "repositories"])),
        Term(names: "commit · commitear",
             en: "A saved snapshot of the changes, with a message.", es: "Una foto guardada de los cambios, con un mensaje.",
             seenEn: "“I'll commit it and let you know”", seenEs: "«lo commiteo y te aviso»",
             aliases: weak(english("commit", double: true)) + strong(spanish("commitear"))),
        Term(names: "rama · branch",
             en: "A separate line of work that leaves the main one alone.", es: "Una línea de trabajo aparte que no toca la principal.",
             seenEn: "“it's on its own branch”", seenEs: "«está en su rama»",
             aliases: weak(["rama", "ramas", "branch", "branches"])),
        Term(names: "main · master",
             en: "The main branch, the one that counts.", es: "La rama principal, la que vale.",
             seenEn: "“it's already in main”", seenEs: "«ya está en main»",
             aliases: weak(["main", "master"])),
        Term(names: "remoto · origin · remote",
             en: "The project's copy online (GitHub).", es: "La copia del proyecto en internet (GitHub).",
             seenEn: "“push it to origin”", seenEs: "«súbelo a origin»",
             aliases: weak(["remoto", "remotos", "origin", "remote", "remotes"])),
        Term(names: "clonar · clone",
             en: "Download the whole project to your computer.", es: "Bajar el proyecto entero a tu ordenador.",
             seenEn: "when you start on a project", seenEs: "al empezar en un proyecto",
             aliases: weak(spanish("clonar") + english("clone"))),
        Term(names: "diff",
             en: "What changed, line by line.", es: "Lo que cambió, línea a línea.",
             seenEn: "“look at the diff”", seenEs: "«mira el diff»",
             aliases: weak(["diff", "diffs"])),
        Term(names: "historial · log",
             en: "The list of all commits.", es: "La lista de todos los commits.",
             seenEn: "“look for it in the log”", seenEs: "«búscalo en el log»",
             aliases: weak(["historial", "log", "logs"])),
        Term(names: "push · pushear",
             en: "Upload your commits to the remote.", es: "Subir tus commits al remoto.",
             seenEn: "“I've already pushed it”", seenEs: "«ya lo he pusheado»",
             aliases: weak(english("push")) + strong(spanish("pushear"))),
        Term(names: "pull",
             en: "Download what's new and join it to your work.", es: "Bajar lo nuevo del remoto y juntarlo con lo tuyo.",
             seenEn: "“pull before you start”", seenEs: "«haz pull antes de empezar»",
             aliases: weak(english("pull")) + strong(spanish("pullear"))),
        Term(names: "fetch",
             en: "See what's new on the remote without touching your files.", es: "Ver lo nuevo del remoto sin tocar tus archivos.",
             seenEn: "agent notices", seenEs: "avisos del agente",
             aliases: weak(english("fetch")) + strong(spanish("fetchear"))),
        Term(names: "upstream",
             en: "The remote branch yours follows.", es: "La rama del remoto a la que sigue la tuya.",
             seenEn: "“it has no upstream”", seenEs: "«no tiene upstream»",
             aliases: strong(["upstream"])),
        Term(names: "ahead · behind",
             en: "How many commits you have more or fewer than the remote.", es: "Cuántos commits llevas de más o de menos que el remoto.",
             seenEn: "“2 commits ahead”", seenEs: "«2 commits por delante»",
             aliases: weak(["ahead", "behind", "por delante", "por detrás"])),
        Term(names: "fork",
             en: "Your own copy of someone else's project.", es: "Tu copia propia de un proyecto ajeno.",
             seenEn: "on GitHub", seenEs: "en GitHub",
             aliases: weak(english("fork")) + strong(spanish("forkear"))),
        Term(names: "merge · mergear",
             en: "Join one branch's changes into another.", es: "Juntar los cambios de una rama en otra.",
             seenEn: "“merge it into main”", seenEs: "«mergea a main»",
             aliases: weak(english("merge")) + strong(spanish("mergear"))),
        Term(names: "merge commit",
             en: "The commit left by joining two branches.", es: "El commit que deja la unión de dos ramas.",
             seenEn: "in the history", seenEs: "en el historial",
             aliases: strong(["merge commit", "merge commits"])),
        Term(names: "fast-forward",
             en: "A join with no mixing: the branch just moves forward.", es: "Una unión sin mezcla: la rama solo avanza.",
             seenEn: "“fast-forward merge”", seenEs: "«fast-forward merge»",
             aliases: strong(["fast-forward", "fast forward", "fast-forward merge", "fast-forwarded", "ff-only"])),
        Term(names: "conflicto · merge conflict",
             en: "Two changes on the same line; someone picks which stays.", es: "Dos cambios en la misma línea; alguien decide cuál vale.",
             seenEn: "“there are conflicts”", seenEs: "«hay conflictos»",
             aliases: weak(["conflicto", "conflictos", "conflict", "conflicts"])
                + strong(["merge conflict", "merge conflicts", "conflicto de merge", "conflictos de merge"])),
        Term(names: "rebase · rebasear",
             en: "Move your commits on top of another branch's latest.", es: "Mover tus commits encima de lo último de otra rama.",
             seenEn: "“rebase onto main”", seenEs: "«rebasea sobre main»",
             aliases: strong(english("rebase")) + strong(spanish("rebasear"))),
        Term(names: "rebase interactivo · interactive rebase",
             en: "Reorder, combine or edit commits before sharing them.", es: "Reordenar, juntar o editar commits antes de compartirlos.",
             seenEn: "“clean up with an interactive rebase”", seenEs: "«limpia con un rebase interactivo»",
             aliases: strong(["interactive rebase", "rebase interactivo", "rebase interactive", "rebase -i", "rebase --interactive"])),
        Term(names: "squash",
             en: "Combine several commits into one.", es: "Juntar varios commits en uno.",
             seenEn: "“squash and merge”", seenEs: "«squash and merge»",
             aliases: strong(english("squash") + spanish("squashear") + ["squash and merge", "squash & merge", "squash merge"])),
        Term(names: "cherry-pick",
             en: "Copy a single commit from another branch.", es: "Copiar un solo commit de otra rama.",
             seenEn: "“cherry-pick the fix”", seenEs: "«cherry-pickea el fix»",
             aliases: strong(english("cherry-pick") + spanish("cherry-pickear") + ["cherrypick", "cherry pick"])),
        Term(names: "PR · pull request",
             en: "A proposal of changes for someone to review and join.", es: "Una propuesta de cambios para que alguien la revise y la una.",
             seenEn: "“opening a PR”", seenEs: "«abro PR»",
             aliases: [Alias(text: "PR", exact: true), Alias(text: "PRs", exact: true)] + strong(["pull request", "pull requests"])),
        Term(names: "review",
             en: "Another person checking a PR.", es: "La revisión de una PR por otra persona.",
             seenEn: "“pending review”", seenEs: "«pendiente de review»",
             aliases: weak(["review", "reviews"])),
        Term(names: "stage · staging area",
             en: "What's marked to go into the next commit.", es: "Lo marcado para entrar en el próximo commit.",
             seenEn: "“add it to the stage”", seenEs: "«añádelo al stage»",
             aliases: weak(["stage", "staged"]) + strong(["staging area"])),
        Term(names: "stash · stashear",
             en: "Set unfinished changes aside to get them back later.", es: "Apartar cambios a medias para recuperarlos luego.",
             seenEn: "“I stash and switch branch”", seenEs: "«stasheo y cambio de rama»",
             aliases: strong(english("stash") + spanish("stashear"))),
        Term(names: "descartar cambios · discard",
             en: "Throw away what isn't saved in a commit.", es: "Tirar lo que no se ha guardado en un commit.",
             seenEn: "in VS Code", seenEs: "en VS Code",
             aliases: weak(english("discard")) + strong(["descartar cambios", "discard changes"])),
        Term(names: "amend",
             en: "Fix the last commit instead of making a new one.", es: "Corregir el último commit en vez de hacer otro.",
             seenEn: "“I'll put it in with amend”", seenEs: "«lo meto con amend»",
             aliases: strong(english("amend"))),
        Term(names: "revert",
             en: "A new commit that undoes an earlier one.", es: "Un commit nuevo que deshace uno anterior.",
             seenEn: "“revert it”", seenEs: "«reviértelo»",
             aliases: weak(english("revert") + ["revertir", "revierte", "revierto", "revertí", "revertido"])),
        Term(names: "reset",
             en: "Move the branch back to an earlier commit.", es: "Volver la rama a un commit anterior.",
             seenEn: "“do a reset”", seenEs: "«haz un reset»",
             aliases: weak(["reset", "resets", "resetear", "resetea", "reseteo"])),
        Term(names: "reset --hard",
             en: "Go back and delete what wasn't saved.", es: "Volver atrás y borrar lo que no estaba guardado.",
             seenEn: "when something broke", seenEs: "cuando algo se rompió",
             aliases: strong(["reset --hard", "reset hard"])),
        Term(names: "force push",
             en: "Upload and overwrite what's on the remote.", es: "Subir y pisar lo que hay en el remoto.",
             seenEn: "“I need a force push”", seenEs: "«necesito un force push»",
             aliases: strong(["force push", "force-push", "forcepush", "force pushed", "force-pushed", "push --force", "push -f", "push forzado"])),
        Term(names: "HEAD",
             en: "The point in history you're at right now.", es: "El punto del historial en el que estás ahora.",
             seenEn: "git messages", seenEs: "mensajes de git",
             aliases: [Alias(text: "HEAD", exact: true)] + weak(["head"])),
        Term(names: "detached HEAD",
             en: "You're on a loose commit, outside any branch.", es: "Estás en un commit suelto, fuera de cualquier rama.",
             seenEn: "notice when switching to a commit", seenEs: "aviso al cambiar de commit",
             aliases: strong(["detached head", "head desacoplado", "head separado"])),
        Term(names: "untracked",
             en: "New files git doesn't follow yet.", es: "Archivos nuevos que git aún no sigue.",
             seenEn: "in `git status`", seenEs: "en `git status`",
             aliases: strong(["untracked", "untracked files"])),
        Term(names: "working tree clean · nothing to commit",
             en: "There are no unsaved changes.", es: "No hay cambios sin guardar.",
             seenEn: "“nothing to commit”", seenEs: "«nothing to commit»",
             aliases: strong(["working tree clean", "nothing to commit", "working directory clean"])),
        Term(names: "worktree",
             en: "Another branch open in another folder at the same time.", es: "Otra rama abierta en otra carpeta a la vez.",
             seenEn: "with parallel agents", seenEs: "con agentes en paralelo",
             aliases: strong(["worktree", "worktrees", "work tree"])),
        Term(names: "tag",
             en: "A fixed name on a commit, like a version.", es: "Un nombre fijo en un commit, como una versión.",
             seenEn: "“v0.5.0”", seenEs: "«v0.5.0»",
             aliases: weak(["tag", "tags", "tagged", "tagging"])),
        Term(names: ".gitignore",
             en: "The list of what git must not save.", es: "La lista de lo que git no debe guardar.",
             seenEn: "at the root of the repo", seenEs: "en la raíz del repo",
             aliases: strong([".gitignore", "gitignore"])),
        Term(names: "CI",
             en: "Automatic checks when changes are uploaded.", es: "Las comprobaciones automáticas al subir cambios.",
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
