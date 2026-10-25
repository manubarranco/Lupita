import CoreGraphics
import Testing
@testable import LupitaCore

// D42: the git vocabulary package.
@Suite(.serialized) struct GitVocabularyTests {
    static func resolver(glossary: Bool = false) -> Resolver {
        var index = RefIndex()
        index.repos = [Repo(name: "atlas", path: "/x/atlas")]
        index.add(text: "## D023 — Sin dependencias\nNada nuevo.\n", fileName: "decisions.md", repo: "atlas", relativePath: "docs/decisions.md", absolutePath: "/x/atlas/decisions.md")
        if glossary {
            index.add(text: "- **rebase** — el rebase de la casa, no el de git\n", fileName: "glossary.md", repo: "atlas", relativePath: "docs/glossary.md", absolutePath: "/x/atlas/docs/glossary.md")
        }
        index.rank()
        return Resolver(index: index)
    }

    /// Points at the text between ⟦ and ⟧ in `sentence`.
    static func pick(_ sentence: String, glossary: Bool = false) -> Resolution? {
        S.language = "es"
        GitVocabulary.isEnabled = true
        let start = sentence.range(of: "⟦")!
        let offset = sentence.distance(from: sentence.startIndex, to: start.lowerBound) + 1
        let line = sentence.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: "")
        return CandidatePicker.pick(line: line, cursorOffset: offset, resolver: resolver(glossary: glossary))
    }

    /// Whether the lookup shows a tooltip: the app says «not a known reference» for anything else.
    static func explains(_ r: Resolution?) -> Bool {
        guard let r else { return false }
        return [.exact, .corrected, .ambiguous].contains(r.kind) && !r.definitions.isEmpty
    }

    /// One sentence per term, in the order of the table: the term must be explained, by that term.
    static let sentences: [String] = [
        "clona el ⟦repo⟧ y haz pull",
        "lo ⟦commiteo⟧ y te aviso",
        "esa ⟦rama⟧ ya está en main",
        "ya está en ⟦main⟧, súbelo a origin",
        "súbelo a ⟦origin⟧ con un push",
        "hay que ⟦clonar⟧ el repo primero",
        "mira el ⟦diff⟧ del commit",
        "búscalo en el ⟦log⟧ del repo",
        "ya lo he ⟦pusheado⟧",
        "haz ⟦pull⟧ antes de crear la rama",
        "haz ⟦fetch⟧ y mira el remoto",
        "no tiene ⟦upstream⟧",
        "va 2 commits ⟦por delante⟧",
        "hice un ⟦fork⟧ en GitHub del repo",
        "⟦mergea⟧ a main",
        "queda un ⟦merge commit⟧",
        "es un ⟦fast-forward⟧ merge",
        "hay ⟦conflictos⟧ en el merge",
        "⟦rebasea⟧ sobre main",
        "limpia con un ⟦rebase interactivo⟧",
        "⟦squash⟧ and merge",
        "⟦cherry-pickea⟧ el fix",
        "abro ⟦PR⟧",
        "la PR está pendiente de ⟦review⟧",
        "añádelo al ⟦stage⟧ antes del commit",
        "⟦stasheo⟧ y cambio de rama",
        "pulsa ⟦descartar cambios⟧ en VS Code",
        "lo meto con ⟦amend⟧",
        "haz un ⟦revert⟧ del commit",
        "haz un ⟦reset⟧ a ese commit",
        "haz un ⟦reset --hard⟧",
        "necesito un ⟦force push⟧",
        "estás en ⟦HEAD⟧",
        "estás en ⟦detached HEAD⟧",
        "aparece como ⟦untracked⟧",
        "⟦nothing to commit⟧, working tree clean",
        "abre un ⟦worktree⟧",
        "crea un ⟦tag⟧ v0.5.0 en main",
        "mételo en ⟦.gitignore⟧",
        "el ⟦CI⟧ está en rojo",
    ]

    @Test func theTableHasTheForty() {
        #expect(GitVocabulary.terms.count == 40)
        #expect(Self.sentences.count == 40)
        for term in GitVocabulary.terms {
            #expect(!term.en.isEmpty && !term.es.isEmpty && !term.seenEn.isEmpty && !term.seenEs.isEmpty)
        }
    }

    @Test func everyTermIsExplained() throws {
        for (n, sentence) in Self.sentences.enumerated() {
            let r = try #require(Self.pick(sentence), "nothing for: \(sentence)")
            let d = try #require(r.definitions.first)
            #expect(d.rule == .vocabulary, "\(sentence) → \(d.rule)")
            #expect(d.id == GitVocabulary.terms[n].names, "\(sentence) → \(d.id)")
            #expect(d.title == GitVocabulary.terms[n].es)
            #expect(d.summary.hasPrefix("Lo verás en: "))
        }
    }

    @Test func englishCardsAreInEnglish() throws {
        let r = try #require(Self.pick("⟦rebasea⟧ sobre main"))
        S.language = "en"
        let again = try #require(Self.resolver().resolveGit("rebase", block: "rebase"))
        #expect(again.definitions[0].title == "Move your commits on top of another branch's latest.")
        #expect(again.definitions[0].summary == "You'll see it in: “rebase onto main”")
        #expect(r.definitions[0].rule == .vocabulary)
        S.language = "es"
    }

    @Test func conjugatedVerbsResolve() throws {
        for (word, expected) in [("pusheo", "push · pushear"), ("pusheado", "push · pushear"), ("pushea", "push · pushear"),
                                 ("mergear", "merge · mergear"), ("mergeamos", "merge · mergear"),
                                 ("rebasear", "rebase · rebasear"), ("rebaseado", "rebase · rebasear"),
                                 ("stashear", "stash · stashear"), ("stasheo", "stash · stashear"),
                                 ("commitear", "commit · commitear"), ("commiteo", "commit · commitear"), ("commiteado", "commit · commitear"),
                                 ("cherry-pickear", "cherry-pick"), ("cherry-pickeo", "cherry-pick"),
                                 ("rebased", "rebase · rebasear"), ("squashed", "squash"), ("amended", "amend"), ("worktrees", "worktree")] {
            let r = try #require(Self.pick("lo ⟦\(word)⟧ ahora"), "\(word)")
            #expect(r.definitions.first?.id == expected, "\(word)")
        }
        // English inflections of a word that is also ordinary English need the context.
        #expect(Self.explains(Self.pick("he ⟦pushed⟧ la rama")))
        #expect(!Self.explains(Self.pick("I ⟦pushed⟧ the button")))
    }

    @Test func phrasesResolve() throws {
        for (sentence, expected) in [("un ⟦fast-forward merge⟧ limpio", "fast-forward"), ("un ⟦merge conflict⟧ feo", "conflicto · merge conflict"),
                                     ("el ⟦interactive rebase⟧", "rebase interactivo · interactive rebase"),
                                     ("⟦squash and merge⟧ por favor", "squash"), ("una ⟦pull request⟧ nueva", "PR · pull request"),
                                     ("el ⟦staging area⟧ está vacío", "stage · staging area"), ("hace ⟦force-push⟧ siempre", "force push"),
                                     ("estás en ⟦detached HEAD⟧ otra vez", "detached HEAD"), ("la ⟦working tree clean⟧", "working tree clean · nothing to commit")] {
            let r = try #require(Self.pick(sentence), "\(sentence)")
            #expect(r.definitions.first?.id == expected, "\(sentence)")
        }
        // Pointing at the second word of a phrase works too.
        let second = try #require(Self.pick("un fast-forward ⟦merge⟧ limpio"))
        #expect(second.definitions.first?.id == "fast-forward")
    }

    @Test func ordinaryProseResolvesNothing() {
        S.language = "es"
        GitVocabulary.isEnabled = true
        for line in ["push the button to continue", "the main reason is cost", "a branch of the tree fell", "el log de la web es largo",
                     "I need a head start on this", "the fork in the road", "ese tag de precio está mal", "la rama del árbol se rompió",
                     "ask for a review of the copy", "my origin story is long", "resetea el router de casa", "the history of the web"] {
            let words = line.split(separator: " ")
            var location = 0
            for word in words {
                let r = CandidatePicker.pick(line: line, cursorOffset: location + 1, resolver: Self.resolver())
                #expect(!Self.explains(r), "“\(word)” in “\(line)” resolved to \(r?.definitions.first?.id ?? "")")
                location += word.count + 1
            }
        }
    }

    @Test func ambiguousWordsNeedAnotherGitWordOrBackticks() {
        #expect(Self.explains(Self.pick("the ⟦main⟧ branch")))
        #expect(Self.explains(Self.pick("the ⟦branch⟧ is on main")))
        #expect(Self.explains(Self.pick("run `⟦push⟧` now")))
        #expect(!Self.explains(Self.pick("the ⟦main⟧ reason")))
    }

    @Test func aGlossaryTermWins() throws {
        let r = try #require(Self.pick("hay que ⟦rebasear⟧ la casa", glossary: false))
        #expect(r.definitions.first?.rule == .vocabulary)
        let term = try #require(Self.pick("el ⟦rebase⟧ de la casa", glossary: true))
        #expect(term.definitions.first?.rule == .term)
        let without = try #require(Self.pick("el ⟦rebase⟧ de la casa", glossary: false))
        #expect(without.definitions.first?.rule == .vocabulary)
    }

    @Test func idsAndCodeWinOverTheGitPackage() throws {
        let id = try #require(Self.pick("según ⟦D023⟧ hay un rebase"))
        #expect(id.definitions.first?.rule != .vocabulary)
        let command = try #require(Self.pick("corre ⟦git rebase⟧ main"))
        #expect(command.definitions.first?.rule == .terminal)
        let stash = try #require(Self.pick("corre ⟦git stash⟧"))
        #expect(stash.definitions.first?.rule == .terminal)
    }

    @Test func theSwitchTurnsItOff() {
        GitVocabulary.isEnabled = false
        defer { GitVocabulary.isEnabled = true }
        S.language = "es"
        let line = "hay que rebasear y hacer un force push"
        #expect(!Self.explains(CandidatePicker.pick(line: line, cursorOffset: 10, resolver: Self.resolver())))
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row(line), resolver: Self.resolver()).isEmpty)
    }

    // MARK: OCR and highlight

    @Test func ocrWordsUseTheNearbyRowsAsContext() throws {
        S.language = "es"
        GitVocabulary.isEnabled = true
        let words = HighlightPickerTests.row("sube la rama", y: 0) + HighlightPickerTests.row("antes de hacer push", y: 20)
        let push = try #require(words.last)
        let r = CandidatePicker.pick(words: words, cursor: CGPoint(x: push.box.midX, y: push.box.midY), resolver: Self.resolver())
        #expect(r?.definitions.first?.id == "push · pushear")
        let lone = HighlightPickerTests.row("antes de hacer push")
        let none = CandidatePicker.pick(words: lone, cursor: CGPoint(x: lone[3].box.midX, y: lone[3].box.midY), resolver: Self.resolver())
        #expect(!Self.explains(none))
    }

    @Test func theHighlightUnderlinesGitWords() {
        S.language = "es"
        GitVocabulary.isEnabled = true
        let resolver = Self.resolver()
        // push, main, branch: three weak words that vouch for each other; rebasear and the phrase count alone.
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("push the main branch"), resolver: resolver).count == 3)
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("push the button"), resolver: resolver).isEmpty)
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("hay que rebasear y hacer un force push"), resolver: resolver).count == 2)
        #expect(HighlightPicker.marks(words: HighlightPickerTests.row("un fast-forward merge limpio"), resolver: resolver).count == 1)
    }
}
