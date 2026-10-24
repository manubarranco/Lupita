import Foundation

extension CodeRefs {
    /// Functions, classes, variables, constants, dictionary keys and test names (D29, type 1): their own
    /// comment and where they are defined. Looked up in the source files at the moment of pointing.
    enum Symbols {
        enum Kind: Int { case function, type, constant, cssClass, key, file }

        struct Hit {
            var kind: Kind
            var path: String
            var absolute: String
            var line: Int
            var indent: Int
            var comment: [String]
        }

        static let extensions: Set<String> = ["py", "js", "mjs", "ts", "tsx", "jsx", "swift", "astro", "css", "scss"]
        static let skippedDirs: Set<String> = [
            "node_modules", "build", "dist", ".build", "archive", "archived", "venv", ".venv", "__pycache__",
            "Pods", "DerivedData", "vendor", ".next", ".git",
        ]
        static let maxFileSize = 800_000
        static let maxHits = 5
        static let maxCommentLines = 3

        // MARK: Entry

        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            guard let name = symbolName(text) else { return nil }
            var places = repos.map { (label: $0.name, home: $0.name, root: $0.path) }
            for lazyWorktrees in [false, true] {
                if lazyWorktrees {
                    places = repos.flatMap { repo in worktrees(of: repo).map { (label: "\(repo.name) · \(($0 as NSString).lastPathComponent)", home: repo.name, root: $0) } }
                }
                for place in places {
                    let hits = find(name, in: place.root)
                    guard !hits.isEmpty else { continue }
                    return hits.prefix(maxHits).map { definition(name, hit: $0, repo: place.label) }
                }
            }
            return nil
        }

        /// The identifier to search for, or nil when the text is not shaped like code: a plain lowercase
        /// word (`slider`) is noise unless it is called (`slider()`) or between backticks.
        static func symbolName(_ text: Text) -> String? {
            let ns = text.text as NSString
            guard let m = callForm.firstMatch(in: text.text, range: NSRange(location: 0, length: ns.length)) else { return nil }
            let name = ns.substring(with: m.range(at: 1))
            let called = m.range(at: 2).location != NSNotFound
            guard name.count >= 4 else { return nil }
            let shaped = called || text.codeMarked || name.contains("_") || camel(name)
            return shaped ? name : nil
        }

        /// `name`, `name()`, `name(args)`, `obj.method()`, `Class.member`: the last component is the symbol.
        static let callForm = try! NSRegularExpression(pattern: #"^(?:[A-Za-z_$][\w$]*\.)*([A-Za-z_$][\w$]*)(\(.*\)?)?$"#)
        static let camelHump = try! NSRegularExpression(pattern: #"[a-z0-9][A-Z]|[A-Z][a-z]+[A-Z]"#)

        static func camel(_ name: String) -> Bool { matches(camelHump, name) }

        // MARK: Files

        /// Absolute paths of the source files of a checkout. Walked with `readdir`: FileManager's
        /// enumerator took 100 ms on a checkout of 10 000 files, this takes a few.
        static func sourceFiles(in root: String, extensions exts: Set<String> = extensions) -> [String] {
            let key = root + "|" + exts.sorted().joined(separator: ",")
            if let cached = FileListCache.shared.get(key) { return cached }
            var out: [String] = []
            walk(root, isRoot: true, extensions: exts, into: &out)
            out.sort()
            FileListCache.shared.set(key, out)
            return out
        }

        private static func walk(_ dir: String, isRoot: Bool, extensions exts: Set<String>, into out: inout [String]) {
            guard let handle = opendir(dir) else { return }
            defer { closedir(handle) }
            var files: [String] = [], folders: [String] = []
            var hasGit = false
            while let entry = readdir(handle) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
                }
                if name == ".git" { hasGit = true; continue }
                if name.hasPrefix(".") { continue }
                switch Int32(entry.pointee.d_type) {
                case Int32(DT_DIR):
                    if !skippedDirs.contains(name), !name.hasSuffix("-worktrees") { folders.append(name) }
                case Int32(DT_REG):
                    if exts.contains((name as NSString).pathExtension.lowercased()) { files.append(name) }
                default: break
                }
            }
            // A nested repo or a linked worktree is searched on its own.
            if hasGit && !isRoot { return }
            out += files.map { dir + "/" + $0 }
            for folder in folders { walk(dir + "/" + folder, isRoot: false, extensions: exts, into: &out) }
        }

