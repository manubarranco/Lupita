import Foundation

extension CodeRefs {
    /// CSS tokens and hex colours (D29, type 3): `--accent`, `var(--accent)`, `#0E5400`. The value (both when
    /// the token has a light and a dark one), a colour sample and where it is defined.
    enum Tokens {
        enum Mode { case base, light, dark }

        struct Decl {
            let name: String
            let value: String
            let mode: Mode
            let file: String
            let line: Int
        }

        static let extensions: Set<String> = ["css", "scss", "astro", "tsx", "jsx", "html"]
        static let tokenName = try! NSRegularExpression(pattern: #"^(?:var\(\s*)?(--[A-Za-z][\w-]*)\s*(?:,.*)?\)?$"#)
        static let hexShape = try! NSRegularExpression(pattern: #"^#([0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#)
        static let varCall = try! NSRegularExpression(pattern: #"var\(\s*(--[A-Za-z][\w-]*)\s*(?:,\s*([^()]*(?:\([^()]*\)[^()]*)*))?\)"#)

        // MARK: Entry

        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            if let g = groups(tokenName, text.text) { return token(g[1], repos: repos) }
            // `#333` and `#1234` could be PR numbers: the PR type answers them (and falls back to the colour).
            if let g = groups(hexShape, text.text), !(g[1].count <= 4 && g[1].allSatisfy(\.isNumber)) { return color(g[1], repos: repos) }
            return nil
        }

        /// A colour on its own, also used for `#333` when no PR of that number exists.
        static func color(_ hex: String, repos: [Repo]) -> [Definition]? {
            guard let normal = normalizedHex(hex) else { return nil }
            var found: (Repo, [Decl])?
            for repo in repos {
                let table = self.table(for: repo)
                let same = table.values.flatMap { $0 }.filter { d in
                    d.mode != .dark && color(of: resolved(d, mode: .base, table: table)) == normal
                        || d.mode == .dark && color(of: resolved(d, mode: .dark, table: table)) == normal
                }.sorted { a, b in
                    // Where the colour is written down comes before where another token points to it.
                    (a.value.contains("var(") ? 1 : 0, a.file, a.line) < (b.value.contains("var(") ? 1 : 0, b.file, b.line)
                }
                if !same.isEmpty { found = (repo, same); break }
            }
            let display = "#" + String(normal.dropFirst().prefix(6))
            let rgb = components(of: normal).map { "rgb(\(Int($0.r)), \(Int($0.g)), \(Int($0.b)))" } ?? ""
            let sample = [ColorSample(label: "", hex: normal)]
            guard let (repo, decls) = found, let first = decls.first else {
                return [Definition(id: display, key: normal, repo: "", path: "", line: 0, rule: .color, title: rgb,
                                   summary: S.noTokenUsesIt, absolutePath: "", colors: sample)]
            }
            let names = Array(NSOrderedSet(array: decls.map(\.name)).array as! [String]).prefix(4).joined(separator: ", ")
            return [Definition(id: display, key: normal, repo: repo.name, path: relative(first.file, in: repo), line: first.line,
                               rule: .color, title: rgb, summary: S.definedAs(names), absolutePath: first.file, colors: sample)]
        }

        static func token(_ name: String, repos: [Repo]) -> [Definition]? {
            for repo in repos {
                let table = self.table(for: repo)
                guard let decls = table[name], !decls.isEmpty else { continue }
                // Prefer the file that gives both themes, then the shallowest path.
                let byFile = Dictionary(grouping: decls, by: \.file)
                let file = byFile.keys.sorted { a, b in
                    let (da, db) = (byFile[a]!.contains { $0.mode == .dark }, byFile[b]!.contains { $0.mode == .dark })
                    if da != db { return da }
                    return (a.split(separator: "/").count, a) < (b.split(separator: "/").count, b)
                }.first!
                let inFile = byFile[file]!.sorted { $0.line < $1.line }
                let base = inFile.first { $0.mode != .dark }
                let dark = inFile.first { $0.mode == .dark } ?? decls.first { $0.mode == .dark }
                guard let shown = base ?? dark else { continue }

                var values: [(label: String, value: String)] = []
                var samples: [ColorSample] = []
                if let base {
                    let v = resolved(base, mode: base.mode == .light ? .light : .base, table: table)
                    values.append((dark == nil ? "" : S.light, v))
                    if let hex = color(of: v) { samples.append(ColorSample(label: dark == nil ? "" : S.light, hex: hex)) }
                }
                if let dark {
                    let v = resolved(dark, mode: .dark, table: table)
                    values.append((S.dark, v))
                    if let hex = color(of: v) { samples.append(ColorSample(label: S.dark, hex: hex)) }
                } else if let base, base.value.contains("var(") {
                    // `--accent: var(--brand)` has no dark value of its own but `--brand` does.
                    let v = resolved(base, mode: .dark, table: table)
                    if v != values.first?.value {
                        values.append((S.dark, v))
                        if let hex = color(of: v) { samples.append(ColorSample(label: S.dark, hex: hex)) }
                    }
                }
                let title = values.map { $0.label.isEmpty ? $0.value : "\($0.label) \($0.value)" }.joined(separator: " · ")
                // `--accent: var(--brand)` says what it was written as when that differs from the value shown.
                let chain = shown.value != values.first?.value ? S.writtenAs(shown.value) : ""
                return [Definition(id: name, key: "\(repo.name)/\(name)", repo: repo.name, path: relative(shown.file, in: repo),
                                   line: shown.line, rule: .token, title: title, summary: chain, absolutePath: shown.file,
                                   colors: samples.isEmpty ? nil : samples)]
            }
            return nil
        }

        static func relative(_ file: String, in repo: Repo) -> String {
            let root = RepoDiscovery.realPath(repo.path)
            return file.hasPrefix(root + "/") ? String(file.dropFirst(root.count + 1)) : (file.hasPrefix(repo.path + "/") ? String(file.dropFirst(repo.path.count + 1)) : file)
        }

        // MARK: Values

        /// The value with every `var()` replaced by what it points to; the dark mode falls back to the base value.
        static func resolved(_ decl: Decl, mode: Mode, table: [String: [Decl]], depth: Int = 0) -> String {
            substitute(decl.value, mode: mode, table: table, depth: depth, seen: [decl.name])
        }

        static func substitute(_ value: String, mode: Mode, table: [String: [Decl]], depth: Int, seen: Set<String>) -> String {
            guard depth < 8, value.contains("var(") else { return value }
            let ns = value as NSString
            var out = value
            for m in varCall.matches(in: value, range: NSRange(location: 0, length: ns.length)).reversed() {
                let name = ns.substring(with: m.range(at: 1))
                let fallback = m.range(at: 2).location == NSNotFound ? nil : ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                var replacement: String?
                if !seen.contains(name), let decls = table[name] {
                    let pick = (mode == .dark ? decls.first { $0.mode == .dark } : nil) ?? decls.first { $0.mode != .dark } ?? decls.first
                    if let pick {
                        replacement = substitute(pick.value, mode: mode, table: table, depth: depth + 1, seen: seen.union([name]))
                    }
                }
                guard let replacement = replacement ?? fallback else { continue }
                out = (out as NSString).replacingCharacters(in: m.range, with: replacement)
            }
            return out
        }

        // MARK: Colours

        /// `#RRGGBB` (or `#RRGGBBAA`) from a CSS colour, or nil when the value is not a plain colour.
        static func color(of value: String) -> String? {
            let v = value.trimmingCharacters(in: .whitespaces).lowercased()
            if v.hasPrefix("#") { return normalizedHex(String(v.dropFirst())) }
            if let rgb = functionArguments(v, name: "rgb") ?? functionArguments(v, name: "rgba") {
                let n = rgb.compactMap(number)
                guard n.count >= 3 else { return nil }
                let alpha = rgb.count > 3 ? (rgb[3].hasSuffix("%") ? n[3] / 100 : n[3]) : 1
                return hex(n[0], n[1], n[2], alpha: alpha)
            }
            if let hsl = functionArguments(v, name: "hsl") ?? functionArguments(v, name: "hsla") {
                guard hsl.count >= 3, let h = number(hsl[0].replacingOccurrences(of: "deg", with: "")), let s = number(hsl[1]), let l = number(hsl[2]) else { return nil }
                let a = hsl.count > 3 ? (number(hsl[3]).map { hsl[3].hasSuffix("%") ? $0 / 100 : $0 } ?? 1) : 1
                let (r, g, b) = hslToRGB(h: h, s: s / 100, l: l / 100)
                return hex(r, g, b, alpha: a)
            }
            // shadcn-style tokens hold bare HSL components, used as `hsl(var(--accent))`: `140 80% 90%`.
            if matches(bareHSL, v) {
                let n = v.split(separator: " ").compactMap { number(String($0)) }
                let (r, g, b) = hslToRGB(h: n[0], s: n[1] / 100, l: n[2] / 100)
                return hex(r, g, b, alpha: 1)
            }
            return named[v]
        }

        static let bareHSL = try! NSRegularExpression(pattern: #"^\d+(?:\.\d+)? \d+(?:\.\d+)?% \d+(?:\.\d+)?%$"#)

        static let named: [String: String] = ["white": "#FFFFFF", "black": "#000000", "red": "#FF0000", "blue": "#0000FF", "green": "#008000"]

        static func functionArguments(_ v: String, name: String) -> [String]? {
            guard v.hasPrefix(name + "("), v.hasSuffix(")") else { return nil }
            let inner = v.dropFirst(name.count + 1).dropLast()
            return inner.split(whereSeparator: { ",/ ".contains($0) }).map(String.init)
        }

        /// `50%` → 50 for hsl; for rgb a percentage means a share of 255 (handled by the caller as a plain number).
        static func number(_ s: String) -> Double? { Double(s.replacingOccurrences(of: "%", with: "")) }

        static func hex(_ r: Double, _ g: Double, _ b: Double, alpha: Double) -> String {
            func c(_ x: Double) -> Int { max(0, min(255, Int(x.rounded()))) }
            let base = String(format: "#%02X%02X%02X", c(r), c(g), c(b))
            return alpha >= 0.999 ? base : base + String(format: "%02X", c(alpha * 255))
        }

        static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
            let c = (1 - abs(2 * l - 1)) * s
            let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
            let x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
            let (r1, g1, b1): (Double, Double, Double) = switch Int(hh) {
            case 0: (c, x, 0)
            case 1: (x, c, 0)
            case 2: (0, c, x)
            case 3: (0, x, c)
            case 4: (x, 0, c)
            default: (c, 0, x)
            }
            let m = l - c / 2
            return ((r1 + m) * 255, (g1 + m) * 255, (b1 + m) * 255)
        }

        /// `#abc` → `#AABBCC`; 4 and 8 digits keep their alpha.
        static func normalizedHex(_ digits: String) -> String? {
            let d = digits.hasPrefix("#") ? String(digits.dropFirst()) : digits
            guard [3, 4, 6, 8].contains(d.count), d.allSatisfy(\.isHexDigit) else { return nil }
            let full = d.count <= 4 ? d.map { "\($0)\($0)" }.joined() : d
            return "#" + full.uppercased()
        }

        static func components(of hex: String) -> (r: Double, g: Double, b: Double)? {
            let d = hex.dropFirst()
            guard d.count >= 6, let v = UInt32(d.prefix(6), radix: 16) else { return nil }
            return (Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255))
        }

        // MARK: Parsing

        /// Every `--name: value` of a repo's style files, by name. Kept for a few seconds like the file lists.
        static func table(for repo: Repo) -> [String: [Decl]] {
            if let cached = TableCache.shared.get(repo.path) { return cached }
            var out: [String: [Decl]] = [:]
            let needle = Data("--".utf8)
            for file in Symbols.sourceFiles(in: repo.path, extensions: extensions) {
                var info = stat()
                guard stat(file, &info) == 0, info.st_size <= Symbols.maxFileSize,
                      let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
                      !Symbols.occurrences(of: needle, in: data).isEmpty else { continue }
                for d in declarations(in: data, file: file) { out[d.name, default: []].append(d) }
            }
            TableCache.shared.set(repo.path, out)
            return out
        }

        static func declarations(in data: Data, file: String) -> [Decl] {
            let bytes = [UInt8](data)
            let isCSS = file.hasSuffix(".css") || file.hasSuffix(".scss")
            var out: [Decl] = []
            var stack: [String] = []
            var buffer: [UInt8] = []
            var bufferLine = 1, line = 1, parens = 0
            var i = 0

            func flush() {
                defer { buffer = []; bufferLine = line }
                guard !buffer.isEmpty else { return }
                let text = String(decoding: buffer, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.hasPrefix("--"), let colon = text.firstIndex(of: ":") else { return }
                let name = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
                guard name.dropFirst(2).allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }), name.count > 2 else { return }
                var value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                value = value.replacingOccurrences(of: #"\s*!important$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                guard !value.isEmpty else { return }
                out.append(Decl(name: name, value: value, mode: mode(of: stack), file: file, line: bufferLine))
            }

            while i < bytes.count {
                let c = bytes[i]
                if c == 10 { line += 1 }
                // Comments: /* */ everywhere, // outside CSS (and not inside a URL).
                if c == 47, i + 1 < bytes.count, bytes[i + 1] == 42 {
                    i += 2
                    while i + 1 < bytes.count, !(bytes[i] == 42 && bytes[i + 1] == 47) { if bytes[i] == 10 { line += 1 }; i += 1 }
                    i += 2; continue
                }
                if !isCSS, c == 47, i + 1 < bytes.count, bytes[i + 1] == 47, i == 0 || bytes[i - 1] != 58 {
                    while i < bytes.count, bytes[i] != 10 { i += 1 }
                    continue
                }
                if c == 34 || c == 39 {  // a string, kept whole
                    buffer.append(c); i += 1
                    while i < bytes.count, bytes[i] != c, bytes[i] != 10 { buffer.append(bytes[i]); i += 1 }
                    if i < bytes.count { buffer.append(bytes[i]); i += 1 }
                    continue
                }
                switch c {
                case 40: parens += 1; buffer.append(c)
                case 41: parens = max(0, parens - 1); buffer.append(c)
                case 123 where parens == 0:
                    stack.append(String(decoding: buffer, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                    buffer = []; bufferLine = line
                case 125 where parens == 0:
                    flush()
                    if !stack.isEmpty { stack.removeLast() }
                case 59 where parens == 0: flush()
                default:
                    if buffer.isEmpty, c == 32 || c == 10 || c == 9 || c == 13 { bufferLine = line } else { buffer.append(c) }
                }
                i += 1
            }
            return out
        }

        static let darkHints = try! NSRegularExpression(
            pattern: #"prefers-color-scheme:\s*dark|\[data-(?:theme|mode|color-scheme)\s*[~|^$*]?=\s*["']?dark|\.dark\b|\.theme-dark|\.is-dark"#)
        static let lightHints = try! NSRegularExpression(
            pattern: #"prefers-color-scheme:\s*light|\[data-(?:theme|mode|color-scheme)\s*[~|^$*]?=\s*["']?light|\.light\b|\.theme-light"#)

        static func mode(of stack: [String]) -> Mode {
            let context = stack.joined(separator: " ")
            if matches(darkHints, context) { return .dark }
            if matches(lightHints, context) { return .light }
            return .base
        }
    }

    final class TableCache: @unchecked Sendable {
        static let shared = TableCache()
        private let lock = NSLock()
        private var entries: [String: (Date, [String: [Tokens.Decl]])] = [:]

        func get(_ key: String) -> [String: [Tokens.Decl]]? {
            lock.lock(); defer { lock.unlock() }
            guard let e = entries[key], Date().timeIntervalSince(e.0) < FileListCache.lifetime else { return nil }
            return e.1
        }

        func set(_ key: String, _ table: [String: [Tokens.Decl]]) {
            lock.lock(); defer { lock.unlock() }
            entries[key] = (Date(), table)
        }

        func clear() {
            lock.lock(); defer { lock.unlock() }
            entries = [:]
        }
    }
}
