import Foundation

extension CodeRefs {
    /// Pull requests (D29, type 6): `#123`, `PR 123`, `PR #123`. The title and date of the merge that closed
    /// it, read from the local git history (`Merge pull request #123 from …` or a squash `Title (#123)`).
    /// Open PRs need the network and stay out (D26).
    enum PullRequests {
        static let shape = try! NSRegularExpression(pattern: #"^(?:(?:PR|pull request)\s*#?\s*|#)(\d{1,6})$"#, options: [.caseInsensitive])

        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            guard let g = groups(shape, text.text), let number = Int(g[1]), number > 0 else { return nil }
            let explicit = !text.text.hasPrefix("#")
            // The window's repo only: another repo's `#123` is a different pull request.
            let searched = preferredRepo.map { name in repos.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame } } ?? repos
            if Git.executable != nil {
                // One git process per repo, all at once: with no window repo every repo is asked.
                let box = Results(count: searched.count)
                DispatchQueue.concurrentPerform(iterations: searched.count) { i in box.set(i, merged(number, in: searched[i])) }
                if let d = box.first { return [d] }
            }
            // `#333` with no such PR is a colour.
            if !explicit, [3, 4].contains(g[1].count), let colour = Tokens.color(g[1], repos: repos) { return colour }
            guard explicit || g[1].count > 1 else { return nil }
            let id = "#\(number)"
            return [Definition(id: id, key: id, repo: searched.count == 1 ? searched[0].name : "", path: "", line: 0, rule: .pullRequest,
                               title: S.prNotInHistory, summary: "", absolutePath: "")]
        }

        /// Slots written from several threads, read in order afterwards.
        final class Results: @unchecked Sendable {
            private let lock = NSLock()
            private var slots: [Definition?]
            init(count: Int) { slots = Array(repeating: nil, count: count) }
            func set(_ i: Int, _ d: Definition?) { lock.lock(); slots[i] = d; lock.unlock() }
            var first: Definition? { lock.lock(); defer { lock.unlock() }; return slots.compactMap { $0 }.first }
        }

        static func merged(_ number: Int, in repo: Repo) -> Definition? {
            let args = ["log", "--all", "-1", "-E", "--grep=^Merge pull request #\(number) ", "--grep=\\(#\(number)\\)$",
                        "--format=%H%x1f%s%x1f%ad%x1f%b", "--date=short"]
            guard let f = Git.fields(repo.path, args), f.count >= 3 else { return nil }
            let (sha, subject, date) = (f[0], f[1], f[2])
            let body = f.count > 3 ? f[3].split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } : nil
            let isMerge = subject.hasPrefix("Merge pull request #")
            var branch = ""
            if isMerge, let from = subject.range(of: " from ") { branch = String(subject[from.upperBound...]) }
            // A merge with no description has only its branch name to say what it was.
            let title = isMerge ? (body ?? (branch.isEmpty ? subject : branch)) : subject.replacingOccurrences(of: " (#\(number))", with: "")
            let summary = [S.mergedOn(date), branch.isEmpty || branch == title ? "" : branch].filter { !$0.isEmpty }.joined(separator: " · ")
            let web = Git.webURL(repo.path)
            var d = Definition(id: "#\(number)", key: sha, repo: repo.name, path: "", line: 0, rule: .pullRequest,
                               title: title, summary: summary, absolutePath: repo.path)
            d.openURL = web.map { "\($0)/pull/\(number)" }
            return d
        }
    }
}
