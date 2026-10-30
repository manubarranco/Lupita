import Foundation
import Testing
@testable import LupitaCore

// Batch 2 of the ID forms: numbers with a word, checklist tasks, `REQ-3.1` and BMAD story keys,
// each scoped by folder.
@Suite struct IDFormsBatch2Tests {
    static func resolver(_ files: [String: String]) -> Resolver {
        var index = RefIndex()
        for (path, text) in files.sorted(by: { $0.key < $1.key }) {
            index.add(text: text, fileName: (path as NSString).lastPathComponent, repo: "r", relativePath: path, absolutePath: "/r/" + path)
        }
        index.rank()
        return Resolver(index: index)
    }

    static func shown(_ resolver: Resolver, _ text: String, from path: String?) -> [Definition] {
        guard let id = IDGrammar.parse(text) else { return [] }
        return resolver.shownDefinitions(for: id, preferredRepo: "r", fromPath: path)
    }

    static func keys(_ text: String) -> [String] { IDGrammar.tokens(in: text).map(\.id.key) }

    // MARK: R1, a word and a number

    @Test func wordAndNumberAreRecognised() {
        #expect(Self.keys("see Requirement 3 and Story 2.3, Epic 2.") == ["REQUIREMENT 3", "STORY 2.3", "EPIC 2"])
        #expect(Self.keys("Property 7 holds; Decision 4: use X; Task Group 2") == ["PROPERTY 7", "DECISION 4", "TASK GROUP 2"])
        #expect(Self.keys("_Requirements: 1.1_ Requirements 4.3, 4.5") == ["REQUIREMENT 4.3"])
        #expect(Self.keys("Subtask 5.2 and Task #3") == ["TASK 5.2", "TASK 3"])
    }

    @Test func wordAndNumberNeedTheWordAndTheNumber() {
        #expect(Self.keys("Requirement three, requirement 3, Epic, the Story of 2 users, Task 3rd, Epic 2x").isEmpty)
        #expect(Self.keys("version Task 1.2.3.4 and Story 2.3.4.5").isEmpty)
        #expect(Self.keys("Task 3.FIX.4 and Task 3.x and Task 3_1").isEmpty)
        #expect(Self.keys("MyRequirement 3 and Subepic 2").isEmpty)
    }

    @Test func requirementIsDefinedByItsHeadingAndTakenFromItsFolder() {
        let r = Self.resolver([
            "specs/a/requirements.md": "# Spec A\n\n### Requirement 3: Login\n\nText\n",
            "specs/a/design.md": "Covers Requirement 3.\n",
            "specs/b/design.md": "Covers Requirement 3.\n",
        ])
        let own = Self.shown(r, "Requirement 3", from: "specs/a/design.md")
        #expect(own.map(\.path) == ["specs/a/requirements.md"])
        #expect(own.first?.title == "Login")
        #expect(own.first?.rule == .heading)
        // The sibling folder `specs/b` does not borrow the definition of `specs/a`.
        #expect(Self.shown(r, "Requirement 3", from: "specs/b/design.md").isEmpty)
        let picked = r.resolveWordID("Requirement 3", preferredRepo: "r", fromPath: "specs/b/design.md")
        #expect(picked == nil)
        #expect(r.resolveWordID("Requirement 3.", preferredRepo: "r", fromPath: "specs/a/design.md")?.definitions.first?.title == "Login")
    }

    @Test func aDefinitionInAFolderAboveReaches() {
        let r = Self.resolver([
            "docs/epics.md": "## Epic 2: Payments\n",
            "docs/stories/deep/s.md": "Belongs to Epic 2.\n",
            "src/notes.md": "Epic 2 again.\n",
        ])
        #expect(Self.shown(r, "Epic 2", from: "docs/stories/deep/s.md").first?.title == "Payments")
        #expect(Self.shown(r, "Epic 2", from: "src/notes.md").isEmpty)
    }

