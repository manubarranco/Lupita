import Foundation

/// Renders the spike report. Spanish copy: it is read by the project owner, not shipped.
enum HTML {
    static func page(index: RefIndex, sample: [Report.SampleItem], labels: [String: Bool],
                     ocr: Report.OCRResult, rejectedTotal: Int) -> String {
        let defs = index.definitions.values.flatMap { $0 }
        let crossRepo = index.definitions.filter { Set($0.value.map(\.repo)).count > 1 }
        let intraRepo = index.definitions.filter { entry in
            Dictionary(grouping: entry.value, by: \.repo).values.contains { $0.count > 1 }
        }
        let orphans = index.mentions.filter { index.definitions[$0.key] == nil && $0.value.count >= 3 }
            .sorted { $0.value.count > $1.value.count }.prefix(25)

        // Metrics from labels
        func rate(_ kind: Report.SampleItem.Kind) -> (ok: Int, n: Int) {
            let items = sample.filter { $0.kind == kind && labels[$0.labelKey] != nil }
            return (items.filter { labels[$0.labelKey] == true }.count, items.count)
        }
        let acc = rate(.accepted), rej = rate(.rejected), res = rate(.resolution)
        var metrics: [(String, String, String, Bool?)] = []  // label, value, threshold, pass
        if acc.n > 0 {
            let p = Double(acc.ok) / Double(acc.n)
            metrics.append(("Precisión de definiciones", pct(p) + " (\(acc.ok)/\(acc.n))", "≥ 95 %", p >= 0.95))
            if rej.n > 0 {
                let missRate = Double(rej.n - rej.ok) / Double(rej.n)
                let tp = p * Double(defs.count), fn = missRate * Double(rejectedTotal)
                let recall = tp / max(tp + fn, 1)
                metrics.append(("Recall de definiciones (estimado)", pct(recall) + " (\(rej.n - rej.ok) perdidas en \(rej.n) rechazadas)", "≥ 90 %", recall >= 0.90))
            }
        }
        if res.n > 0 {
            let r = Double(res.ok) / Double(res.n)
            metrics.append(("Top-1 correcto con pista de repo", pct(r) + " (\(res.ok)/\(res.n))", "≥ 90 %", r >= 0.90))
            let flagged = sample.filter { $0.kind == .resolution && labels[$0.labelKey] == false && $0.detail.hasSuffix("⚠ otro repo") }.count
            let honest = Double(res.ok + flagged) / Double(res.n)
            metrics.append(("No engaña (acierta o avisa de que es de otro repo)", pct(honest) + " (\(res.ok + flagged)/\(res.n))", "—", nil))
        }
        let ocrRate = Double(ocr.corrected) / Double(max(ocr.perturbed, 1))
        let falseRate = Double(ocr.falseCorrections) / Double(max(ocr.noise, 1))
        metrics.append(("OCR: IDs corregidos", pct(ocrRate) + " (\(ocr.corrected)/\(ocr.perturbed))", "≥ 90 %", ocrRate >= 0.90))
        metrics.append(("OCR: correcciones falsas", pct(falseRate) + " (\(ocr.falseCorrections)/\(ocr.noise))", "≤ 5 %", falseRate <= 0.05))

        var h = head()
        h += "<h1>Lupita — informe del spike de heurísticas</h1>"
        h += "<p class=lede>\(index.repos.count) repos · \(index.fileCount) archivos .md · <b>\(index.definitions.count)</b> IDs definidos · \(crossRepo.count) definidos en varios repos</p>"

        h += "<h2>¿Pasa el listón?</h2><table><tr><th>Medida</th><th>Resultado</th><th>Umbral</th><th></th></tr>"
        for (label, value, threshold, pass) in metrics {
            h += "<tr><td>\(e(label))</td><td>\(e(value))</td><td>\(threshold)</td><td>\(pass.map { $0 ? "<span class=ok>✓</span>" : "<span class=ko>✗</span>" } ?? "")</td></tr>"
        }
        h += "</table>"
        if acc.n == 0 { h += "<p class=note>Sin etiquetas todavía: falta <code>labels.json</code>.</p>" }

        h += "<h2>Por repo</h2><table><tr><th>Repo</th><th>IDs definidos</th><th>Prefijos descubiertos</th><th>Reglas</th></tr>"
        for repo in index.repos {
            let mine = defs.filter { $0.repo == repo.name }
            let keys = Set(mine.map(\.key))
            let prefixes = Dictionary(grouping: keys, by: { IDGrammar.parse($0)?.prefix ?? "?" })
                .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
            let rules = Dictionary(grouping: mine, by: \.rule).map { "\($0.key.rawValue) \($0.value.count)" }.sorted()
            h += "<tr><td><b>\(e(repo.name))</b></td><td>\(keys.count)</td><td>\(prefixes.map { "<span class=chip>\(e($0.0))<i>\($0.1)</i></span>" }.joined())</td><td class=small>\(rules.joined(separator: " · "))</td></tr>"
        }
        h += "</table>"

        h += "<h2>Colisiones entre repos <small>(\(crossRepo.count))</small></h2><p class=note>El mismo ID significa cosas distintas según el repo: por eso importa saber en qué ventana estás.</p><table><tr><th>ID</th><th>Definiciones</th></tr>"
        for (key, ds) in crossRepo.sorted(by: { $0.value.count > $1.value.count }).prefix(20) {
            h += "<tr><td><b>\(e(key))</b></td><td>\(ds.map { "<div><span class=repo>\(e($0.repo))</span> \(e($0.title))</div>" }.joined())</td></tr>"
        }
        h += "</table>"

        h += "<h2>Duplicados dentro de un mismo repo <small>(\(intraRepo.count))</small></h2><table><tr><th>ID</th><th>Dónde (la primera es la que gana)</th></tr>"
        for (key, ds) in intraRepo.sorted(by: { $0.key < $1.key }).prefix(25) {
            let grouped = Dictionary(grouping: ds, by: \.repo).filter { $0.value.count > 1 }
            let rows = grouped.values.flatMap { $0 }.map { "<div><span class=repo>\(e($0.repo))</span> <code>\(e($0.path)):\($0.line)</code> \($0.rule.rawValue) — \(e($0.title))</div>" }
            h += "<tr><td><b>\(e(key))</b></td><td>\(rows.joined())</td></tr>"
        }
        h += "</table>"

        h += "<h2>Huérfanos <small>(citados ≥ 3 veces, nunca definidos)</small></h2><p>\(orphans.map { "<span class=chip>\(e($0.key))<i>\($0.value.count)</i></span>" }.joined())</p>"

        h += "<h2>Muestra etiquetada</h2><p class=note>✓ = el sistema acierta. Las 10 marcadas con ◆ son las que conviene que mires tú: si no estás de acuerdo con la etiqueta, dímelo.</p>"
        for (kind, title) in [(Report.SampleItem.Kind.accepted, "Aceptadas como definición"), (.rejected, "Rechazadas (¿debería haber sido definición?)"), (.resolution, "Menciones resueltas (¿apunta a la definición correcta?)")] {
            h += "<h3>\(title)</h3><table><tr><th></th><th>Dónde</th><th>Línea</th><th>Resultado</th></tr>"
            for item in sample where item.kind == kind {
                let mark = labels[item.labelKey].map { $0 ? "<span class=ok>✓</span>" : "<span class=ko>✗</span>" } ?? "·"
                let review = reviewSIDs.contains(item.sid) ? " ◆" : ""
                h += "<tr><td>\(mark) <small>\(item.sid)\(review)</small></td><td class=small><span class=repo>\(e(item.repo))</span><br><code>\(e(item.path)):\(item.line)</code></td><td><code class=line>\(e(String(item.text.prefix(220))))</code></td><td class=small>\(e(item.detail))</td></tr>"
            }
            h += "</table>"
        }

        h += "<h2>OCR simulado</h2><p>Se cambia un carácter de \(ocr.perturbed) IDs reales como lo haría el OCR (0→O, 1→l, 5→S…) y se mira si vuelve al ID correcto. Después se pasan \(ocr.noise) palabras que <b>no</b> son referencias definidas para ver si alguna se “corrige” por error.</p>"
        if !ocr.failures.isEmpty { h += "<h3>No recuperados</h3><ul>\(ocr.failures.map { "<li><code>\(e($0))</code></li>" }.joined())</ul>" }
        if !ocr.falseExamples.isEmpty { h += "<h3>Correcciones falsas</h3><ul>\(ocr.falseExamples.map { "<li><code>\(e($0))</code></li>" }.joined())</ul>" }
        h += "</main></body></html>"
        return h
    }

