import Foundation
import Testing
@testable import LupitaCore

// Batch 5, part 2: IDs defined in JSON files count only when a `.md` of the repo cites them.
@Suite struct StructuredFilesTests {
    static let taskmaster = """
    {
      "master": {
        "tasks": [
          { "id": 1, "title": "Set up the project", "description": "Scaffold it", "subtasks": [
              { "id": 1, "title": "Create the folders" }, { "id": 2, "title": "Add the CLI" } ] },
          { "id": 2, "title": "Wire the parser", "subtasks": [] }
        ]
      }
    }
    """

    static func index(_ md: [String: String], structured: [String: String], repo: String = "r") -> RefIndex {
        var index = RefIndex()
        for (path, text) in md.sorted(by: { $0.key < $1.key }) {
            index.add(text: text, fileName: (path as NSString).lastPathComponent, repo: repo, relativePath: path, absolutePath: "/\(repo)/" + path)
        }
        for (path, text) in structured.sorted(by: { $0.key < $1.key }) {
            index.addStructured(text: text, fileName: (path as NSString).lastPathComponent, repo: repo, relativePath: path, absolutePath: "/\(repo)/" + path)
        }
        index.rank()
        return index
    }

    @Test func aTaskCitedInProseIsDefinedByTasksJson() {
        let r = Resolver(index: Self.index(["docs/notes.md": "We finished Task 1 and Subtask 1.2 today."],
                                           structured: [".taskmaster/tasks/tasks.json": Self.taskmaster]))
        let one = r.resolve("Task 1", preferredRepo: "r", fromPath: "docs/notes.md")
        #expect(one.isShown && one.definitions.first?.title == "Set up the project" && one.definitions.first?.rule == .structured)
        let sub = r.resolve("Subtask 1.2", preferredRepo: "r", fromPath: "docs/notes.md")
        #expect(sub.definitions.first?.title == "Add the CLI")
    }

    @Test func aTaskNobodyCitesDefinesNothing() {
        let index = Self.index(["docs/notes.md": "We finished Task 1."], structured: [".taskmaster/tasks/tasks.json": Self.taskmaster])
        #expect(index.definitions["TASK 2"] == nil)
        #expect(index.definitions["TASK 1.1"] == nil)
        #expect(index.definitions["TASK 1"]?.count == 1)
    }

    @Test func aBareNumberOutsideATaskListDefinesNothing() {
        let json = #"{"items": [{"id": 5, "title": "Something"}], "tasks": "none"}"#
        let index = Self.index(["a.md": "See Task 5 and item 5."], structured: ["data.json": json])
        #expect(index.definitions["TASK 5"] == nil)
    }

    @Test func aMarkdownDefinitionWinsOverTheFile() {
        let index = Self.index(["tasks.md": "- [ ] 1. Real task one\n", "notes.md": "Task 1 is done"], structured: ["tasks.json": Self.taskmaster])
        #expect(index.definitions["TASK 1"]?.map(\.rule).contains(.structured) == false)
    }

    @Test func anIdWrittenAsAStringIsDefinedWhenCited() {
        let json = #"[{"id": "FR-007", "title": "Export to PDF"}, {"id": "FR-008", "title": "Never cited"}, {"id": "gpt-4", "name": "model"}]"#
        let index = Self.index(["spec.md": "The export (FR-007) is slow."], structured: ["data/requirements.json": json])
        #expect(index.definitions["FR007"]?.first?.title == "Export to PDF")
        #expect(index.definitions["FR008"] == nil)
    }

    @Test func aCitationInAnotherRepoDoesNotCount() {
        var index = Self.index(["spec.md": "Nothing here."], structured: [:], repo: "a")
        index.add(text: "Task 1 everywhere", fileName: "n.md", repo: "b", relativePath: "n.md", absolutePath: "/b/n.md")
        index.addStructured(text: Self.taskmaster, fileName: "tasks.json", repo: "a", relativePath: "tasks.json", absolutePath: "/a/tasks.json")
        #expect(index.definitions["TASK 1"] == nil)
    }

    @Test func aTaskOfTheFileReachesCitationsFromAnyFolder() {
        let r = Resolver(index: Self.index(["docs/deep/x.md": "Task 2 next"], structured: [".taskmaster/tasks/tasks.json": Self.taskmaster]))
        #expect(r.resolve("Task 2", preferredRepo: "r", fromPath: "docs/deep/x.md").isShown)
    }

    @Test func universalConfigurationIsNeverRead() {
        for name in ["package.json", "package-lock.json", "tsconfig.json", "tsconfig.build.json", "docker-compose.yml", "Cargo.toml",
                     "pyproject.toml", "config.yaml", ".eslintrc.json", "openapi.yaml", "app.min.json"] {
            #expect(!StructuredFiles.isRead(name: name, parents: []), "\(name)")
        }
        for name in ["tasks.json", "sprint-status.yaml", "tickets.toml", "requirements.json"] {
            #expect(StructuredFiles.isRead(name: name, parents: ["docs"]), "\(name)")
        }
        #expect(!StructuredFiles.isRead(name: "tasks.json", parents: ["node_modules", "x"]))
        #expect(!StructuredFiles.isRead(name: "notes.txt", parents: []))
    }

    @Test func discoveryFindsTheFilesThatCanDefineAndSkipsBigOnes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-structured-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        func put(_ path: String, _ text: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try put(".git/HEAD", "ref")
        try put(".taskmaster/tasks/tasks.json", "{}")
        try put("docs/data.json", "{}")
        try put("package.json", "{}")
        try put("node_modules/x/y.json", "{}")
        try put("docs/big.json", String(repeating: " ", count: StructuredFiles.maxBytes + 1))
        try put("docs/readme.md", "# hi")
        let base = RepoDiscovery.realPath(root.path)
        let found = RepoDiscovery.files(in: Repo(name: "t", path: base))
        let names = found.structured.map { $0.path.replacingOccurrences(of: base + "/", with: "") }
        #expect(names == [".taskmaster/tasks/tasks.json", "docs/data.json"], "\(names)")
        #expect(found.markdown.count == 1)
    }
}
