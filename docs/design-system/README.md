# Tooltip design system

How the Lupita tooltip is styled, in tokens, so a theme can change the look without touching the views. Decision: [D54](../decisions.md). What is where:

| File | What |
|---|---|
| [inventory.md](inventory.md) | Every style line of `TooltipPanel.swift` → the token that replaces it (53 rows, checked by script) |
| [tokens.json](tokens.json) | The three layers, the size scale, the density factors and the default theme «Cristal» |
| [themes/](themes/) | The 7 themes (Cristal has no overrides: it is tokens.json) |
| [variants/](variants/) | Five single-group variants that prove the groups are independent |
| [states.json](states.json) | Sample content for the ten tooltip states |
| [prototype.html](prototype.html) | The tooltip in HTML, driven only by tokens, with a live token editor |
| [sheets/](sheets/) | Contact sheets (per theme, comparison, independence) and the overflow report |
| [resolved/](resolved/) | Every theme with every reference resolved, per mode, ready for the port (the Swift app embeds these; `_shared.json` holds the scale, density and limits) |
| [macos-fonts.json](macos-fonts.json) | The macOS fonts on the author's Mac; `check-fonts.mjs` checks every font and weight a theme asks for against it |

## Three layers

1. **Primitive**: raw scales. `font.size.lg = 13`, `radius.pill = 999`, `space.14 = 14`, `palette.accent-light = #007AFF`, `shadow.md = [layers]`.
2. **Semantic**: roles. `text.title`, `color.surface`, `radius.container`, `space.padding`, `shadow.container`. This is the only layer a theme changes.
3. **Component**: where roles are used. `component.badge.pad-x → {space.badge-x}`. Same for every theme, and it holds **no raw values** (except `component.limits`, line counts and truncation, which are behaviour).

A theme file is `{ id, name, blurb, axes, overrides: { primitive, semantic } }`, deep-merged over `tokens.json`. `axes` must name exactly the groups the overrides touch.

## Five independent groups

| Group | Primitive | Semantic |
|---|---|---|
| **type** | `font.*` | `text.*` |
| **color** | `palette.*` | `color.*` |
| **shape** | `radius.*` | `radius.*`, `border.*` |
| **space** | `space.*` | `space.*`, `size.*` (width, swatch) |
| **shadow** | `shadow.*` | `shadow.*` |

[sheets/independence.png](sheets/independence.png) shows Cristal next to five variants that each change **one** group; `check-independence.mjs` proves the diff stays inside that group.

## Text hierarchy (fixed; a theme changes the look, not the order)

| Level | Role | Used for |
|---|---|---|
| 1 | `text.title` | what it is / means |
| 2 | `text.id` | the cited name |
| 3 | `text.description` | the explanation |
| 4 | `text.repo` | where it comes from |
| 5 | `text.location` | `path:line` |
| 6 | `text.badge` | kind, «de otro repo» |
| 7 | `text.eyebrow` | «¿Querías decir…?», range header |
| 8 | `text.footnote` | «+2 más», «citado 12 veces» |
| 9 | `text.placeholder` | «sin definición», «sin comentario» |
| 10 | `text.swatch` | colour label |
| 11 | `text.notice` | notices |

Each role carries `family, size, weight, italic, lineHeight, tracking, color`.

## Fonts, size, density (D55)