        /// Linked worktrees of a repo, read from `.git/worktrees/*/gitdir` (no git process: spawning one
        /// per repo cost 90 ms each). Never the repo itself.
        static func worktrees(of repo: Repo) -> [String] {
            let admin = repo.path + "/.git/worktrees"
            let names = (try? FileManager.default.contentsOfDirectory(atPath: admin)) ?? []
            return names.sorted().compactMap { name -> String? in
                guard let text = try? String(contentsOfFile: admin + "/" + name + "/gitdir", encoding: .utf8) else { return nil }
                var path = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if path.hasSuffix("/.git") { path.removeLast(5) }
                return FileManager.default.fileExists(atPath: path) ? RepoDiscovery.realPath(path) : nil
            }
        }

        // MARK: Search

        static func find(_ name: String, in root: String) -> [Hit] {
            let needle = Data(name.utf8)
            var hits: [Hit] = []
            for path in sourceFiles(in: root) {
                let relative = path.hasPrefix(root + "/") ? String(path.dropFirst(root.count + 1)) : path
                let ext = (path as NSString).pathExtension.lowercased()
                // `test_engine` is the file `test_engine.py`; a plain word (`slider`) is not a file name here.
                let named = ["py", "js", "mjs", "ts", "tsx", "jsx"].contains(ext)
                    && (name.hasPrefix("test") || name.contains("_") || camel(name))
                    && ((path as NSString).lastPathComponent as NSString).deletingPathExtension == name
                var info = stat()
                guard stat(path, &info) == 0, info.st_size <= maxFileSize,
                      let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
                let offsets = occurrences(of: needle, in: data)
                guard named || !offsets.isEmpty else { continue }
                let style = Style(ext: ext)
                var lines: [String]?
                func allLines() -> [String] {
                    if lines == nil { lines = String(decoding: data, as: UTF8.self).components(separatedBy: "\n") }
                    return lines!
                }
                if !offsets.isEmpty {
                    let list = patterns(for: name, style: style, ext: ext)
                    var seenLine = -1
                    for offset in offsets {
                        let (start, end) = lineBounds(data, around: offset)
                        guard start != seenLine else { continue }
                        seenLine = start
                        let text = String(decoding: data[start..<end], as: UTF8.self)
                        for pattern in list {
                            guard let g = groups(pattern.regex, text) else { continue }
                            let kind = pattern.kind(g.count > 1 ? g[1] : "")
                            let number = newlines(in: data, before: start)
                            let all = allLines()
                            hits.append(Hit(kind: kind, path: relative, absolute: path, line: number + 1,
                                            indent: text.prefix { $0 == " " || $0 == "\t" }.count,
                                            comment: comment(of: kind, lines: all, at: number, style: style)))
                            break
                        }
                        if hits.count >= 12 { break }
                    }
                }
                if named { hits.append(moduleHit(lines: allLines(), style: style, path: relative, absolute: path)) }
            }
            let sorted = hits.sorted { a, b in
                (a.kind.rawValue, a.comment.isEmpty ? 1 : 0, a.indent, a.path, a.line) < (b.kind.rawValue, b.comment.isEmpty ? 1 : 0, b.indent, b.path, b.line)
            }
            // Snapshots of a file (`engine.py`, `reference_engine_pre_x.py`) repeat the same comment: show it once.
            var seen = Set<String>()
            return sorted.filter { hit in hit.comment.isEmpty || seen.insert(hit.comment.joined(separator: "\n")).inserted }
        }

