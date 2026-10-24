import Foundation

/// Which repos have coding agents, how many citations in them nothing defines, and whether
/// the Lupita rule is already in their instructions (D21). Read-only: Lupita never writes in
/// a user's repo; it hands the user a prompt for their own agent.
public struct RepoOnboarding: Hashable, Sendable {
    public let repo: Repo
    /// Agent instruction files found, relative to the repo root.
    public let agentFiles: [String]
    /// Mentions of IDs that nothing defines in this repo.
    public let undefinedCitations: Int
    /// The `<!-- lupita -->` marker is in one of the agent files.
    public let ruleInstalled: Bool
}

public enum Onboarding {
    public static let marker = "<!-- lupita -->"

    /// Files and folders that tell a coding agent how to work in a repo.
    public static let agentFileNames = [
        "AGENTS.md", "CLAUDE.md", ".cursorrules", ".windsurfrules", ".github/copilot-instructions.md",
    ]
    public static let agentFolders = [".cursor/rules"]

    /// The agent instruction files of a repo, relative to its root.
    public static func agentFiles(in repo: Repo) -> [String] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: repo.path)
        var found = agentFileNames.filter { fm.fileExists(atPath: root.appendingPathComponent($0).path) }
        for folder in agentFolders {
            let url = root.appendingPathComponent(folder)
            let items = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            found += items.sorted().filter { !$0.hasPrefix(".") }.map { folder + "/" + $0 }
        }
        return found
    }

    /// Whether any of the files carries the marker.
    public static func hasRule(in repo: Repo, files: [String]) -> Bool {
        files.contains { file in
            let url = URL(fileURLWithPath: repo.path).appendingPathComponent(file)
            return (try? String(contentsOf: url, encoding: .utf8))?.contains(marker) == true
        }
    }

    /// Mentions in `repo`'s files of IDs that no definition in `repo` covers.
    public static func undefinedCitations(of repo: Repo, in index: RefIndex) -> Int {
        let prefix = repo.name + "/"
        var total = 0
        for (key, mentions) in index.mentions {
            if index.definitions[key]?.contains(where: { $0.repo == repo.name }) == true { continue }
            total += mentions.byFile.filter { $0.key.hasPrefix(prefix) }.values.reduce(0, +)
        }
        return total
    }

    /// Status of every repo with agent files, most undefined citations first.
    public static func status(of index: RefIndex) -> [RepoOnboarding] {
        index.repos.compactMap { repo in
            let files = agentFiles(in: repo)
            guard !files.isEmpty else { return nil }
            return RepoOnboarding(repo: repo, agentFiles: files,
                                  undefinedCitations: undefinedCitations(of: repo, in: index),
                                  ruleInstalled: hasRule(in: repo, files: files))
        }.sorted { ($1.undefinedCitations, $0.repo.name) < ($0.undefinedCitations, $1.repo.name) }
    }

    /// The block the agent appends to the repo's instructions.
    public static let ruleBlock = """
        \(marker)
        Define every decision, question, lesson or story you create as a heading `## ID — Title`
        followed by a one-line summary. Add each new internal term to `docs/glossary.md` as
        `- **term** — definition`. Cite both by ID or term elsewhere.
        <!-- /lupita -->
        """

    /// Short prompt: add the rule block. In the Mac's language.
    public static func rulePrompt(spanish: Bool = S.isSpanish) -> String {
        let intro = spanish
            ? "Añade este bloque al final del archivo de instrucciones de agentes de este repo (AGENTS.md si existe; si no, CLAUDE.md), sin cambiar nada más, y haz commit."
            : "Add this block at the end of this repo's agent instructions file (AGENTS.md if it exists; otherwise CLAUDE.md), without changing anything else, and commit."
        return intro + "\n\n```markdown\n" + ruleBlock + "\n```"
    }

    /// Optional prompt: convert what already exists. Touches several files.
    public static func conversionPrompt(spanish: Bool = S.isSpanish) -> String {
        spanish
            ? """
              Pasa las decisiones, lecciones, preguntas, stories y términos internos que ya existen en este repo al formato de esta regla, sin cambiar su contenido: cada una como un encabezado `## ID — Título` seguido de un resumen de una línea, y cada término en `docs/glossary.md` como `- **término** — definición`. Esto toca varios archivos; hazlo en un solo commit.
              """
            : """
              Convert the decisions, lessons, questions, stories and internal terms that already exist in this repo to the format of this rule, without changing their content: each one as a heading `## ID — Title` followed by a one-line summary, and each term in `docs/glossary.md` as `- **term** — definition`. This touches several files; do it in a single commit.
              """
    }
}
