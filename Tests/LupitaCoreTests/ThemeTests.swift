import Testing
import AppKit
@testable import LupitaCore

// D54 / D55: the tooltip reads its style from the design-system tokens. These tests pin the Swift port to the
// numbers of docs/design-system (scripts/design-system/check-parity.mjs holds the same table for the JSON).

@Suite struct ThemeParityTests {
    /// Cristal, light, M, normal: the 56 checks of check-parity.mjs.
    @Test func cristalMatchesTheTokens() {
        let t = TooltipTheme.load("cristal")
        let checks: [(String, Double, Double)] = [
            ("width", t.width, 440), ("padding", t.space.padding, 18), ("radius container", t.radius.container, 20),
            ("notice radius", t.radius.notice, 14), ("swatch radius", t.radius.swatch, 10), ("badge capsule", t.radius.badge, 999),
            ("swatch size", t.swatchSize, 20), ("range-gap", t.space.rangeGap, 10), ("range-line-gap", t.space.rangeLineGap, 6),
            ("entry-gap", t.space.entryGap, 10), ("inline-gap", t.space.inlineGap, 8), ("block-gap", t.space.blockGap, 12),
            ("row-gap", t.space.rowGap, 5), ("name-gap", t.space.nameGap, 3), ("row-pad-x", t.space.rowPadX, 8), ("row-pad-y", t.space.rowPadY, 4),
            ("meta-gap", t.space.metaGap, 4), ("row radius", t.radius.row, 8), ("swatch-gap", t.space.swatchGap, 12),
            ("swatch-inner-gap", t.space.swatchInnerGap, 6), ("badge-x", t.space.badgeX, 8), ("badge-y", t.space.badgeY, 2),
            ("notice-x", t.space.noticeX, 16), ("notice-y", t.space.noticeY, 10), ("border container", t.border.container, 1),
            ("border swatch", t.border.swatch, 1), ("border notice", t.border.notice, 1), ("suggestion opacity", t.suggestionOpacity, 0.72),
            ("title size", t.text(.title).size, 14), ("title weight", Double(t.text(.title).weight), 500),
            ("id size", t.text(.id).size, 11), ("id weight", Double(t.text(.id).weight), 600),
            ("description size", t.text(.description).size, 12), ("description weight", Double(t.text(.description).weight), 400),
            ("repo size", t.text(.repo).size, 10), ("repo weight", Double(t.text(.repo).weight), 600),
            ("location size", t.text(.location).size, 10), ("location weight", Double(t.text(.location).weight), 400),
            ("badge size", t.text(.badge).size, 10), ("badge weight", Double(t.text(.badge).weight), 600),
            ("eyebrow size", t.text(.eyebrow).size, 10), ("footnote size", t.text(.footnote).size, 10),
            ("placeholder size", t.text(.placeholder).size, 14), ("swatch size", t.text(.swatch).size, 10), ("notice size", t.text(.notice).size, 12),
            ("title lines", Double(t.limits.titleLines), 4), ("range title lines", Double(t.limits.rangeTitleLines), 1),
            ("id lines", Double(t.limits.idLines), 2), ("description lines", Double(t.limits.descriptionLines), 4),
            ("location lines", Double(t.limits.locationLines), 1), ("max rows", Double(t.limits.maxRows), 3),
        ]
        for (name, actual, expected) in checks { #expect(actual == expected, "\(name): \(actual) != \(expected)") }
        #expect(t.text(.title).fontRole == .heading && t.text(.id).fontRole == .code && t.text(.description).fontRole == .body)
        #expect(t.text(.location).fontRole == .code && t.text(.swatch).fontRole == .code)
        #expect(t.text(.placeholder).italic)
        #expect(t.surfaceBlur == 40)
    }

    @Test func cristalColorsAndShadow() {
        let light = TooltipTheme.load("cristal", mode: .light), dark = TooltipTheme.load("cristal", mode: .dark)
        #expect(light.colors.surface == RGBA(hex: "#FFFFFF40"))
        #expect(dark.colors.surface == RGBA(hex: "#141A2C59"))
        #expect(light.containerShadow.count == 2 && light.containerShadow[0].y == 28 && light.containerShadow[0].blur == 64 && light.containerShadow[0].spread == -8)
        #expect(light.colors.textPrimary == RGBA(hex: "#0B1B2E"))
    }

    @Test func cristalBorderIsAHairlineLikeTheSystemSeparator() {
        #expect(TooltipTheme.load("cristal", mode: .light).colors.border == RGBA(hex: "#00000024"))
        #expect(TooltipTheme.load("cristal", mode: .dark).colors.border == RGBA(hex: "#FFFFFF29"))
    }

    @Test func terminalHasAVisibleEdgeInBothModes() {
        for mode in ThemeMode.allCases {
            let t = TooltipTheme.load("terminal", mode: mode)
            #expect(t.colors.border == RGBA(hex: "#3DFF7A99") && t.border.container >= 1)
        }
    }

    @Test func onlyNeonDrawsAnInnerHalo() {
        for id in TooltipTheme.ids {
            let layers = TooltipTheme.load(id).insetShadow
            #expect(layers.isEmpty == (id != "neon"), "\(id)")
        }
        #expect(TooltipTheme.load("neon").insetShadow.first?.blur == 10)
    }

    @Test func cristalIsTheDefault() {
        #expect(TooltipTheme.defaultID == "cristal" && TooltipTheme.ids.first == "cristal")
        #expect(TooltipTheme.load("no-such-theme").id == "cristal")
    }
}

@Suite struct ThemeLoadTests {
    @Test func sevenThemesLoadInEveryCombination() {
        #expect(TooltipTheme.ids.count == 7)
        for id in TooltipTheme.ids { for size in ThemeSize.allCases { for density in ThemeDensity.allCases { for mode in ThemeMode.allCases {
            let t = TooltipTheme.load(id, mode: mode, size: size, density: density)
            #expect(t.id == id && t.size == size && t.density == density && t.mode == mode)
            #expect(t.width >= 400 && t.width <= 520)
            for role in TextRole.allCases { #expect(t.text(role).size >= 10) }
        } } } }
    }

    @Test func sizeStepsGrowTheTextAndTheWidth() {
        let widths = ThemeSize.allCases.map { TooltipTheme.load("papel", size: $0).width }
        #expect(widths == [400, 440, 480, 520])
        let body = ThemeSize.allCases.map { TooltipTheme.load("papel", size: $0).text(.description).size }
        #expect(body == [11, 12, 14, 16])
        let heading = ThemeSize.allCases.map { TooltipTheme.load("papel", size: $0).text(.title).size }
        #expect(heading == [13, 14, 17, 19])
    }

    @Test func densityScalesTheSpaceOnly() {
        let c = TooltipTheme.load("cristal", density: .compact), n = TooltipTheme.load("cristal"), a = TooltipTheme.load("cristal", density: .airy)
        #expect(c.space.padding < n.space.padding && n.space.padding < a.space.padding)
        #expect(c.space.padding == 13.5 && a.space.padding == 23.5)
        #expect(c.text(.title).size == n.text(.title).size && c.width == n.width && c.radius == n.radius)
    }

    @Test func everyThemeHasADistinctNameAndBlurb() {
        let names = TooltipTheme.names.map(\.name)
        #expect(Set(names).count == 7)
        for id in TooltipTheme.ids { #expect(!TooltipTheme.load(id).blurb.isEmpty) }
    }

    @Test func reduceTransparencyMakesTheSurfaceSolid() {
        let t = TooltipTheme.load("cristal", accessibility: ThemeAccessibility(reduceTransparency: true))
        #expect(t.colors.surface.a == 1 && t.colors.noticeSurface.a == 1 && t.surfaceBlur == 0)
        #expect(TooltipTheme.load("cristal").colors.surface.a < 1)
    }

    @Test func increaseContrastDarkensSecondaryTextAndThickensBorders() {
        let base = TooltipTheme.load("cristal"), t = TooltipTheme.load("cristal", accessibility: ThemeAccessibility(increaseContrast: true))
        #expect(t.text(.description).color == base.colors.textPrimary)
        #expect(t.text(.repo).color == base.text(.repo).color)   // accent stays accent
        #expect(t.border.container == base.border.container + 1)
    }

    @Test func shadowInsetsCoverTheShadow() {
        let t = TooltipTheme.load("cristal")
        let i = t.shadowInsets(of: t.containerShadow)
        #expect(i.top >= 0 && i.bottom >= 28 + 56 - 8 - 1 && i.left > 0)
        #expect(TooltipTheme.load("terminal").shadowInsets(of: TooltipTheme.load("terminal").containerShadow) == (0, 0, 0, 0))
        let hard = TooltipTheme.load("brutalista")
        #expect(hard.shadowInsets(of: hard.containerShadow).right == 5 && hard.shadowInsets(of: hard.containerShadow).left == 0)
    }
}

/// Every theme × size × density × mode against what the JSON loader computes (ThemeExpected.generated.swift).
@Suite struct ThemeMatrixTests {
    @Test func swiftArithmeticMatchesTheTokenLoaderEverywhere() {
        let lines = ThemeExpected.lines.split(separator: "\n")
        #expect(lines.count == 7 * 4 * 3 * 2)
        for line in lines {
            let parts = line.split(separator: "\t")
            let key = parts[0].split(separator: "/").map(String.init)
            let t = TooltipTheme.load(key[0], mode: ThemeMode(rawValue: key[1])!, size: ThemeSize(rawValue: key[2])!, density: ThemeDensity(rawValue: key[3])!)
            var got: [String: Double] = ["width": t.width, "swatch": t.swatchSize]
            for r in TextRole.allCases { got["\(r.rawValue).size"] = t.text(r).size }
            let s = t.space
            for (k, v) in ["padding": s.padding, "blockGap": s.blockGap, "rangeGap": s.rangeGap, "rangeLineGap": s.rangeLineGap, "entryGap": s.entryGap,
                           "inlineGap": s.inlineGap, "rowGap": s.rowGap, "nameGap": s.nameGap, "swatchGap": s.swatchGap, "swatchInnerGap": s.swatchInnerGap,
                           "badgeX": s.badgeX, "badgeY": s.badgeY, "noticeX": s.noticeX, "noticeY": s.noticeY, "rowPadX": s.rowPadX, "rowPadY": s.rowPadY,
                           "metaGap": s.metaGap] { got["space.\(k)"] = v }
            for pair in parts[1].split(separator: ";") {
                let kv = pair.split(separator: "="), name = String(kv[0]), want = Double(kv[1])!
                #expect(got[name] == want, "\(parts[0]) \(name): \(String(describing: got[name])) != \(want)")
            }
        }
    }
}

/// Criterion 5: every font a theme names exists on this Mac, or the fallback is announced; none resolves to a different face.
@Suite struct ThemeFontsTests {
    @Test func everyNamedFontIsInstalledAndResolvesToItself() {
        for id in TooltipTheme.ids {
            let t = TooltipTheme.load(id)
            for (role, spec) in t.fonts {
                switch ThemeFonts.resolve(spec) {
                case .system: #expect(spec.isSystem)
                case .named(let n): #expect(n == spec.primary)
                case .fallback(let missing, _): Issue.record("\(id) \(role): font «\(missing)» is not installed here")
                }
            }
        }
    }

    @Test func everyRoleGetsTheExactFaceItAsksFor() {
        for id in TooltipTheme.ids {
            for mode in ThemeMode.allCases {
                let t = TooltipTheme.load(id, mode: mode)
                for role in TextRole.allCases {
                    let s = t.text(role)
                    let f = ThemeFonts.nsFont(s.font, size: s.size, weight: s.weight, italic: s.italic)
                    if !s.font.isSystem { #expect(f.familyName == s.font.primary, "\(id) \(role): \(f.familyName ?? "?") instead of \(s.font.primary)") }
                    if s.italic && !s.font.isSystem { #expect(f.fontDescriptor.symbolicTraits.contains(.italic), "\(id) \(role) lost the italic") }
                    if !s.font.isSystem {
                        let got = (f.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any])?[.weight] as? Double ?? 0
                        let want = Double(ThemeFonts.weight(s.weight).rawValue)
                        #expect(abs(got - want) < 0.16, "\(id) \(role): weight \(got) for \(s.weight) (\(want)) in \(f.fontName)")
                    }
                }
            }
        }
    }

    @Test func aMissingFontFallsBackAndSaysSo() {
        let spec = FontSpec(primary: "No Such Font XYZ", fallback: .serif)
        #expect(ThemeFonts.resolve(spec) == .fallback(missing: "No Such Font XYZ", .serif))
    }

    @Test func fontSpecDecodesFromJSON() throws {
        let spec = try JSONDecoder().decode(FontSpec.self, from: Data(#"{"primary":"Menlo","fallback":"monospaced"}"#.utf8))
        #expect(spec.primary == "Menlo" && spec.fallback == .monospaced)
    }
}
