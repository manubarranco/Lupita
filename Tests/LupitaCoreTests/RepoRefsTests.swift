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
