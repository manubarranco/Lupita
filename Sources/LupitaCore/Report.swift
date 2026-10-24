import Foundation

/// Spike evaluation: corpus stats, a labelled sample (precision/recall), resolution
/// top-1 and simulated OCR correction. Output is an HTML page plus `sample.json`;
/// labels are read back from `labels.json` (`{"sid": true|false}`) when present.
public enum Report {
    public struct SampleItem: Codable, Sendable {
        public enum Kind: String, Codable, Sendable { case accepted, rejected, resolution }
        public let sid: String
        public let kind: Kind
        public let repo: String
        public let path: String
        public let line: Int
        public let text: String
        /// accepted: rule + title · rejected: the ID token · resolution: query → top-1.
        public let detail: String
        /// Labels are keyed by content, not by `sid`, so they survive re-sampling.
        /// A resolution whose answer changes gets a new key and must be relabelled.
        public var labelKey: String { "\(kind.rawValue)|\(repo)|\(path)|\(line)|\(detail)" }
    }

    public struct OCRResult: Sendable {
        public var perturbed = 0, corrected = 0, wrong = 0
        public var noise = 0, falseCorrections = 0
        public var failures: [String] = []
        public var falseExamples: [String] = []
    }

    // MARK: - Entry points

    public static func write(index: RefIndex, to dir: URL) throws -> String {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sample = buildSample(index: index)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(sample).write(to: dir.appendingPathComponent("sample.json"))
        let labelsURL = dir.appendingPathComponent("labels.json")
        let labels = (try? JSONDecoder().decode([String: Bool].self, from: Data(contentsOf: labelsURL))) ?? [:]
        let ocr = simulateOCR(index: index)
        let html = HTML.page(index: index, sample: sample, labels: labels, ocr: ocr,
                             rejectedTotal: rejectedCandidates(index: index).count)
        let out = dir.appendingPathComponent("index.html")
        try html.write(to: out, atomically: true, encoding: .utf8)
        return out.path
    }

    public static func describe(_ r: Resolution) -> String {
        var out: [String] = []
        switch r.kind {
        case .notAnID: return "“\(r.query)” is not a reference."
        case .undefined:
            return "\(r.query): not a known reference" + (r.mentions.map { " (mentioned \($0.count)× in \($0.files.count) files, never defined)" } ?? "")
        case .ambiguous: out.append("\(r.query): ambiguous OCR → \(r.alternatives.joined(separator: " / "))")
        case .corrected: out.append(r.isSuggestion ? "Did you mean \(r.key ?? "")? (read: \(r.query))" : "\(r.query) → corrected to \(r.key ?? "")")
        case .exact: break
        }
        if r.fromOtherRepo { out.append("(not defined in the preferred repo; showing other repos)") }
        for d in r.definitions {
            out.append("[\(d.repo)] \(d.id) — \(d.rule == .symbol && d.title.isEmpty ? S.noComment : d.title)")
            if !d.summary.isEmpty { out.append("    \(d.summary)") }
            out.append("    " + (d.path.isEmpty ? "" : "\(d.path):\(d.line) · ") + d.rule.rawValue)
        }
        if let m = r.mentions { out.append("cited \(m.count)× in \(m.files.count) files") }
        return out.joined(separator: "\n")
    }

    // MARK: - Sample

    static func buildSample(index: RefIndex) -> [SampleItem] {
        var rng = SplitMix64(seed: 42)
        var items: [SampleItem] = []

        let allDefs = index.definitions.values.flatMap { $0 }.sorted { ($0.repo, $0.path, $0.line) < ($1.repo, $1.path, $1.line) }
        for (n, d) in pick(allDefs, 25, &rng).enumerated() {
            items.append(SampleItem(sid: "A\(n + 1)", kind: .accepted, repo: d.repo, path: d.path, line: d.line,
                                    text: lineText(d.absolutePath, d.line) ?? d.path,
                                    detail: "\(d.rule.rawValue) · \(d.id) — \(d.title)"))
        }
        for (n, c) in pick(rejectedCandidates(index: index), 25, &rng).enumerated() {
            items.append(SampleItem(sid: "R\(n + 1)", kind: .rejected, repo: c.repo, path: c.path, line: c.line,
                                    text: c.text, detail: c.token))
        }
        let resolver = Resolver(index: index)
        let definedMentions = mentionOccurrences(index: index).filter { index.definitions[$0.key] != nil }
        for (n, m) in pick(definedMentions, 30, &rng).enumerated() {
            let r = resolver.resolve(m.token, preferredRepo: m.repo, context: m.context, fromPath: m.path)
            let flag = r.fromOtherRepo ? " ⚠ otro repo" : ""
            let detail = r.definitions.first.map { "\(m.token) → [\($0.repo)] \($0.path):\($0.line) — \($0.title)\(flag)" } ?? "\(m.token) → (none)"
            items.append(SampleItem(sid: "M\(n + 1)", kind: .resolution, repo: m.repo, path: m.path, line: m.line,
                                    text: m.text, detail: detail))
        }
        return items
    }

    struct Candidate { let repo, path: String; let line: Int; let text, token: String }

    /// Lines that start with an ID in a definition-like position but were not accepted.
    static func rejectedCandidates(index: RefIndex) -> [Candidate] {
        var out: [Candidate] = []
        forEachLine(index: index) { repo, path, n, line in
            let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t#-*+>|_"))
            guard line.first.map({ "#-*+|".contains($0) }) == true || line.hasPrefix("**"),
                  let first = IDGrammar.tokens(in: stripped).first, first.range.location == 0,
                  DefinitionRules.lineDefinition(line) == nil
            else { return }
            out.append(Candidate(repo: repo, path: path, line: n, text: line, token: first.id.display))
        }
        return out
    }