    @Test func withNoReaderFileEveryDefinitionOfTheRepoIsListed() {
        let one = Self.resolver(["a/epics.md": "## Epic 2: Payments\n"])
        let id = IDGrammar.parse("Epic 2")!
        #expect(one.shownDefinitions(for: id, preferredRepo: "r", fromPath: nil).count == 1)
        let two = Self.resolver(["a/epics.md": "## Epic 2: Payments\n", "b/epics.md": "## Epic 2: Search\n"])
        #expect(two.shownDefinitions(for: id, preferredRepo: "r", fromPath: nil).map(\.path).sorted() == ["a/epics.md", "b/epics.md"])
        #expect(two.resolveWordID("Epic 2", preferredRepo: "r", fromPath: nil)?.definitions.count == 2)
    }

    @Test func aCitedCriterionShowsItsRequirement() {
        let r = Self.resolver(["s/requirements.md": "### Requirement 3: Login\n", "s/design.md": "x\n"])
        let shown = Self.shown(r, "Requirement 3.1", from: "s/design.md")
        #expect(shown.first?.title == "Login")
        // An exact definition beats the parent.
        let exact = Self.resolver(["s/requirements.md": "### Requirement 3: Login\n### Requirement 3.1: Password\n"])
        #expect(Self.shown(exact, "Requirement 3.1", from: "s/design.md").first?.title == "Password")
    }

    @Test func aHeadingThatIsNotTheFormDoesNotDefineIt() {
        let r = Self.resolver([
            "s/a.md": "## Task 2.FIX Summary\n\n### Requirements 12.1-12.6: Accessibility\n\n## The Epic 5 plan\n",
            "s/b.md": "Task 2 and Requirement 12.1 and Epic 5.\n",
        ])
        #expect(Self.shown(r, "Task 2", from: "s/b.md").isEmpty)
        #expect(Self.shown(r, "Requirement 12.1", from: "s/b.md").isEmpty)
        #expect(Self.shown(r, "Epic 5", from: "s/b.md").isEmpty)
    }

    @Test func aHeadingWithNoTitleStillDefines() {
        let r = Self.resolver(["s/requirements.md": "### Requirement 1\n\n**User Story:** As a user, I log in.\n", "s/d.md": "x"])
        let d = Self.shown(r, "Requirement 1", from: "s/d.md").first
        #expect(d?.rule == .heading)
    }

    @Test func theReadersOwnFileComesFirst() {
        let r = Self.resolver([
            "plans/a.md": "### Task 2: Alpha\n",
            "plans/b.md": "### Task 2: Beta\n",
        ])
        #expect(Self.shown(r, "Task 2", from: "plans/b.md").first?.title == "Beta")
        #expect(Self.shown(r, "Task 2", from: "plans/a.md").first?.title == "Alpha")
    }

    // MARK: R5, the tasks of a tasks.md

    @Test func aChecklistNumberIsATaskToken() {
        let line = IDGrammar.tokens(in: "  - [x]* 1.1 Create the table")
        #expect(line.map(\.id.key) == ["TASK 1.1"])
        #expect(line.first.map { ("  - [x]* 1.1 Create the table" as NSString).substring(with: $0.range) } == "1.1")
        #expect(Self.keys("- [ ] 2. Wire it") == ["TASK 2"])
        #expect(Self.keys("- [ ] write the docs").isEmpty)
        #expect(Self.keys("1.1 Create the table").isEmpty)
        #expect(Self.keys("- [ ] 1.1x Create").isEmpty)
    }

