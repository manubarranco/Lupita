import Foundation

extension CodeRefs {
    /// Terminal commands (D29, type 4): `npm run x` from the repo's `package.json`; git and common shell
    /// commands from a fixed dictionary (`CodeDictionaries`).
    enum Commands {
        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            var line = text.text
            for prompt in ["$ ", "> ", "% "] where line.hasPrefix(prompt) { line = String(line.dropFirst(prompt.count)) }
            let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let first = tokens.first, tokens.count <= 8, first.first?.isLetter == true else { return nil }
            let args = Array(tokens.dropFirst())

            if CodeDictionaries.managers.contains(first) {
                if let sub = args.first(where: { !$0.hasPrefix("-") }) {
                    var script: String?
                    if sub == "run" || sub == "run-script" {
                        script = args.drop { $0 != sub }.dropFirst().first { !$0.hasPrefix("-") }
                    } else if first != "npm" || ["test", "start", "stop", "restart"].contains(sub) {
                        script = sub
                    }
                    if let script, let defs = scripts(named: script, command: tokens.prefix(through: tokens.firstIndex(of: script) ?? 0).joined(separator: " "), repos: repos) {
                        return defs
                    }
                    if TermPackages.isOn(.terminal), let d = CodeDictionaries.packageCommands[sub] {
                        return [builtin(tokens.prefix(2).joined(separator: " "), S.isSpanish ? d.es : d.en, notes: notes(args))]
                    }
                }
                return nil
            }

            let subKey = args.first.flatMap { $0.hasPrefix("-") ? nil : first + " " + $0 }
            guard let entry = subKey.flatMap({ CodeDictionaries.command($0) }) ?? CodeDictionaries.command(first),
                  entry.safe || text.codeMarked else { return nil }
            // A bare word of a few letters is a command only when it stands alone or is followed by arguments that look like one.
            if tokens.count == 1, entry.key.contains(" ") { return nil }
            let shown = entry.key.contains(" ") ? tokens.prefix(entry.key.split(separator: " ").count + 1).joined(separator: " ") : tokens.prefix(2).joined(separator: " ")
            return [builtin(tokens.count == 1 ? first : shown, entry.text, notes: notes(args))]
        }

        static func builtin(_ id: String, _ description: String, notes: [String]) -> Definition {
            Definition(id: id, key: id, repo: "", path: "", line: 0, rule: .terminal, title: description,
                       summary: notes.joined(separator: "\n"), absolutePath: "")
        }

        static func notes(_ args: [String]) -> [String] {
            var out: [String] = []
            for a in args {
                if let n = CodeDictionaries.flagNotes[a] { out.append(S.isSpanish ? n.es : n.en) }
                // `-am`, `-rf`: bundled single-letter flags
                else if a.hasPrefix("-"), !a.hasPrefix("--"), a.count > 2 {
                    for ch in a.dropFirst() { if let n = CodeDictionaries.flagNotes["-" + String(ch)] { out.append(S.isSpanish ? n.es : n.en) } }
                }
            }
            var seen = Set<String>()
            return out.filter { seen.insert($0).inserted }.prefix(2).map { $0 }
        }

        // MARK: package.json

        /// The `scripts` entry `name` in the first repo that has it (the window's repo first).
        static func scripts(named name: String, command: String, repos: [Repo]) -> [Definition]? {
            for repo in repos {
                var found: [Definition] = []
                for file in packageFiles(in: repo) {
                    guard let data = FileManager.default.contents(atPath: file),
                          let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                          let scripts = json["scripts"] as? [String: Any], let body = scripts[name] as? String else { continue }
                    let text = String(decoding: data, as: UTF8.self)
                    let line = lineOfScript(name, in: text)
                    found.append(Definition(id: command, key: "\(repo.name)/\(file)#\(name)", repo: repo.name,
                                            path: Tokens.relative(file, in: repo), line: line, rule: .terminal,
                                            title: S.runsScript(body), summary: "", absolutePath: file))
                }
                if !found.isEmpty { return found }
            }
            return nil
        }

        /// `package.json` at the root and one or two folders down (`apps/web`, `packages/ui`, `web`).
        static func packageFiles(in repo: Repo) -> [String] {
            let fm = FileManager.default
            var out: [String] = []
            func add(_ dir: String) {
                let file = dir + "/package.json"
                if fm.fileExists(atPath: file) { out.append(file) }
            }
            func children(_ dir: String) -> [String] {
                ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).sorted().filter {
                    !$0.hasPrefix(".") && !Symbols.skippedDirs.contains($0) && !RepoDiscovery.isSkipped($0)
                }.map { dir + "/" + $0 }.filter { var d: ObjCBool = false; return fm.fileExists(atPath: $0, isDirectory: &d) && d.boolValue }
            }
            add(repo.path)
            for child in children(repo.path) {
                add(child)
                if ["apps", "packages", "services"].contains((child as NSString).lastPathComponent) { children(child).forEach(add) }
            }
            return out
        }

        static func lineOfScript(_ name: String, in text: String) -> Int {
            let lines = text.components(separatedBy: "\n")
            guard let start = lines.firstIndex(where: { $0.contains("\"scripts\"") }) else { return 1 }
            for (i, l) in lines.enumerated().dropFirst(start) where l.contains("\"\(name)\"") { return i + 1 }
            return start + 1
        }
    }
}
