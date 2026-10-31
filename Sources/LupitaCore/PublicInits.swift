import Foundation

// Public builders for the answer types, so the app's galleries can make the states of the design system by hand
// (the memberwise initialisers are internal). They add no behaviour.

extension Definition {
    public static func made(id: String, key: String? = nil, repo: String = "", path: String = "", line: Int = 0, rule: DefinitionRule,
                            title: String, summary: String = "", absolutePath: String = "", colors: [ColorSample]? = nil) -> Definition {
        var d = Definition(id: id, key: key ?? id, repo: repo, path: path, line: line, rule: rule, title: title, summary: summary,
                           absolutePath: absolutePath)
        d.colors = colors
        return d
    }
}

extension Mentions {
    public static func made(byFile: [String: Int]) -> Mentions {
        var m = Mentions()
        m.byFile = byFile
        return m
    }
}

extension Resolution {
    public static func made(query: String, kind: Kind = .exact, key: String?, definitions: [Definition], mentions: Mentions? = nil,
                            fromOtherRepo: Bool = false, range: RangeList? = nil) -> Resolution {
        var r = Resolution(query: query, kind: kind, key: key, definitions: definitions, mentions: mentions, alternatives: [])
        r.fromOtherRepo = fromOtherRepo
        r.range = range
        return r
    }
}

extension RangeList {
    public static func made(entries: [(id: String, definition: Definition?)], noun: String, sharedRepo: String?, sharedPath: String?) -> RangeList {
        RangeList(entries: entries.map { Entry(id: $0.id, definition: $0.definition) }, noun: noun, sharedRepo: sharedRepo, sharedPath: sharedPath)
    }
}

extension Repo {
    public static func made(name: String, path: String) -> Repo { Repo(name: name, path: path) }
}