    struct Occurrence { let repo, path: String; let line: Int; let text, token, key: String; let context: String }

    static func mentionOccurrences(index: RefIndex) -> [Occurrence] {
        var out: [Occurrence] = []
        forEachLine(index: index) { repo, path, n, line in
            guard DefinitionRules.lineDefinition(line) == nil else { return }
            for t in IDGrammar.tokens(in: line) {
                // Only the 80 characters before the ID count as context for a repo name.
                let start = max(0, t.range.location - 80)
                let context = (line as NSString).substring(with: NSRange(location: start, length: t.range.location + t.range.length - start))
                out.append(Occurrence(repo: repo, path: path, line: n, text: line, token: t.id.display, key: t.id.key, context: context))
            }
        }
        return out
    }

    private static func forEachLine(index: RefIndex, _ body: (String, String, Int, String) -> Void) {
        for repo in index.repos {
            for file in RepoDiscovery.markdownFiles(in: repo) {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let path = RepoDiscovery.paths(of: file, in: repo).relative
                var inFence = false
                for (i, line) in text.components(separatedBy: .newlines).enumerated() {
                    if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { inFence.toggle(); continue }
                    if !inFence { body(repo.name, path, i + 1, line) }
                }
            }
        }
    }

    // MARK: - OCR simulation

    /// Glyph swaps a real OCR pass makes on IDs (the inverse of `Resolver.confusions`).
    static let ocrErrors: [Character: [Character]] = [
        "0": ["O", "o"], "1": ["I", "l", "|"], "5": ["S"], "8": ["B"], "2": ["Z"], "6": ["G"],
        "O": ["0"], "I": ["1"], "S": ["5"], "B": ["8"], "D": ["0"], "Q": ["O"], "L": ["1"],
    ]

    static func simulateOCR(index: RefIndex) -> OCRResult {
        var rng = SplitMix64(seed: 7)
        var result = OCRResult()
        let resolver = Resolver(index: index)
        let keys = index.definitions.keys.sorted()
        for key in pick(keys, 200, &rng) {
            let display = index.definitions[key]![0].id
            var chars = Array(display)
            let positions = chars.indices.filter { ocrErrors[chars[$0]] != nil }
            guard !positions.isEmpty else { continue }
            let p = positions[Int(rng.next() % UInt64(positions.count))]
            let options = ocrErrors[chars[p]]!
            chars[p] = options[Int(rng.next() % UInt64(options.count))]
            let garbled = String(chars)
            result.perturbed += 1
            let r = resolver.resolve(garbled)
            if (r.kind == .corrected || r.kind == .exact) && r.key == key {
                result.corrected += 1
            } else {
                result.wrong += 1
                if result.failures.count < 15 { result.failures.append("\(display) → \(garbled) → \(r.kind.rawValue) \(r.key ?? r.alternatives.joined(separator: "/"))") }
            }
        }

        // Tokens that are not defined references must not get "corrected" into one.
        var noise = Set(["GPL3", "BSD3", "UTF8", "H1", "H2", "P0", "ES6", "MP4", "V2", "Q4", "A1", "HTTP2", "IPV6",
                         "BIO", "SOS", "IOS", "OK", "TODO", "API", "LOL", "ID", "QA", "DS", "UX", "SOLO", "DO", "LO", "SI"])
        for (key, _) in index.mentions where index.definitions[key] == nil { noise.insert(key) }
        for token in noise.sorted() where index.definitions[IDGrammar.parse(token)?.key ?? ""] == nil {
            result.noise += 1
            let r = resolver.resolve(token)
            if r.kind == .corrected || r.kind == .ambiguous {
                result.falseCorrections += 1
                if result.falseExamples.count < 15 { result.falseExamples.append("\(token) → \(r.key ?? r.alternatives.joined(separator: "/"))") }
            }
        }
        return result
    }

    // MARK: - Helpers

    static func lineText(_ path: String, _ line: Int) -> String? {
        guard line > 0, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        return line <= lines.count ? lines[line - 1] : nil
    }

    /// Fixed sample (seed 42) of term hits found by the generic pattern outside glossary files:
    /// what D22 labels to decide whether the pattern is switched on.
    public static func looseTermSample(roots: [String], count: Int = 40) -> [Definition] {
        let previous = Glossary.looseTerms
        Glossary.looseTerms = true
        defer { Glossary.looseTerms = previous }
        let index = RefIndex.build(roots: roots)
        let hits = index.terms.values.flatMap { $0 }
            .filter { !Glossary.isGlossaryFile(($0.path as NSString).lastPathComponent) }
            .sorted { ($0.repo, $0.path, $0.line, $0.id) < ($1.repo, $1.path, $1.line, $1.id) }
        var rng = SplitMix64(seed: 42)
        return pick(hits, count, &rng)
    }

    static func pick<T>(_ items: [T], _ n: Int, _ rng: inout SplitMix64) -> [T] {
        var pool = items
        var out: [T] = []
        while out.count < n, !pool.isEmpty {
            out.append(pool.remove(at: Int(rng.next() % UInt64(pool.count))))
        }
        return out
    }
}

/// Deterministic RNG so the sample (and its labels) stay stable between runs.
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
