import AppKit
import SwiftUI
import LupitaCore

// Sample states shared by the themes gallery and the «Aspecto» window.

/// The ten states of `docs/design-system/states.json`, built by hand as the `Resolution`s the real views receive.
struct GalleryState {
    let id: String
    let label: String
    let resolution: Resolution?
    let notice: String?
    var hover: Int? = nil

    @MainActor func view(_ theme: TooltipTheme) -> AnyView {
        if let notice { return AnyView(NoticeView(text: notice, theme: theme)) }
        return AnyView(TooltipView(resolution: resolution!, theme: theme, open: { _ in }, previewHover: hover))
    }
}

enum GalleryStates {
    private static func def(_ id: String, _ rule: DefinitionRule = .heading, title: String, summary: String = "", repo: String = "",
                            path: String = "", line: Int = 0, colors: [ColorSample]? = nil, file: Bool = true) -> Definition {
        .made(id: id, repo: repo, path: path, line: line, rule: rule, title: title, summary: summary,
              absolutePath: file ? "/Users/demo/\(repo)/\(path)" : "", colors: colors)
    }

    static let all: [GalleryState] = {
        let d42 = def("D42", title: "Vocabulario de git en lenguaje llano",
                      summary: "Cuarenta términos validados por Manu, con una línea llana y un ejemplo, en español e inglés.",
                      repo: "lupita", path: "docs/decisions.md", line: 212)
        let d43 = def("D43", title: "Los interruptores solo apagan diccionarios fijos", summary: "Lo que sale de los repos queda siempre encendido.",
                      repo: "lupita", path: "docs/decisions.md", line: 221)
        let d23 = def("D23", title: "Un solo punto de verdad para los tokens", summary: "Los componentes leen roles, nunca valores.",
                      repo: "ds-agentico", path: "docs/decisions.md", line: 140)
        let os = def("OS", .term, title: "Sistema operativo", summary: "El software que gestiona el equipo y los programas.", file: false)
        let d5 = def("D5", title: "Orden de las fases", summary: "Primero el sistema, después los temas.", repo: "lios", path: "memory/decisions.md", line: 88)
        let range = RangeList.made(entries: [
            ("D40", def("D40", title: "Informe de IDs que envían los usuarios", repo: "lupita", path: "docs/decisions.md", line: 190)),
            ("D41", def("D41", title: "Los rangos listan el tramo", repo: "lupita", path: "docs/decisions.md", line: 200)),
            ("D42", d42), ("D43", nil)], noun: "decisiones", sharedRepo: "lupita", sharedPath: "docs/decisions.md")
        let accent = def("--accent", .token, title: "Color de acento de la interfaz", summary: "Se usa en enlaces, foco y el repo del tooltip.",
                         repo: "vector-ui-studio", path: "src/tokens.css", line: 12,
                         colors: [ColorSample(label: "claro", hex: "#2F6FED"), ColorSample(label: "oscuro", hex: "#8AB4FF")])
        let stress = def("ARCHITECTURE-DECISION-RECORD-0042-SUPERSEDED-BY-0057", .symbol,
                         title: "Migrar el motor de resolución de referencias a un índice incremental que se actualiza en segundo plano cuando cambia un archivo, conservando la compatibilidad con los glosarios del repo y sin bloquear el atajo ni el subrayado mientras dura la reindexación completa",
                         summary: "La reindexación completa recorre todos los repos activos y, mientras no termina, se sirven las respuestas del índice anterior para que el atajo nunca espere; al acabar se cambia de índice de una sola vez y se descarta el viejo.",
                         repo: "lupita-con-un-nombre-de-repo-muy-largo-de-verdad",
                         path: "docs/decisions/architecture/2026/10/0042-incremental-index-with-background-reindex.md", line: 1204)
        var cited: [String: Int] = [:]
        for (i, n) in [3, 3, 2, 2, 2].enumerated() { cited["lupita/docs/f\(i).md"] = n }
        var many: [String: Int] = [:]
        for i in 0..<86 { many["lupita/docs/g\(i).md"] = 14 }
        many["lupita/docs/big.md"] = 44
        return [
            GalleryState(id: "definition", label: "ID definido", resolution: .made(query: "D42", key: "D42", definitions: [d42, d43], mentions: .made(byFile: cited)), notice: nil, hover: 1),
            GalleryState(id: "term", label: "Término", resolution: .made(query: "rebase", key: "rebase", definitions: [
                def("rebase", .term, title: "rebase", summary: "Reescribe tus commits encima de otra rama para que la historia quede en línea recta. Cambia los commits: no lo hagas sobre ramas ya compartidas.", file: false)]), notice: nil),
            GalleryState(id: "symbol", label: "Símbolo sin comentario", resolution: .made(query: "build_glyphs", key: "build_glyphs", definitions: [
                def("build_glyphs()", .symbol, title: "", repo: "nib", path: "Sources/glyphs.py", line: 318)]), notice: nil),
            GalleryState(id: "suggestion", label: "¿Querías decir…?", resolution: .made(query: "023", kind: .corrected, key: "D23", definitions: [d23]), notice: nil),
            GalleryState(id: "ambiguous", label: "Lectura dudosa", resolution: .made(query: "0S", kind: .ambiguous, key: nil, definitions: [os, d5]), notice: nil),
            GalleryState(id: "range", label: "Rango", resolution: .made(query: "D40-D43", key: "D40", definitions: range.entries.compactMap(\.definition), range: range), notice: nil),
            GalleryState(id: "color", label: "Color", resolution: .made(query: "--accent", key: "--accent", definitions: [accent]), notice: nil),
            GalleryState(id: "otherRepo", label: "De otro repo", resolution: .made(query: "FR-001", key: "FR-001", definitions: [
                def("FR-001", title: "El usuario ve la definición sin salir de la ventana", summary: "Requisito funcional del producto original.", repo: "automata", path: "docs/spec.md", line: 31)], fromOtherRepo: true), notice: nil),
            GalleryState(id: "notice", label: "Aviso", resolution: nil, notice: "Lupita no encuentra nada para «ZX9» en tus repos."),
            GalleryState(id: "stress", label: "Estrés: textos largos", resolution: .made(query: "ADR-0042", key: "ADR-0042", definitions: [stress], mentions: .made(byFile: many), fromOtherRepo: true), notice: nil),
        ]
    }()
}