- **Fonts by role.** `font.family` is `{heading, body, code}`, each `{primary, fallback}`: a macOS font by name (or `system`) and the system design to fall back to (`default`, `serif`, `rounded`, `monospaced`). `heading` = title, placeholder · `body` = description, eyebrow, footnote, notice, badge · `code` = id, repo, location, swatch. Nothing is bundled: a font missing on a Mac falls back and the app says so. A theme may only ask a font for weights and italics its family really has (`check-fonts.mjs`).
- **Size is a setting, not a theme.** `scale` in tokens.json has four steps, S 11 / M 12 / L 14 / XL 16 (body), with heading ≈ 1.2×, code = body − 1, label ≈ 0.83× (never under 10 pt), width 400 / 440 / 480 / 520 and a swatch of 18 / 20 / 22 / 24. M is the default and equals the 0.9.0 body. A theme cannot set a size or the width.
- **Density is a setting.** `density` is a factor over every `space.*` token: compact 0.75, normal 1, airy 1.3, rounded to half a point.
- **Accessibility, not themes.** *Reduce transparency* draws every surface opaque; *Increase contrast* draws secondary text as primary and thickens borders by a point. Both apply to every theme.
- `loadTheme(id, { size, density })` in `lib.mjs` applies the scale and the factor; `build-resolved.mjs` writes what the Swift port reads and the numbers it must reproduce for every theme × size × density × mode.

## What the validator enforces (`node scripts/design-system/run-all.mjs`)

- references resolve; no raw values in the component layer; the 11 roles exist; `axes` is truthful;
- contrast ≥ 4.5:1 for every text role (≥ 7:1 on a theme with `"aaa": true`), measured with the **translucent surface laid over a white and a black page**, worst case; swatch border ≥ 3:1;
- no text under 10 pt; title ≥ 12 pt and description ≥ 11 pt (size S); `size(title) ≥ size(description) > size(caption)`, and the title heavier or higher-contrast than the description;
- width between 360 and 520;
- the default theme Cristal at M / normal keeps its numbers (`check-parity.mjs`: 56 checks, repeated in Swift by `ThemeTests.swift`);
- the size scale and the density factors are well formed, and the S / compact and XL / airy extremes hold every visual rule;
- every font and weight exists on this Mac (`check-fonts.mjs`);
- 0 overflows in the whole matrix: 7 themes × 10 states × 2 modes × 4 sizes × 3 densities = 1680 renders (`render-sheets.mjs --only matrix`, checked by `check-sheets.mjs`).

## Add a theme in 5 steps

1. Copy a close theme from `scripts/design-system/make-themes.mjs` and give it an `id`, a `name` and a `blurb`.
2. Change only what is yours: `fonts` (by role), `type` (weights, colours, tracking; never sizes), `color` (pairs `[light, dark]`), `radius`/`border`, `space`/`size`, `shadows`/`shadow`.
3. `node scripts/design-system/make-themes.mjs` writes `themes/<id>.json`.
4. `node scripts/design-system/run-all.mjs` until it says `ALL GREEN`.
5. `node scripts/design-system/render-sheets.mjs --themes <id>` and look at `sheets/theme-<id>.png` next to Cristal before keeping it.
   Playwright is not in the repo. On Manu's Mac it lives in `~/.local/share/lupita-tools`: run with `NODE_PATH=~/.local/share/lupita-tools/node_modules`.

## Mapping to SwiftUI (for the port)

| Token | SwiftUI |
|---|---|
| `font.family.*` | `ThemeFonts.nsFont`: the named macOS font at the exact weight, or the system design |
| `text.*` | `.font(.system(size:weight:design:))`, `.italic()`, `.lineSpacing(…)`, `.tracking(…)`, colour from `color.*` |
| `color.*` light/dark | `Color(light:dark:)` via `NSColor(name:dynamicProvider:)` |
| `color.surface` + `surface-blur` | macOS can't set the blur radius of a material: use `.regularMaterial`/`.thinMaterial` per theme or `NSVisualEffectView` with a tint; the number is a hint |
| `shadow.*` | **`hasShadow = false` on the panel** and draw the layers with `.shadow(color:radius:x:y:)` (`radius` ≈ CSS blur / 2); the system shadow is not a token. Padding around the view must leave room for the shadow |
| `radius.pill` | `Capsule()` |
| `border.*` | `strokeBorder(color, lineWidth:)`; 0 = no overlay |

In the HTML prototype every named font is the real macOS font; only the system fallbacks have stand-ins (Chromium cannot reach SF Mono, New York or SF Rounded). The real drawing is the Swift one: `LupitaApp --render-themes` writes the contact sheets in `sheets-real/`.
