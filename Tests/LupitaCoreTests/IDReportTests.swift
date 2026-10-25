import Foundation
import Testing
@testable import LupitaCore

@Suite struct IDReportTests {
    private func makeRepo(named name: String, _ files: [String: String]) throws -> Repo {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("idr-" + UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        for (path, text) in files {
            let url = dir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return Repo(name: name, path: RepoDiscovery.realPath(dir.path))
    }

    private static let secretRepo = [
        "docs/decisions.md": """
        ## D1 — Launch the Zephyrwidget acquisition
        Secret definition body about Zephyrwidget.
        ## D2 — Fire the contractor Hornblower
        See D1 and D2, D1 again.
        """,
        "SecretFolderName/questions.md": """
        | Q1 | Is Hornblower guilty? | open |
        | Q2 | Moonshot budget? | open |
        See §5 and §6, also §7. Section 1.2 and 1.3 and 2.4 matter. Also REQ.12, REQ.13, REQ.14.
        Ref ZZ9 is cited ZZ9 ZZ9 ZZ9 here, never defined.
        """,
        "SecretFolderName/Q7-Hornblower-severance.md": "body",
    ]

    @Test func shapes() {
        #expect(IDReport.shape(of: "E2-S3") == "A9-A9")
        #expect(IDReport.shape(of: "1.2") == "9.9")
        #expect(IDReport.shape(of: "ADR-004") == "AAA-999")
    }

    @Test func listsShapesPlacesAndCounts() throws {
        let repo = try makeRepo(named: "client-acme", Self.secretRepo)
        let rows = IDReport.build(index: RefIndex.build(repos: [repo]))
        let d = try #require(rows.first { $0.prefix == "D" && $0.place == .heading })
        #expect(d.shape == "A9" && d.ids == 2 && d.fileName == "decisions.md" && d.repo == 1 && d.resolved)
        #expect(d.mentions == 3)
        #expect(rows.contains { $0.prefix == "Q" && $0.place == .table && $0.fileName == "questions.md" })
        #expect(rows.contains { $0.place == .fileName && $0.fileName == "A9-….md" })
        let section = try #require(rows.first { $0.prefix == "§" })
        #expect(section.shape == "§9" && !section.recognised && section.mentions == 3)
        #expect(rows.contains { $0.shape == "9.9" && !$0.recognised && $0.mentions == 3 })
        #expect(rows.contains { $0.prefix == "ZZ" && !$0.resolved && $0.recognised })
    }

    @Test func rareUnrecognisedTokensAreLeftOut() throws {
        let repo = try makeRepo(named: "r", ["a.md": "Only §1 and §2 appear."])
        #expect(!IDReport.build(index: RefIndex.build(repos: [repo])).contains { $0.prefix == "§" })
    }

    @Test func neverHoldsTitlesTextOrPaths() throws {
        let repo = try makeRepo(named: "client-acme", Self.secretRepo)
        let rows = IDReport.build(index: RefIndex.build(repos: [repo]))
        let markdown = IDReport.markdown(rows: rows, version: "1.0")
        let json = String(decoding: try JSONEncoder().encode(rows), as: UTF8.self)
        for output in [markdown, json] {
            for secret in ["Zephyrwidget", "Hornblower", "Moonshot", "severance", "guilty", "acquisition",
                           "SecretFolderName", "client-acme", "idr-", "/docs", "/var", "/private", "Secret definition"] {
                #expect(!output.contains(secret), "leaked \(secret)")
            }
        }
        #expect(markdown.contains("repo 1"))
    }

    @Test func reposAreNumberedAlphabetically() throws {
        let b = try makeRepo(named: "bbb", ["x.md": "## D1 — t"])
        let a = try makeRepo(named: "aaa", ["y.md": "## D2 — t"])
        let rows = IDReport.build(index: RefIndex.build(repos: [b, a]))
        #expect(rows.first { $0.fileName == "y.md" }?.repo == 1)
        #expect(rows.first { $0.fileName == "x.md" }?.repo == 2)
    }
}
