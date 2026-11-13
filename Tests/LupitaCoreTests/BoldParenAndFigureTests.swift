import Foundation
import Testing
@testable import LupitaCore

// Lot 6: `- **V1 (sintáctico)**: …` defines V1, and `FIG. 1` is a reference to a figure of the document.
@Suite struct BoldParenAndFigureTests {
    static func hit(_ line: String) -> DefinitionHit? { DefinitionRules.lineDefinition(line) }

    @Test func boldIDWithAQualifierInBracketsDefinesTheID() {
        for line in ["- **V1 (sintáctico)**: matchea tokens", "**V1 (sintáctico):** matchea tokens", "1. **V1 (sintáctico)** — matchea tokens", "  * **V1 (sintáctico)**: matchea tokens"] {
            let h = Self.hit(line)
            #expect(h?.id.key == "V1", "\(line)")
            #expect(h?.title == "sintáctico: matchea tokens", "\(line)")
        }
    }

    @Test func aBoldIDWithABracketedAsideAndNoSeparatorIsAMention() {
        #expect(Self.hit("- **D008** (aside) said so") == nil)
        #expect(Self.hit("- **V1 (sintáctico)** matchea tokens") == nil)
        #expect(Self.hit("**See V1 (sintáctico)**: no") == nil)
        #expect(Self.hit("- **version 1 (old)**: no") == nil)
    }

    @Test func theQualifierAloneIsTheTitleWhenThereIsNoText() {
        #expect(Self.hit("- **V2 (semántico):**")?.title == "semántico")
    }

    @Test func figureLabelsAreIDs() {
        #expect(IDGrammar.tokens(in: "mueve FIG. 1 y FIG.2, no FIG 3 ni FIG. 12a").map(\.id.key) == ["FIG 1", "FIG 2"])
        #expect(IDGrammar.parse("FIG. 1")?.key == "FIG 1")
        #expect(IDGrammar.tokens(in: "Fig. 1 and fig. 2 in lower case").isEmpty)
    }

    @Test func figureDefinitionsInATableAListAndAHeading() {
        #expect(Self.hit("| **FIG. 1 — glifo en edición** | el glifo sobre su rejilla |")?.title == "glifo en edición: el glifo sobre su rejilla")
        #expect(Self.hit("- **FIG. 3 por bloques**: Letras 52")?.title == "por bloques: Letras 52")
        #expect(Self.hit("## FIG. 2 — El grupo")?.title == "El grupo")
        #expect(Self.hit("tocar la altura puede mover FIG. 1 y las cajas") == nil)
        #expect(Self.hit("- FIG. 1 shows the thing") == nil)
    }

    @Test func aFigureIsDefinedInItsOwnRepoAndFoundFromAnotherDocument() {
        var index = RefIndex()
        index.add(text: "| **FIG. 1 — glifo** | el glifo |", fileName: "UI.md", repo: "nib", relativePath: "viewer/UI.md", absolutePath: "/nib/viewer/UI.md")
        index.add(text: "Estructura: FIG. 1 (glifo activo).", fileName: "PRODUCT.md", repo: "nib", relativePath: "PRODUCT.md", absolutePath: "/nib/PRODUCT.md")
        index.rank()
        let r = Resolver(index: index)
        let defs = r.shownDefinitions(for: IDGrammar.parse("FIG. 1")!, preferredRepo: "nib", fromPath: "PRODUCT.md")
        #expect(defs.first?.path == "viewer/UI.md")
    }

    @Test func aBoldParenDefinitionInAnotherRepoDoesNotBeatTheReadersOwn() {
        var index = RefIndex()
        index.add(text: "- **V1 (sintáctico)**: mira tokens", fileName: "scan.md", repo: "ds", relativePath: "scan.md", absolutePath: "/ds/scan.md")
        index.add(text: "- **V1**: otra cosa distinta", fileName: "other.md", repo: "other", relativePath: "other.md", absolutePath: "/other/other.md")
        index.rank()
        let r = Resolver(index: index)
        #expect(r.shownDefinitions(for: IDGrammar.parse("V1")!, preferredRepo: "ds", fromPath: nil).first?.repo == "ds")
    }
}