    static let reviewSIDs: Set<String> = ["A1", "A5", "A9", "A13", "R1", "R5", "R9", "M1", "M5", "M9"]

    static func pct(_ x: Double) -> String { String(format: "%.0f %%", x * 100) }

    static func e(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func head() -> String {
        """
        <!doctype html><html lang=es><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
        <title>Lupita — informe</title><style>
        :root{--bg:#fbfaf7;--fg:#1d1c1a;--muted:#6b6862;--line:#e6e2da;--chip:#efebe3;--ok:#2f7d4f;--ko:#b3412e;--accent:#3a5bd9}
        @media (prefers-color-scheme:dark){:root{--bg:#161615;--fg:#ecebe7;--muted:#9a978f;--line:#2c2b28;--chip:#262522;--ok:#6cc08b;--ko:#e8806c;--accent:#8ea4ff}}
        body{background:var(--bg);color:var(--fg);font:15px/1.5 -apple-system,system-ui,sans-serif;margin:0}
        main{max-width:1100px;margin:0 auto;padding:32px 16px 80px}
        h1{font-size:26px;margin:0 0 4px}h2{font-size:19px;margin:40px 0 8px}h3{font-size:15px;margin:24px 0 6px;color:var(--muted)}
        small{color:var(--muted);font-weight:400}.lede{color:var(--muted);margin:0 0 8px}.note{color:var(--muted);font-size:14px}
        table{border-collapse:collapse;width:100%;font-size:14px}th,td{text-align:left;vertical-align:top;padding:6px 10px;border-bottom:1px solid var(--line)}
        th{font-weight:600;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
        .chip{display:inline-block;background:var(--chip);border-radius:6px;padding:1px 7px;margin:2px 4px 2px 0;font-weight:600;font-size:13px}
        .chip i{font-style:normal;font-weight:400;color:var(--muted);margin-left:4px}
        .repo{color:var(--accent);font-weight:600}.small{font-size:13px}code{font:12.5px ui-monospace,Menlo,monospace}
        .line{white-space:pre-wrap;word-break:break-word}.ok{color:var(--ok);font-weight:700}.ko{color:var(--ko);font-weight:700}
        </style></head><body><main>
        """
    }
}
