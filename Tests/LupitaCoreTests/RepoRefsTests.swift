import Foundation
import Testing
@testable import LupitaCore

// D19: commits, branches, files and commands, looked up in a throwaway git repo.

@Suite(.serialized) struct RepoRefsTests {
    let root: URL
    let repo: Repo

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-refs-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("atlas")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".claude/commands"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".claude/skills/audit"), withIntermediateDirectories: true)
        try "# Decisions\n\nEvery choice we made, newest last.\n\n## D1 — Use **SQLite**\n".write(
            to: dir.appendingPathComponent("docs/decisions.md"), atomically: true, encoding: .utf8)
        try "---\ndescription: Weekly retro, critic mode\n---\n\nBody\n".write(
            to: dir.appendingPathComponent(".claude/commands/retro.md"), atomically: true, encoding: .utf8)
        try "---\nname: audit\ndescription: >\n  Audits the tokens\n  of a design system\n---\n".write(
            to: dir.appendingPathComponent(".claude/skills/audit/SKILL.md"), atomically: true, encoding: .utf8)
        try "print(1)\n".write(to: dir.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        repo = Repo(name: "atlas", path: RepoDiscovery.realPath(dir.path))
        if Git.executable != nil {
            git("init", "-q", "-b", "main")
            git("add", ".")
            git("commit", "-q", "-m", "docs: first decisions")
            git("checkout", "-q", "-b", "feature/search")
            try "x\n".write(to: dir.appendingPathComponent("search.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "feat: search box")
            git("checkout", "-q", "-b", "fix/typo", "main")
            try "y\n".write(to: dir.appendingPathComponent("typo.md"), atomically: true, encoding: .utf8)
            git("add", ".")
            git("commit", "-q", "-m", "fix: typo")
            git("checkout", "-q", "main")
            git("merge", "-q", "--no-ff", "fix/typo", "-m", "Merge fix/typo: one letter")
            git("branch", "-q", "-D", "fix/typo")
        }
    }

    @discardableResult
    func git(_ args: String...) -> String? {
        Git.output(repo.path, ["-c", "user.name=T", "-c", "user.email=t@example.com"] + args)
    }

    func resolve(_ text: String) -> Resolution? {
        RepoRefs.resolve(text, repos: [repo], preferredRepo: "atlas")
    }

    @Test func fileShowsHeadingAndFirstLine() {
        let d = resolve("`docs/decisions.md:5`.")?.definitions.first
        #expect(d?.rule == .file)
        #expect(d?.title == "Decisions")
        #expect(d?.summary == "Every choice we made, newest last.")
        #expect(d?.line == 5)
    }

    @Test func repoNameShowsItsReadmeAndState() throws {
        try "# Atlas\n\nMaps for agents.\n".write(to: URL(fileURLWithPath: repo.path + "/README.md"), atomically: true, encoding: .utf8)
        let r = RepoRefs.resolve("Atlas", repos: [repo], preferredRepo: "other")
        let d = r?.definitions.first
        #expect(d?.rule == .repo)
        #expect(d?.title == "Atlas")
        #expect(d?.summary.hasSuffix("Maps for agents.") == true)
        #expect(r?.fromOtherRepo == false)
        if Git.executable != nil {
            #expect(d?.summary.hasPrefix(S.onBranch("main")) == true)
            #expect(d?.summary.contains(S.uncommitted(1)) == true)
        }
        #expect(resolve("atla") == nil)
    }

    @Test func pathNamingTheRepoFindsIt() {
        let r = RepoRefs.resolve("atlas/docs/decisions.md", repos: [repo], preferredRepo: "other")
        #expect(r?.definitions.first?.path == "docs/decisions.md")
        #expect(r?.fromOtherRepo == false)
    }

    @Test func bareFileNameNeedsAKnownExtension() {
        #expect(resolve("main.py")?.definitions.first?.rule == .file)
        #expect(resolve("missing.py") == nil)
        #expect(resolve("hello") == nil)
        #expect(resolve("D1") == nil)
    }

    @Test func commandAndSkillDescriptions() {
        #expect(resolve("/retro")?.definitions.first?.title == "Weekly retro, critic mode")
        #expect(resolve("/audit")?.definitions.first?.title == "Audits the tokens of a design system")
        #expect(resolve("/nope") == nil)
    }

    @Test func commitShowsSubjectAndWhereItIs() throws {
        try #require(Git.executable != nil)
        let sha = try #require(git("rev-parse", "--short=8", "main~1")?.trimmingCharacters(in: .whitespacesAndNewlines))
        let d = resolve(sha)?.definitions.first
        #expect(d?.rule == .commit)
        #expect(d?.title == "docs: first decisions")
        #expect(d?.summary.hasSuffix(S.inBranch("main")) == true)
        #expect(resolve("abcdef1") == nil)
    }

    @Test func liveBranchCountsCommitsAhead() throws {
        try #require(Git.executable != nil)
        let d = resolve("feature/search")?.definitions.first
        #expect(d?.rule == .branch)
        #expect(d?.title == "feat: search box")
        #expect(d?.summary.hasSuffix(S.ahead(1, of: "main")) == true)
        // A branch lives in one repo: never flagged as "from another repo".
        #expect(RepoRefs.resolve("feature/search", repos: [repo], preferredRepo: "other")?.fromOtherRepo == false)
    }

    @Test func deletedBranchFoundInItsMergeCommit() throws {
        try #require(Git.executable != nil)
        let d = resolve("fix/typo")?.definitions.first
        #expect(d?.title == S.branchDeleted)
        #expect(d?.summary.contains("Merge fix/typo: one letter") == true)
        #expect(resolve("fix/never-existed") == nil)
    }

    @Test func resolverTriesRepoRefsBeforeIDs() {
        var index = RefIndex()
        index.repos = [repo]
        let r = Resolver(index: index).resolve("docs/decisions.md", preferredRepo: "atlas")
        #expect(r.kind == .exact)
        #expect(r.definitions.first?.rule == .file)
    }
}

@Suite struct OnboardingTests {
    private func makeRepo(_ files: [String: String]) throws -> Repo {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("onb-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        for (path, text) in files {
            let url = dir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return Repo(name: dir.lastPathComponent, path: RepoDiscovery.realPath(dir.path))
    }

    @Test func detectsAgentFiles() throws {
        let repo = try makeRepo(["CLAUDE.md": "x", ".cursor/rules/a.mdc": "x", ".github/copilot-instructions.md": "x", "README.md": "x"])
        #expect(Onboarding.agentFiles(in: repo) == ["CLAUDE.md"])
        let both = try makeRepo(["AGENTS.md": "x", "CLAUDE.md": "x"])
        #expect(Onboarding.agentFiles(in: both) == ["AGENTS.md", "CLAUDE.md"])
        let plain = try makeRepo([".cursorrules": "x", "README.md": "x"])
        #expect(Onboarding.agentFiles(in: plain).isEmpty)
        #expect(Onboarding.status(of: RefIndex.build(repos: [plain])).isEmpty)
    }

    @Test func detectsTheMarker() throws {
        let with = try makeRepo(["AGENTS.md": "intro\n\(Onboarding.ruleBlock)\n"])
        let without = try makeRepo(["AGENTS.md": "intro"])
        #expect(Onboarding.hasRule(in: with, files: ["AGENTS.md"]))
        #expect(!Onboarding.hasRule(in: without, files: ["AGENTS.md"]))
    }

    @Test func countsUndefinedCitations() throws {
        let repo = try makeRepo([
            "AGENTS.md": "x",
            "docs/decisions.md": "## D1 — Defined\nSummary.\n\nSee D1, D7 and Q3.\n",
            "docs/notes.md": "D7 again, and D9.\n",
        ])
        let rows = Onboarding.status(of: RefIndex.build(repos: [repo]))
        #expect(rows.count == 1)
        #expect(rows[0].undefinedCitations == 4)  // D7 ×2, Q3, D9; D1 is defined here
        #expect(!rows[0].ruleInstalled)
    }

    @Test func definedElsewhereLabelsAndRangesDoNotCount() throws {
        let a = try makeRepo(["AGENTS.md": "x", "docs/a.md": "See D1, D7, P1, P2 and L0-L3 and Q3.\n"])
        let b = try makeRepo(["docs/decisions.md": "## D1 — Defined elsewhere\nSummary.\n\n## Q3\n"])
        let index = RefIndex.build(repos: [a, b])
        // D1 is defined in the other repo; Q3 only has a weak section; P1/P2 and L0-L3 are not references.
        let row = Onboarding.status(of: index).first { $0.repo == a }
        #expect(row?.undefinedCitations == 2)  // D7 and Q3
    }

    @Test func promptIsFixed() {
        let expected = """
            Add this block at the end of this repo's agent instructions file (`AGENTS.md`, or `CLAUDE.md` if there is no `AGENTS.md`). Change nothing else. If the block is already there, do nothing.

            <!-- lupita -->
            Define each new decision, question, lesson or story once as `## ID — Title` plus a
            one-line summary. Add each new internal term to the glossary (`docs/glossary.md` if
            there is none) as `- **term** — definition`. Where this repo already has a format
            for these, keep it.
            <!-- /lupita -->
            """
        #expect(Onboarding.prompt == expected)
        #expect(Onboarding.prompt.hasSuffix("<!-- /lupita -->"))
        #expect(!Onboarding.prompt.contains("```"))
    }

    @Test func explainedPercent() throws {
        let a = try makeRepo(["AGENTS.md": "x", "docs/a.md": "See D1, D1, D7, P1 and L0-L3 and Q3.\n"])
        let b = try makeRepo(["docs/decisions.md": "## D1 — Defined elsewhere\nSummary.\n"])
        let index = RefIndex.build(repos: [a, b])
        // In a: D1 ×2 explained (and the heading in b is not in a's listed set), D7 and Q3 not: 2 of 4.
        #expect(Onboarding.explainedPercent(of: [a], in: index) == 50)
        #expect(Onboarding.explainedPercent(of: [], in: index) == nil)
    }

    @Test func versionsCompareNumerically() {
        #expect(Versions.isNewer("v0.4.0", than: "0.3.0"))
        #expect(Versions.isNewer("0.10.0", than: "0.9.5"))
        #expect(!Versions.isNewer("0.3.0", than: "0.3.0"))
        #expect(!Versions.isNewer("0.3", than: "0.3.0"))
        #expect(Versions.isNewer("1.0", than: "0.9.9"))
        #expect(!Versions.isNewer("0.2.9", than: "0.3.0"))
        #expect(Versions.tag(fromReleaseJSON: Data(#"{"tag_name":"v0.4.0","x":1}"#.utf8)) == "v0.4.0")
        #expect(Versions.tag(fromReleaseJSON: Data("nope".utf8)) == nil)
    }

    @Test func candidateFoldersCountRepos() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("home-" + UUID().uuidString)
        let fm = FileManager.default
        for p in ["code/a/.git", "code/b/.git", "Documents/GitHub/c/.git", "Developer/empty"] {
            try fm.createDirectory(at: home.appendingPathComponent(p), withIntermediateDirectories: true)
        }
        let found = RepoDiscovery.candidateRoots(home: home.path)
        #expect(found.map(\.path) == [home.path + "/code", home.path + "/Documents/GitHub"])
        #expect(found.map(\.repos) == [2, 1])
    }
}
