import Foundation
import Testing
@testable import LupitaCore

// D043: the closed list of hidden and archive folders that the walk enters.
@Suite struct FrameworkFoldersTests {
    static func makeRepo(_ paths: [String]) throws -> Repo {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-tests-\(UUID().uuidString)/r")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        for path in paths {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "## D001 — Titulo\\n".write(to: url, atomically: true, encoding: .utf8)
        }
        return Repo(name: "r", path: root.path)
    }

    static func found(_ repo: Repo) -> Set<String> {
        let base = RepoDiscovery.realPath(repo.path) + "/"
        return Set(RepoDiscovery.markdownFiles(in: repo).map { RepoDiscovery.realPath($0.path).replacingOccurrences(of: base, with: "") })
    }

    @Test(arguments: [".kiro/specs/a/requirements.md", ".taskmaster/docs/prd.md", ".specify/memory/constitution.md"])
    func listedHiddenFolderIsEntered(_ path: String) throws {
        let repo = try Self.makeRepo([path, "docs/a.md"])
        #expect(Self.found(repo) == [path, "docs/a.md"])
        #expect(RepoDiscovery.isIndexed(path: repo.path + "/" + path, in: repo))
    }

    @Test func listedFolderInsideAMonorepoPackageIsEntered() throws {
        let repo = try Self.makeRepo(["packages/app/.kiro/specs/x/design.md"])
        #expect(Self.found(repo) == ["packages/app/.kiro/specs/x/design.md"])
    }

    @Test func archiveIsEnteredOnlyInsideOpenspecChanges() throws {
        let inside = "openspec/changes/archive/2026-01-01-add-x/proposal.md"
        let repo = try Self.makeRepo([
            inside, "openspec/changes/live/tasks.md",
            "archive/old.md", "docs/archive/old.md", "openspec/archive/old.md",
            "openspec/specs/archive/old.md", "changes/archive/old.md", "openspec/changes/archived/old.md",
        ])
        #expect(Self.found(repo) == [inside, "openspec/changes/live/tasks.md"])
        #expect(RepoDiscovery.isIndexed(path: repo.path + "/" + inside, in: repo))
        #expect(!RepoDiscovery.isIndexed(path: repo.path + "/docs/archive/old.md", in: repo))
        #expect(!RepoDiscovery.isIndexed(path: repo.path + "/openspec/archive/old.md", in: repo))
    }

    @Test func everythingElseKeepsBeingSkipped() throws {
        let skipped = [
            "node_modules/x/README.md", ".git/info/x.md", "build/x.md", "dist/x.md", "vendor/x.md",
            "DerivedData/x.md", "Pods/x.md", "venv/x.md", ".build/x.md", ".claude/x.md", ".github/x.md",
            ".cursor/rules/x.md", ".kiro-old/x.md", ".specify2/x.md", "x/.hidden/y.md", "archived/x.md",
            "feature-worktrees/x.md", "worktrees/x.md",
            // Inside a listed folder, the skip rules still apply.
            ".kiro/node_modules/x.md", ".kiro/.cache/x.md", ".taskmaster/build/x.md", ".specify/archive/x.md",
            "openspec/changes/archive/2026/node_modules/x.md",
            // A hidden file stays hidden even inside a listed folder.
            ".kiro/.hidden.md",
        ]
        let repo = try Self.makeRepo(skipped + ["ok.md"])
        #expect(Self.found(repo) == ["ok.md"])
        for path in skipped { #expect(!RepoDiscovery.isIndexed(path: repo.path + "/" + path, in: repo), "\(path)") }
    }

    @Test func nestedRepoInsideAListedFolderIsStillLeftOut() throws {
        let repo = try Self.makeRepo([".kiro/inner/.git/HEAD", ".kiro/inner/a.md", ".kiro/b.md"])
        #expect(Self.found(repo) == [".kiro/b.md"])
    }
}
