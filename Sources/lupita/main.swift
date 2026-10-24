import Foundation
import LupitaCore

let usage = """
usage:
  lupita index <dir…> [--out index.json]     build the index and print stats
  lupita <ID> [--repo NAME] [--roots dir…]   resolve an ID (default roots: ~/Repos)
  lupita onboarding [dir…] [--prompt|--convert]  repos with agents: undefined citations and rule state
  lupita terms <dir…> [--sample N]           sample (seed 42) of generic-pattern term hits outside glossaries
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
    if let query = take("--query", &args) { info["query"] = query }
    if let repo = take("--repo", &args) { info["repo"] = repo }
    if let at = take("--at", &args) { info["at"] = at }
    // With --onboarding, it opens the "Prepare your repos" window instead.
    if args.contains("--onboarding") { info["onboarding"] = "1" }
    DistributedNotificationCenter.default().postNotificationName(
        .init("com.manubarranco.lupita.lookup"), object: nil, userInfo: info.isEmpty ? nil : info, deliverImmediately: true)

case "onboarding":
    args.removeFirst()
    let wantsPrompt = args.contains("--prompt"), wantsConvert = args.contains("--convert")
    args.removeAll { $0 == "--prompt" || $0 == "--convert" }
    if wantsPrompt { print(Onboarding.rulePrompt()) }
    else if wantsConvert { print(Onboarding.conversionPrompt()) }
    else {
        let index = RefIndex.build(roots: args.isEmpty ? ["~/Repos"] : args)
        for row in Onboarding.status(of: index) {
            print("\(row.repo.name)\t\(S.undefinedCitations(row.undefinedCitations))\t\(row.ruleInstalled ? S.ruleInstalled : S.ruleMissing)")
        }
    }

case "terms":
    args.removeFirst()
    let n = take("--sample", &args).flatMap(Int.init) ?? 40
    for (i, d) in Report.looseTermSample(roots: args.isEmpty ? ["~/Repos"] : args, count: n).enumerated() {
        print("\(i + 1)\t[\(d.repo)] \(d.path):\(d.line)\t\(d.id) — \(d.summary.prefix(110))")
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
    let resolution = Resolver(index: RefIndex.build(roots: roots)).resolve(query, preferredRepo: repo)
    print(Report.describe(resolution))
}
