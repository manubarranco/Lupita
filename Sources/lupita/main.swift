import Foundation
import LupitaCore

let usage = """
usage:
  lupita index <dir…> [--out index.json]     build the index and print stats
  lupita <ID|text> [--repo NAME] [--roots dir…] [--time]  resolve an ID or anything else Lupita knows (default roots: ~/Repos)
  lupita onboarding [dir…] [--prompt|--convert]  repos with agents: undefined citations and rule state
  lupita terms <dir…> [--sample N]           sample (seed 42) of generic-pattern term hits outside glossaries
  lupita batch [--repo NAME] [--roots dir…]  resolve each line of stdin; tab-separated result per line (measuring)
  lupita report <dir…> [--out reports]       write the accuracy report (HTML + sample JSON)
"""

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { print(usage); exit(1) }

func take(_ flag: String, _ args: inout [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}

func takeList(_ flag: String, _ args: inout [String]) -> [String]? {
    guard let i = args.firstIndex(of: flag) else { return nil }
    let values = Array(args[(i + 1)...].prefix { !$0.hasPrefix("--") })
    args.removeSubrange(i...(i + values.count))
    return values
}

switch command {
case "index":
    args.removeFirst()
    let out = take("--out", &args)
    let start = Date()
    let index = RefIndex.build(roots: args.isEmpty ? ["~/Repos"] : args)
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    print("\(index.repos.count) repos · \(index.fileCount) files · \(index.definitions.count) defined IDs · \(ms) ms")
    for repo in index.repos {
        let n = index.definitions.values.filter { $0.contains { $0.repo == repo.name } }.count
        print("  \(repo.name): \(n)")
    }
    if let out { try index.save(to: URL(fileURLWithPath: out)); print("saved \(out)") }

case "poke":
    // Asks the running app to look up the ID under the mouse, as if the hotkey was pressed.
    // With --query, it resolves that text instead (logged, not shown): `lupita poke --query D001 --repo atlas`.
    // With --query and --at x,y (screen points, origin bottom-left), it is also shown there.
    // With --lens, it shows the lens for that many seconds instead, as if the chord was held.
    args.removeFirst()
    var info: [String: String] = [:]
    if let lens = take("--lens", &args) { info["lens"] = lens }
    // With --hold, the highlight (or the welcome step's) for that many seconds, then released.
    if let hold = take("--hold", &args) { info["hold"] = hold }
    if let query = take("--query", &args) { info["query"] = query }
    if let repo = take("--repo", &args) { info["repo"] = repo }
    if let at = take("--at", &args) { info["at"] = at }
    // With --onboarding, it opens the "Prepare your repos" window instead.
    if args.contains("--onboarding") { info["onboarding"] = "1" }
    // With --tutorial, the welcome step (D56).
    if args.contains("--tutorial") { info["tutorial"] = "1" }
    // With --about, the About panel.
    if args.contains("--about") { info["about"] = "1" }
    if args.contains("--menu") { info["menu"] = args.contains("--confirm") ? "confirm" : args.contains("--expand") ? "expand" : "1" }
    DistributedNotificationCenter.default().postNotificationName(
        .init("com.manubarranco.lupita.lookup"), object: nil, userInfo: info.isEmpty ? nil : info, deliverImmediately: true)

case "onboarding":
    args.removeFirst()
    let wantsPrompt = args.contains("--prompt")
    args.removeAll { $0 == "--prompt" }
    if wantsPrompt { print(Onboarding.prompt) }
    else {
        let index = RefIndex.build(roots: args.isEmpty ? ["~/Repos"] : args)
        let rows = Onboarding.status(of: index)
        for row in rows {
            print("\(row.repo.name)\t\(S.undefinedCitations(row.undefinedCitations))\t\(row.ruleInstalled ? S.ruleInstalled : S.ruleMissing)")
        }
        if let percent = Onboarding.explainedPercent(of: rows.map(\.repo), in: index) { print("explained: \(percent) %") }
    }

case "terms":
    args.removeFirst()
    let n = take("--sample", &args).flatMap(Int.init) ?? 40
    for (i, d) in Report.looseTermSample(roots: args.isEmpty ? ["~/Repos"] : args, count: n).enumerated() {
        print("\(i + 1)\t[\(d.repo)] \(d.path):\(d.line)\t\(d.id) — \(d.summary.prefix(110))")
    }

case "batch":
    // Development aid: one text per line on stdin, resolved with one index. Prints
    // `text<TAB>kind<TAB>rule<TAB>has-comment<TAB>ms` for measuring coverage over a corpus.
    args.removeFirst()
    let repo = take("--repo", &args)
    let roots = takeList("--roots", &args) ?? ["~/Repos"]
    let resolver = Resolver(index: RefIndex.build(roots: roots))
    while let line = readLine() {
        let start = Date()
        let r = resolver.resolve(line, preferredRepo: repo)
        let d = r.definitions.first
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        print("\(line)\t\(r.kind.rawValue)\t\(d?.rule.rawValue ?? "-")\t\(d.map { $0.rule == .symbol ? ($0.title.isEmpty ? "no" : "yes") : "-" } ?? "-")\t\(ms)")
    }

case "report":
    args.removeFirst()
    let out = take("--out", &args) ?? "reports"
    let index = RefIndex.build(roots: args.isEmpty ? ["~/Repos"] : args)
    let path = try Report.write(index: index, to: URL(fileURLWithPath: out))
    print("report: \(path)")

default:
    let query = args.removeFirst()
    let repo = take("--repo", &args)
    let roots = takeList("--roots", &args) ?? ["~/Repos"]
    let timed = args.contains("--time")
    let resolver = Resolver(index: RefIndex.build(roots: roots))
    let start = Date()
    let resolution = resolver.resolve(query, preferredRepo: repo)
    print(Report.describe(resolution))
    // The lookup alone, without building the index: D29 gives code lookups 300 ms.
    if timed { print("lookup: \(Int(Date().timeIntervalSince(start) * 1000)) ms") }
}
