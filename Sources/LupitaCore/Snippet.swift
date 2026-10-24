import Foundation

/// Builds the human-facing title and 2-3 line summary for a definition.
public enum Snippet {
    public static let maxLength = 280

    public static func build(for hit: DefinitionHit, lines: [String]) -> (title: String, summary: String) {
        switch hit.rule {
        case .heading, .section:
            let level = headingLevel(lines[hit.line])
            return (hit.title, body(lines, from: hit.line + 1, stopAtLevel: level))
        case .listOrColon:
            let indent = lines[hit.line].prefix { $0 == " " || $0 == "\t" }.count
            var parts = [hit.title]
            var i = hit.line + 1
            while i < lines.count, parts.count < 3 {
                let line = lines[i]
                let lead = line.prefix { $0 == " " || $0 == "\t" }.count
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty, lead > indent else { break }
                parts.append(clean(line))
                i += 1
            }
            return (firstSentence(hit.title), truncate(parts.joined(separator: " ")))
        case .tableRow:
            let cells = lines[hit.line].split(separator: "|").map { clean(String($0)) }.filter { !$0.isEmpty }
            return (hit.title, truncate(cells.dropFirst(2).joined(separator: " · ")))
        case .repo, .commit, .branch, .file, .command, .term:
            return (hit.title, "")  // built by RepoRefs or Glossary, never from an ID line
        case .fileName, .frontmatter:
            let headingLine = lines.firstIndex { $0.hasPrefix("# ") }
            let title = headingLine.map { DefinitionRules.cleanTitle(String(lines[$0].dropFirst(2))) } ?? hit.title
            let start = (headingLine ?? bodyStart(lines)) + 1
            return (title.isEmpty ? hit.title : title, body(lines, from: start, stopAtLevel: 1))
        }
    }

    static func body(_ lines: [String], from start: Int, stopAtLevel level: Int) -> String {
        var parts: [String] = []
        var inFence = false
        var i = start
        while i < lines.count, parts.count < 3 {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1
            if t.hasPrefix("```") { inFence.toggle(); continue }
            if inFence || t.isEmpty || t == "---" || t.allSatisfy({ "|-: ".contains($0) }) { continue }
            if t.hasPrefix("#") {
                if headingLevel(t) <= level { break }
                continue
            }
            parts.append(clean(t))
        }
        return truncate(parts.joined(separator: " "))
    }

    static func clean(_ line: String) -> String {
        var t = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- [ ] ", "- [x] ", "- ", "* ", "+ ", "> "] where t.hasPrefix(marker) {
            t.removeFirst(marker.count)
            break
        }
        return t.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " |"))
    }

    static func headingLevel(_ line: String) -> Int { line.prefix { $0 == "#" }.count }

    private static func bodyStart(_ lines: [String]) -> Int {
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return -1 }
        return end
    }

    private static func firstSentence(_ text: String) -> String {
        let s = text.components(separatedBy: ". ").first?.components(separatedBy: "; ").first ?? text
        return s.count > 90 ? String(s.prefix(89)) + "…" : s
    }

    static func truncate(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
    }
}
