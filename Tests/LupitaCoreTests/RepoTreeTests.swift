import Foundation
import Testing
@testable import LupitaCore

// D44: the folder rows of the menu.
@Suite struct RepoTreeTests {
    static let root = "/nonexistent/Repos"
    static func repo(_ rel: String) -> Repo {
        Repo(name: (rel as NSString).lastPathComponent, path: root + "/" + rel)
    }

    @Test func subfolderWithReposIsItsOwnRow() {
        let nodes = RepoTree.build(root: Self.root, repos: ["nib", "Archivados/old", "Archivados/older"].map(Self.repo))
        #expect(nodes.map(\.title) == ["Archivados", "nib"])
        guard case .folder(_, _, let children) = nodes[0] else { Issue.record("not a folder"); return }
        #expect(children.map(\.title) == ["old", "older"])
    }

    @Test func singleRepoFolderCollapsesIntoTheRepo() {
        let nodes = RepoTree.build(root: Self.root, repos: ["nib", "Clientes/acme/site"].map(Self.repo))
        #expect(nodes.map(\.title) == ["Clientes › acme › site", "nib"])
        guard case .repo = nodes[0] else { Issue.record("not a repo"); return }
    }

    @Test func rootThatIsTheRepo() {
        let repo = Repo(name: "Repos", path: Self.root)
        #expect(RepoTree.build(root: Self.root, repos: [repo]) == [.repo(repo, title: "Repos")])
    }

    @Test func switchStates() {
        let repos = ["a", "b"].map(Self.repo)
        #expect(RepoTree.state(of: repos, disabled: []) == .on)
        #expect(RepoTree.state(of: repos, disabled: [repos[0].path]) == .mixed)
        #expect(RepoTree.state(of: repos, disabled: Set(repos.map(\.path))) == .off)
    }
}