        /// Byte offsets where `needle` starts in `data` (at most 200: a name that frequent is noise anyway).
        static func occurrences(of needle: Data, in data: Data) -> [Int] {
            var out: [Int] = []
            data.withUnsafeBytes { hay in
                needle.withUnsafeBytes { n in
                    guard let h = hay.baseAddress, let nn = n.baseAddress, hay.count >= n.count else { return }
                    var from = 0
                    while from <= hay.count - n.count, out.count < 200,
                          let p = memmem(h + from, hay.count - from, nn, n.count) {
                        let at = h.distance(to: p)
                        out.append(at)
                        from = at + 1
                    }
                }
            }
            return out
        }

        /// The line (byte range, without the newline) that contains `offset`.
        static func lineBounds(_ data: Data, around offset: Int) -> (Int, Int) {
            var start = offset, end = offset
            let base = data.startIndex
            while start > 0, data[base + start - 1] != 10 { start -= 1 }
            while end < data.count, data[base + end] != 10 { end += 1 }
            return (start, end)
        }

        static func newlines(in data: Data, before offset: Int) -> Int {
            data.withUnsafeBytes { $0.prefix(offset).reduce(0) { $1 == 10 ? $0 + 1 : $0 } }
        }

        enum Style {
            case python, script, swift, css
            init(ext: String) {
                switch ext {
                case "py": self = .python
                case "swift": self = .swift
                case "css", "scss": self = .css
                default: self = .script
                }
            }
        }

        struct Pattern {
            let regex: NSRegularExpression
            let kind: (String) -> Kind
        }

