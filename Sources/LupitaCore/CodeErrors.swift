import Foundation

extension CodeRefs {
    /// Errors and HTML tags (D29, type 5): one line from a fixed dictionary. `ENOENT`, `TypeError`,
    /// `HTTP 401`, `<dialog>`. Checked before symbols: the names are exact and a lookup in the repos would
    /// only cost time.
    enum Errors {
        static let tag = try! NSRegularExpression(pattern: #"^<(/?)([a-z][a-z0-9]*)(?:\s[^<>]*)?/?>?$"#)
        static let status = try! NSRegularExpression(pattern: #"^(?:(?:HTTP/?[\d.]*|status|error|code)\s*:?\s*)?(\d{3})(?:\s+([A-Za-z][A-Za-z ]*))?$"#, options: [.caseInsensitive])
        /// Words before a bare number that say it is a status code.
        static let statusHint = try! NSRegularExpression(
            pattern: #"\b(?:http|https|status|error|errors|response|responds?|returns?|returned|code|códigos?|estado|respuesta|devuelve|devolvió|falla|falló|fails?)\b"#,
            options: [.caseInsensitive])

        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            let t = text.text
            if let g = groups(tag, t), t.hasPrefix("<"), t.hasSuffix(">") || g[0] == "<" + g[2] {
                guard let entry = CodeDictionaries.tag(g[2]) else { return nil }
                let shown = t.count > 40 ? "<" + g[1] + g[2] + ">" : t
                return [definition(shown, entry.text, rule: .tag)]
            }
            if let entry = CodeDictionaries.error(t) { return [definition(t, entry.text, rule: .error)] }
            if let g = groups(status, t), let code = Int(g[1]), let entry = CodeDictionaries.status(code) {
                let prefixed = t.lowercased().hasPrefix("http") || t.lowercased().hasPrefix("status") || t.lowercased().hasPrefix("error") || t.lowercased().hasPrefix("code")
                let hasName = !g[2].isEmpty && entry.en.lowercased().contains(g[2].lowercased().trimmingCharacters(in: .whitespaces))
                if prefixed || hasName || text.codeMarked || matches(statusHint, text.before) {
                    return [definition(String(code), entry.text, rule: .error)]
                }
            }
            return nil
        }

        static func definition(_ id: String, _ line: String, rule: DefinitionRule) -> Definition {
            Definition(id: id, key: id, repo: "", path: "", line: 0, rule: rule, title: line, summary: "", absolutePath: "")
        }
    }
}