    @Test func aTasksFileDefinesItsTasksAndOnlyThatFile() {
        let r = Self.resolver([
            ".kiro/specs/a/tasks.md": "# Plan\n\n- [ ] 1. Setup\n  - [x] 1.1 Create the table\n- [ ]* 2.1 Optional thing\n",
            ".kiro/specs/a/design.md": "Done in Task 1.1.\n- [ ] 3.5 Not a task file\n",
            ".kiro/specs/b/design.md": "Done in Task 1.1.\n",
            ".kiro/specs/c/README.md": "- [ ] 4.1 A todo of a readme\n",
        ])
        let d = Self.shown(r, "Task 1.1", from: ".kiro/specs/a/design.md")
        #expect(d.map(\.path) == [".kiro/specs/a/tasks.md"])
        #expect(d.first?.title == "Create the table")
        #expect(Self.shown(r, "Task 2.1", from: ".kiro/specs/a/design.md").first?.title == "Optional thing")
        #expect(Self.shown(r, "Task 1.1", from: ".kiro/specs/b/design.md").isEmpty)
        #expect(Self.shown(r, "Task 3.5", from: ".kiro/specs/a/design.md").isEmpty)
        #expect(Self.shown(r, "Task 4.1", from: ".kiro/specs/c/README.md").isEmpty)
    }

    @Test func aTaskLineIsNotCountedAsAMentionOfItself() {
        var index = RefIndex()
        index.add(text: "- [ ] 1.1 Create\nSee Task 1.1.\n", fileName: "tasks.md", repo: "r", relativePath: "tasks.md", absolutePath: "/r/tasks.md")
        #expect(index.mentions["TASK 1.1"]?.count == 1)
    }

    @Test func wordFormMentionsAreKeptOnlyWhereTheRepoDefinesThem() {
        var index = RefIndex()
        index.add(text: "Epic 2 and Task 9 and D4\n", fileName: "a.md", repo: "x", relativePath: "a.md", absolutePath: "/x/a.md")
        index.add(text: "## Epic 2: Pay\nEpic 2 again\n", fileName: "b.md", repo: "y", relativePath: "b.md", absolutePath: "/y/b.md")
        index.rank()
        #expect(index.mentions["EPIC 2"]?.files == ["y/b.md"])
        #expect(index.mentions["TASK 9"] == nil)
        #expect(index.mentions["D4"]?.files == ["x/a.md"])
    }

    @Test func tasksFileBeatsAReportHeadingFromANearerFolder() {
        let r = Self.resolver([
            "s/tasks.md": "- [ ] 3.3 Name the tokens\n",
            "s/completion/report.md": "## Task 3.3 — Review\n",
            "s/completion/other.md": "Task 3.3 says to name them.\n",
        ])
        #expect(Self.shown(r, "Task 3.3", from: "s/completion/other.md").first?.path == "s/tasks.md")
    }

    @Test func aCitedCriterionKeepsItsMentions() {
        var index = RefIndex()
        index.add(text: "### Requirement 3: Login\n", fileName: "r.md", repo: "x", relativePath: "r.md", absolutePath: "/x/r.md")
        index.add(text: "Covers Requirement 3.1\n", fileName: "d.md", repo: "x", relativePath: "d.md", absolutePath: "/x/d.md")
        index.rank()
        #expect(index.mentions["REQUIREMENT 3.1"]?.files == ["x/d.md"])
    }

    @Test func tasksFileBeatsAReportHeading() {
        let r = Self.resolver([
            "s/tasks.md": "- [ ] 3.3 Name the tokens\n",
            "s/feedback.md": "## Task 3.3 — Candidate Template Review\n",
            "s/other.md": "Task 3.3 says to name them.\n",
        ])
        #expect(Self.shown(r, "Task 3.3", from: "s/other.md").map(\.path) == ["s/tasks.md", "s/feedback.md"])
    }

    // MARK: R2, a suffix after the number

    @Test func aSuffixAfterAHyphenIsPartOfTheID() {
        #expect(Self.keys("REQ-3.1 and AC-3.12, STORY-2.3.") == ["REQ3.1", "AC3.12", "STORY2.3"])
        #expect(IDGrammar.tokens(in: "see REQ-3.1 now").first.map { ("see REQ-3.1 now" as NSString).substring(with: $0.range) } == "REQ-3.1")
    }