        static func patterns(for name: String, style: Style, ext: String) -> [Pattern] {
            let n = NSRegularExpression.escapedPattern(for: name)
            func p(_ s: String, _ k: @escaping (String) -> Kind) -> Pattern { Pattern(regex: try! NSRegularExpression(pattern: s), kind: k) }
            switch style {
            case .python:
                return [
                    p(#"^\s*(?:async\s+)?def\s+\#(n)(?![\w])"#) { _ in .function },
                    p(#"^\s*class\s+\#(n)(?![\w])"#) { _ in .type },
                    p(#"^\s*\#(n)\s*(?::[^=]+)?=(?!=)"#) { _ in .constant },
                    p(#"^\s*[rbuf]?["']\#(n)["']\s*:"#) { _ in .key },
                ]
            case .swift:
                let modifiers = #"(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|open|package|static|final|override|mutating|nonisolated(?:\(unsafe\))?|indirect|lazy|weak|required|convenience)\s+)*"#
                return [
                    p(#"^\s*\#(modifiers)(func|let|var|class|struct|enum|protocol|typealias|actor|case)\s+\#(n)(?![\w])"#) { kw in
                        switch kw { case "func": .function; case "let", "var", "case": .constant; default: .type }
                    }
                ]
            case .css:
                return [
                    p(#"^\s*@keyframes\s+\#(n)(?![\w-])"#) { _ in .cssClass },
                    p(#"^[^{}\n/]*\.\#(n)(?![\w-])[^{}]*\{"#) { _ in .cssClass },
                ]
            case .script:
                var list = [
                    p(#"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\*?\s+\#(n)(?![\w$])"#) { _ in .function },
                    p(#"^\s*(?:export\s+)?(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(class|interface|enum|type|namespace)\s+\#(n)(?![\w$])"#) { _ in .type },
                    p(#"^\s*(?:export\s+)?(?:declare\s+)?(?:const|let|var)\s+\#(n)(?![\w$])"#) { _ in .constant },
                    p(#"^\s*(?:(?:public|private|protected|static|async|get|set|readonly|override)\s+)*\#(n)\s*(?:<[^>]*>)?\s*\([^;]*\)\s*(?::\s*[^{;=]+)?\{\s*$"#) { _ in .function },
                    p(#"^\s*\#(n)\s*:\s*(?:async\s+)?(?:function\b|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)"#) { _ in .function },
                    p(#"^\s*(?:this\.|window\.|exports\.|module\.exports\.)?\#(n)\s*=(?![=>])"#) { _ in .constant },
                    p(#"^\s*["']?\#(n)["']?\??\s*:"#) { _ in .key },
                ]
                if ext == "astro" {
                    list.append(p(#"^[^{}\n/]*\.\#(n)(?![\w-])[^{}]*\{"#) { _ in .cssClass })
                }
                return list
            }
        }

        /// `test_engine` → the file `test_engine.py` and its leading docstring or comment.
        static func moduleHit(lines: [String], style: Style, path: String, absolute: String) -> Hit {
            Hit(kind: .file, path: path, absolute: absolute, line: 1, indent: 0, comment: moduleComment(lines, style: style))
        }

        // MARK: Comments

        static func comment(of kind: Kind, lines: [String], at i: Int, style: Style) -> [String] {
            var result: [String] = []
            if style == .python, kind == .function || kind == .type, let doc = docstring(lines, after: i) { result = doc }
            if result.isEmpty { result = leading(lines, before: i, style: style) }
            if result.isEmpty, let t = trailing(lines[i], style: style) { result = [t] }
            return Array(result.prefix(maxCommentLines))
        }

        static let directives = try! NSRegularExpression(
            pattern: #"^(?:#!|-\*-|type:|noqa|pylint|pragma|fmt:|eslint|@ts-|prettier|swiftlint|MARK:|TODO:\s*$|istanbul)"#)
        static let bannerOnly = try! NSRegularExpression(pattern: #"^[\s#/*=\-_~.]*$"#)

        static func keep(_ line: String) -> Bool {
            !line.isEmpty && !matches(directives, line) && !matches(bannerOnly, line)
        }

        /// The comment lines right above line `i` (no blank line between), decorators and attributes skipped.
        static func leading(_ lines: [String], before i: Int, style: Style) -> [String] {
            var j = i - 1
            while j >= 0, lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("@") { j -= 1 }
            guard j >= 0 else { return [] }
            let last = lines[j].trimmingCharacters(in: .whitespaces)
            var out: [String] = []
            if style == .python {
                while j >= 0, lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                    out.insert(clean(lines[j].trimmingCharacters(in: .whitespaces), prefix: "#"), at: 0)
                    j -= 1
                }
            } else if last.hasSuffix("*/") {
                var k = j
                while k >= 0, !lines[k].contains("/*") { k -= 1; if j - k > 60 { return [] } }
                guard k >= 0 else { return [] }
                for row in lines[k...j] {
                    out.append(clean(row.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "/**", with: "").replacingOccurrences(of: "/*", with: "")
                        .replacingOccurrences(of: "*/", with: ""), prefix: "*"))
                }
            } else {
                while j >= 0, lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    out.insert(clean(lines[j].trimmingCharacters(in: .whitespaces), prefix: "/"), at: 0)
                    j -= 1
                }
            }
            return out.filter(keep)
        }

        /// A comment after the code on the same line (`X = 3  # pixels`), outside any string.
        static func trailing(_ line: String, style: Style) -> String? {
            var quote: Character?
            let chars = Array(line)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if let q = quote {
                    if c == "\\" { i += 2; continue }
                    if c == q { quote = nil }
                } else if c == "\"" || c == "'" || (c == "`" && style != .python) {
                    quote = c
                } else if style == .python ? c == "#" : (c == "/" && i + 1 < chars.count && chars[i + 1] == "/" && (i == 0 || chars[i - 1] != ":")) {
                    let text = clean(String(chars[i...]).trimmingCharacters(in: .whitespaces), prefix: style == .python ? "#" : "/")
                    return keep(text) ? text : nil
                }
                i += 1
            }
            return nil
        }

        /// The text of a comment line without its markers: `///  Opens it.` → `Opens it.`
        static func clean(_ line: String, prefix: Character) -> String {
            var t = Substring(line)
            while let f = t.first, f == prefix || f == " " || f == "\t" || f == "!" { t = t.dropFirst() }
            return t.trimmingCharacters(in: .whitespaces)
        }

        /// The docstring of a `def` / `class` whose signature starts at line `i`.
        static func docstring(_ lines: [String], after i: Int) -> [String]? {
            var j = i
            // The signature may span lines: it ends at the line that ends with `:`.
            while j < lines.count, j - i < 15 {
                let code = trailing(lines[j], style: .python).map { _ in String(lines[j].prefix { $0 != "#" }) } ?? lines[j]
                if code.trimmingCharacters(in: .whitespaces).hasSuffix(":") { break }
                j += 1
            }
            var k = j + 1
            while k < lines.count, lines[k].trimmingCharacters(in: .whitespaces).isEmpty { k += 1 }
            guard k < lines.count else { return nil }
            return stringBlock(lines, at: k)
        }

        /// A triple-quoted string that starts at line `k`: its lines, trimmed.
        static func stringBlock(_ lines: [String], at k: Int) -> [String]? {
            var first = lines[k].trimmingCharacters(in: .whitespaces)
            while let f = first.first, "rRuUbB".contains(f) { first.removeFirst() }
            guard let quote = ["\"\"\"", "'''"].first(where: { first.hasPrefix($0) }) else { return nil }
            var body = String(first.dropFirst(3))
            var out: [String] = []
            var row = k
            while true {
                if let end = body.range(of: quote) {
                    out.append(String(body[..<end.lowerBound]).trimmingCharacters(in: .whitespaces))
                    break
                }
                out.append(body.trimmingCharacters(in: .whitespaces))
                row += 1
                if row >= lines.count || row - k > 40 { break }
                body = lines[row]
            }
            return out.filter { !$0.isEmpty }
        }

        /// A file's own description: its docstring (Python) or the comment block that opens it.
        static func moduleComment(_ lines: [String], style: Style) -> [String] {
            var k = 0
            while k < lines.count {
                let t = lines[k].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#!") || t.hasPrefix("# -*-") || t.hasPrefix("# coding") { k += 1 } else { break }
            }
            guard k < lines.count else { return [] }
            var out: [String] = []
            if style == .python, let doc = stringBlock(lines, at: k) {
                out = doc
            } else {
                let prefix: Character = style == .python ? "#" : "/"
                var j = k
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).hasPrefix(String(prefix)) {
                    out.append(clean(lines[j].trimmingCharacters(in: .whitespaces), prefix: prefix))
                    j += 1
                }
                if out.isEmpty, lines[k].trimmingCharacters(in: .whitespaces).hasPrefix("/*") {
                    var j = k
                    while j < lines.count, j - k < 30 {
                        out.append(clean(lines[j].trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "/**", with: "").replacingOccurrences(of: "/*", with: "")
                            .replacingOccurrences(of: "*/", with: ""), prefix: "*"))
                        if lines[j].contains("*/") { break }
                        j += 1
                    }
                }
            }
            return Array(out.filter(keep).prefix(maxCommentLines))
        }

        // MARK: Result

        static func definition(_ name: String, hit: Hit, repo: String) -> Definition {
            let comment = Array(hit.comment.prefix(maxCommentLines))
            return Definition(id: name, key: "\(repo)/\(hit.path):\(hit.line)", repo: repo, path: hit.path, line: hit.line,
                              rule: .symbol, title: comment.first ?? "", summary: comment.dropFirst().joined(separator: "\n"),
                              absolutePath: hit.absolute)
        }
    }

    /// Source file lists, kept for a short while: pointing at several symbols in a row should not
    /// walk the same folders each time. Nothing is persisted.
    final class FileListCache: @unchecked Sendable {
        static let shared = FileListCache()
        private let lock = NSLock()
        private var entries: [String: (Date, [String])] = [:]
        /// Seconds a list is trusted: the repo changes while the user works.
        static let lifetime: TimeInterval = 20

        func get(_ root: String) -> [String]? {
            lock.lock(); defer { lock.unlock() }
            guard let e = entries[root], Date().timeIntervalSince(e.0) < Self.lifetime else { return nil }
            return e.1
        }

        func set(_ root: String, _ files: [String]) {
            lock.lock(); defer { lock.unlock() }
            entries[root] = (Date(), files)
        }

        func clear() {
            lock.lock(); defer { lock.unlock() }
            entries = [:]
        }
    }
}
