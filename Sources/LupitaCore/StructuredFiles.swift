import Foundation

/// IDs defined in JSON, YAML and TOML files (D60). Reading them is cheap; trusting their shape is not: an object with an
/// `id` and a `title` is also a Figma node, a catalogue entry or a fixture. So such an ID defines something only when a
/// `.md` of the same repo cites it, and a `.md` that defines it wins.
public enum StructuredFiles {
    /// Reading every JSON, YAML and TOML outside the deny list was measured on 77 repos and did not hold: of 24 pairs
    /// (citation, definition) 3 were right (D60). Off; what is read is the closed list below. The code stays so the
    /// decision can be reopened with its data.
    public static let readsEverything = false
    /// Plan B, a closed list: Taskmaster's own task file. `tasks.json` anywhere else is an app's data or an editor's config.
    static func isClosedList(name: String, parents: [String]) -> Bool {
        name.lowercased() == "tasks.json" && parents.contains(".taskmaster")
    }

    /// Bigger files are skipped (lockfiles, exports, data dumps).
    public static let maxBytes = 2_000_000
    public static let extensions: Set<String> = ["json", "yaml", "yml", "toml"]

    /// Configuration that every project has, whatever it is about. The file name, lowercased.
    static let skippedNames: Set<String> = [
        "package.json", "package-lock.json", "npm-shrinkwrap.json", "composer.json", "composer.lock", "bower.json",
        "manifest.json", "tsconfig.json", "jsconfig.json", "deno.json", "tslint.json", "angular.json", "nx.json", "lerna.json",
        "turbo.json", "vercel.json", "netlify.toml", "renovate.json", "components.json", "firebase.json", "app.json", "eas.json",
        "cargo.toml", "pyproject.toml", "rustfmt.toml", "clippy.toml", "rust-toolchain.toml", "taplo.toml", "ruff.toml", "mise.toml",
        "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml", "pnpm-lock.yaml", "pnpm-workspace.yaml",
        "buf.yaml", "buf.gen.yaml", "mkdocs.yml", "mkdocs.yaml", "codecov.yml", "codecov.yaml", "dependabot.yml", "dependabot.yaml",
        "action.yml", "action.yaml", "pubspec.yaml", "pubspec.lock", "environment.yml", "environment.yaml", "conda.yaml",
        "azure-pipelines.yml", "appveyor.yml", "bitbucket-pipelines.yml", "serverless.yml", "serverless.yaml", "skaffold.yaml",
        "chart.yaml", "values.yaml", "kustomization.yaml", "config.yaml", "config.yml", "config.json", "settings.json",
        "launch.json", "extensions.json", "cspell.json", ".pre-commit-config.yaml", "_config.yml",
        "openapi.json", "openapi.yaml", "openapi.yml", "swagger.json", "swagger.yaml", "swagger.yml", "uv.lock",
    ]
    static let skippedPrefixes = ["tsconfig.", ".eslintrc", ".prettierrc", "docker-compose.", "babel.config", "jest.config",
                                  "vite.config", "tailwind.config"]
    static let skippedSuffixes = [".min.json", ".schema.json", "-lock.json", ".gen.json", ".lock"]
    /// Folders whose structured files are never read. The walk still enters them for `.md`.
    static let skippedDirs: Set<String> = [
        "node_modules", "dist", "build", "vendor", "venv", "pods", "deriveddata", "coverage", "target", "out", "bin", "obj",
        "site-packages", "locales", "locale", "i18n", "l10n", "translations", "lang", "archive", "archived", "worktrees",
    ]

    /// Whether the file at `parents` (folder names from the repo root) called `name` is read.
    static func isRead(name: String, parents: [String], everything: Bool = readsEverything) -> Bool {
        if !everything { return isClosedList(name: name, parents: parents) }
        let lower = name.lowercased()
        guard extensions.contains((lower as NSString).pathExtension), !lower.hasPrefix(".") else { return false }
        if parents.contains(where: { skippedDirs.contains($0.lowercased()) || $0.lowercased().hasSuffix("-worktrees") }) { return false }
        // A hidden folder is walked only when it is a framework's (`.taskmaster`); `tasks.json` there is Taskmaster's.
        if skippedNames.contains(lower) || skippedPrefixes.contains(where: lower.hasPrefix) || skippedSuffixes.contains(where: lower.hasSuffix) {
            return false
        }
        return true
    }

    /// A definition candidate found in a structured file, before anyone has cited it.
    struct Candidate: Equatable {
        let key: String
        let display: String
        let title: String
        let summary: String
        /// 1-based; 1 when the line could not be found.
        let line: Int
    }

    /// What a numeric ID means under a list called so: `"tasks": [{"id": 5}]` is `Task 5`.
    static let listWords: [String: String] = [
        "tasks": "Task", "subtasks": "Task", "stories": "Story", "epics": "Epic", "requirements": "Requirement",
    ]
    static let idFields = ["id", "key", "code"]
    static let titleFields = ["title", "name", "description", "summary"]

    static func candidates(fileName: String, text: String, everything: Bool = readsEverything) -> [Candidate] {
        guard fileName.lowercased().hasSuffix(".json"),
              let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var found: [Candidate] = []
        var cursor = 0
        let lines = text.components(separatedBy: "\n")
        func lineOf(_ field: String, _ value: String) -> Int {
            var i = cursor
            while i < lines.count {
                let l = lines[i]
                if l.contains("\"\(field)\""), l.contains(value) { cursor = i + 1; return i + 1 }
                i += 1
            }
            return 1
        }
        func walk(_ node: Any, word: String?, parentNumber: String?) {
            if let dict = node as? [String: Any] {
                var number: String? = nil
                if let field = idFields.first(where: { dict[$0] is String || dict[$0] is NSNumber }),
                   let title = titleFields.compactMap({ dict[$0] as? String }).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    let raw = (dict[field] as? String) ?? "\((dict[field] as? NSNumber)?.intValue ?? 0)"
                    let summary = (dict["description"] as? String).flatMap { $0 == title ? nil : $0 } ?? (dict["details"] as? String) ?? ""
                    if let word, raw.range(of: #"^\d{1,3}(?:\.\d{1,3})?$"#, options: .regularExpression) != nil {
                        let full = raw.contains(".") || parentNumber == nil ? raw : parentNumber! + "." + raw
                        number = full
                        if let id = IDGrammar.parse("\(word) \(full)") {
                            found.append(Candidate(key: id.key, display: id.display, title: Snippet.truncate(title), summary: Snippet.truncate(summary),
                                                   line: lineOf(field, raw)))
                        }
                    } else if everything, raw.rangeOfCharacter(from: .whitespaces) == nil, let id = IDGrammar.parse(raw), id.scope != .section {
                        found.append(Candidate(key: id.key, display: id.display, title: Snippet.truncate(title), summary: Snippet.truncate(summary),
                                               line: lineOf(field, raw)))
                    }
                }
                for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
                    walk(v, word: listWords[k.lowercased()] ?? (v is [Any] ? nil : word), parentNumber: number ?? parentNumber)
                }
            } else if let list = node as? [Any] {
                for v in list { walk(v, word: word, parentNumber: parentNumber) }
            }
        }
        walk(root, word: nil, parentNumber: nil)
        return found
    }
}