    @Test func aFileNamedLikeASuffixedIDDefinesNothing() {
        let r = Self.resolver(["docs/STORY-2.1-HANDOFF-REPORT.md": "Report\n", "docs/AC-1.2-lockout.md": "x\n", "docs/b.md": "see STORY-2.1 and AC-1.2\n"])
        #expect(Self.shown(r, "STORY-2.1", from: "docs/b.md").isEmpty)
        #expect(Self.shown(r, "AC-1.2", from: "docs/b.md").isEmpty)
        // The plain form keeps its file-name definition.
        let plain = Self.resolver(["docs/D23-lockout.md": "x\n", "docs/b.md": "see D23\n"])
        #expect(Self.shown(plain, "D23", from: "docs/b.md").first?.rule == .fileName)
    }

    @Test func versionsKeepTheirOldReading() {
        #expect(Self.keys("REL-0.9.1") == ["REL0"])
        #expect(Self.keys("V5.1 and Python3.9 and D23.5") == ["V5", "D23"])
        #expect(Self.keys("D23. Next sentence, ADR-004.") == ["D23", "ADR004"])
    }

    @Test func aSuffixedIDHasItsOwnDefinitionOrFallsBack() {
        let r = Self.resolver(["a.md": "### REQ-3.1 Password rules\n\n- **FR-2**: Export\n", "b.md": "see REQ-3.1 and FR-2.4\n"])
        #expect(Self.shown(r, "REQ-3.1", from: "b.md").first?.title == "Password rules")
        // `FR-2.4` was read as `FR-2` before the suffix existed: nothing defines it, so it still does.
        #expect(Self.shown(r, "FR-2.4", from: "b.md").first?.title == "Export")
        #expect(Self.shown(r, "REQ-3.2", from: "b.md").isEmpty)
    }

    @Test func storyWithASuffixIsNotTheHeadingStory() {
        // `docs/STORY-2.3-REPORT.md` names a file, not the story that `### Story 2.3` heads: it takes no definition from it.
        let r = Self.resolver(["e/epics.md": "### Story 2.3: Login\n", "e/s.md": "Blocked by STORY-2.3.\n", "e/t.md": "### STORY-2.3 Own\n"])
        #expect(Self.keys("Blocked by STORY-2.3.") == ["STORY2.3"])
        #expect(Self.shown(r, "STORY-2.3", from: "e/s.md").first?.title == "Own")
        #expect(Self.shown(Self.resolver(["e/epics.md": "### Story 2.3: Login\n"]), "STORY-2.3", from: "e/s.md").isEmpty)
    }

    // MARK: R13, the key of a BMAD story

    @Test func aStoryKeyIsRecognised() {
        #expect(Self.keys("see 2-3-user-login and 10-1-setup-db.") == ["STORY 2.3", "STORY 10.1"])
        // `3-3a-…` is another story than 3.3.
        #expect(Self.keys("see 3-3a-custom-upload").isEmpty)
        #expect(IDGrammar.tokens(in: "see 2-3-user-login.md").first.map { ("see 2-3-user-login.md" as NSString).substring(with: $0.range) } == "2-3-user-login")
        #expect(Self.keys("2026-10-30-notes, v2-3-x, 2-3, 2-3-4, 2-3-.md").isEmpty)
        #expect(IDGrammar.tokens(in: "2-3-user-login").first?.id.scope == .topFolder)
    }

    @Test func aSuffixedIDIsDefinedByListAndTableToo() {
        let r = Self.resolver(["a.md": "- **AC-1.2**: Locks after 3 tries\n\n| FR-4.1 | Export | high |\n", "b.md": "x"])
        #expect(Self.shown(r, "AC-1.2", from: "b.md").first?.title == "Locks after 3 tries")
        #expect(Self.shown(r, "FR-4.1", from: "b.md").first?.title == "Export")
    }

    @Test func aStoryKeyTakesItsStoryFromTheSameFirstLevelFolder() {
        let r = Self.resolver([
            "_bmad-output/planning/epics.md": "### Story 2.3: Login\n",
            "_bmad-output/implementation/sprint.md": "next: 2-3-user-login\n",
            "other/notes.md": "next: 2-3-user-login\n",
            "bmad/bmm/sample.md": "### Story 2.3: Example\n",
            "bmad/bmm/instr.md": "e.g. 2-3-user-login\n",
        ])
        // The sibling folder is fine here: the rule is the first-level folder, not the nearest one.
        #expect(Self.shown(r, "2-3-user-login", from: "_bmad-output/implementation/sprint.md").first?.title == "Login")
        #expect(Self.shown(r, "2-3-user-login", from: "other/notes.md").isEmpty)
        // The framework's own examples neither give nor take.
        #expect(Self.shown(r, "2-3-user-login", from: "bmad/bmm/instr.md").isEmpty)
        #expect(Self.shown(r, "2-3-user-login", from: "other/notes.md").isEmpty)
    }

    @Test func aStoryKeyDoesNotTakeAFrameworkExample() {
        let r = Self.resolver(["proj/skills/sample.md": "### Story 2.3: Example\n", "proj/notes.md": "2-3-foo-bar\n"])
        #expect(Self.shown(r, "2-3-foo-bar", from: "proj/notes.md").isEmpty)
    }

    @Test func aFileNamedLikeAStoryKeyDefinesNothing() {
        let r = Self.resolver(["docs/2-3-intro.md": "Some chapter\n", "docs/b.md": "see Story 2.3\n"])
        #expect(Self.shown(r, "Story 2.3", from: "docs/b.md").isEmpty)
    }

    // MARK: the closed archive and the forms that already worked

    @Test func aLiveDefinitionBeatsAClosedOne() {
        let r = Self.resolver([
            "openspec/changes/archive/2026-01-a/design.md": "### D4 — Old\n",
            "openspec/changes/live/design.md": "### D4 — New\n",
            "docs/x.md": "see D4\n",
        ])
        let id = IDGrammar.parse("D4")!
        #expect(r.index.definitions["D4"]?.first?.title == "New")
        #expect(r.shownDefinitions(for: id, preferredRepo: "r", fromPath: "docs/x.md").first?.title == "New")
        // Read from inside the archive, the closed one is the neighbour that counts.
        #expect(r.shownDefinitions(for: id, preferredRepo: "r", fromPath: "openspec/changes/archive/2026-01-a/proposal.md").first?.title == "Old")
    }

    @Test func existingFormsAreUntouched() {
        #expect(Self.keys("D23, QL25, ADR-004, BUG-01, E2-S3b, FR-001a, T012, US1, SC-001") == ["D23", "QL25", "ADR004", "BUG01", "E2-S3b", "FR001a", "T012", "US1", "SC001"])
        #expect(IDGrammar.parse("ADR-004")?.scope == IDScope.none)
        #expect(IDGrammar.parse("Requirement 3")?.scope == IDScope.folder)
    }

    @Test func aWordFormIsNeverOcrCorrected() {
        let r = Self.resolver(["a/epics.md": "## Epic 2: Payments\n", "a/x.md": "t\n"])
        #expect(r.resolve("Epic 2", preferredRepo: "r", fromPath: "a/x.md").kind == .exact)
        #expect(r.resolve("Epic 7", preferredRepo: "r", fromPath: "a/x.md").kind != .exact)
    }

    @Test func thePickerFindsAWordFormByItsNumber() {
        let r = Self.resolver(["a/req.md": "### Requirement 3: Login\n", "a/x.md": "t\n"])
        let line = "Covers Requirement 3 of the spec"
        let at = (line as NSString).range(of: "3").location
        let picked = CandidatePicker.pick(line: line, cursorOffset: at, resolver: r, preferredRepo: "r", fromPath: "a/x.md")
        #expect(picked?.definitions.first?.title == "Login")
        let onWord = CandidatePicker.pick(line: line, cursorOffset: 8, resolver: r, preferredRepo: "r", fromPath: "a/x.md")
        #expect(onWord?.definitions.first?.title == "Login")
    }
}
