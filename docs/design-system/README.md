# Tooltip design system

How the Lupita tooltip is styled, in tokens, so a theme can change the look without touching the views. Decision: [D54](../decisions.md). What is where:

| File | What |
|---|---|
| [inventory.md](inventory.md) | Every style line of `TooltipPanel.swift` → the token that replaces it (53 rows, checked by script) |
| [tokens.json](tokens.json) | The three layers and the default theme «Lupita» (= the 0.9.0 look) |
| [themes/](themes/) | The 10 themes (Lupita has no overrides) |
| [variants/](variants/) | Five single-group variants that prove the groups are independent |
| [states.json](states.json) | Sample content for the ten tooltip states |
| [prototype.html](prototype.html) | The tooltip in HTML, driven only by tokens, with a live token editor |
| [sheets/](sheets/) | Contact sheets (per theme, comparison, independence) and the overflow report |
| [resolved/](resolved/) | Every theme with every reference resolved, per mode, ready for the port |

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

[sheets/independence.png](sheets/independence.png) shows Lupita next to five variants that each change **one** group; `check-independence.mjs` proves the diff stays inside that group.

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

Each role carries `family, size, weight, italic, lineHeight, tracking, color`. Families are the four SwiftUI designs only (`default`, `serif`, `rounded`, `monospaced`), so nothing needs a font file.

## What the validator enforces (`node scripts/design-system/run-all.mjs`)

- references resolve; no raw values in the component layer; the 11 roles exist; `axes` is truthful;
- contrast ≥ 4.5:1 for every text role (≥ 7:1 on a theme with `"aaa": true`), measured with the **translucent surface laid over a white and a black page**, worst case; swatch border ≥ 3:1;
- no text under 10 pt; title and description ≥ 12 pt; `size(title) ≥ size(description) > size(caption)`, and the title heavier or higher-contrast than the description;
- width between 360 and 520;
- the default theme reproduces the code (`check-parity.mjs`: 51 checks). The theme `lupita` is marked `baseline`: its failures print as warnings, because it keeps macOS system colours.

## Add a theme in 5 steps

1. Copy a close theme from `scripts/design-system/make-themes.mjs` and give it an `id`, a `name` and a `blurb`.
2. Change only what is yours: `type` (roles), `color` (pairs `[light, dark]`), `radius`/`border`, `space`/`size`, `shadows`/`shadow`.
3. `node scripts/design-system/make-themes.mjs` writes `themes/<id>.json`.
4. `node scripts/design-system/run-all.mjs` until it says `ALL GREEN`.
5. `node scripts/design-system/render-sheets.mjs --themes <id>` and look at `sheets/theme-<id>.png` next to Lupita before keeping it.
   Playwright is not in the repo. On Manu's Mac it lives in `~/.local/share/lupita-tools`: run with `NODE_PATH=~/.local/share/lupita-tools/node_modules`.

## Mapping to SwiftUI (for the port)

| Token | SwiftUI |
|---|---|
| `font.family.*` | `Font.Design`: `.default`, `.serif`, `.rounded`, `.monospaced` |
| `text.*` | `.font(.system(size:weight:design:))`, `.italic()`, `.lineSpacing(…)`, `.tracking(…)`, colour from `color.*` |
| `color.*` light/dark | `Color(light:dark:)` via `NSColor(name:dynamicProvider:)` |
| `color.surface` + `surface-blur` | macOS can't set the blur radius of a material: use `.regularMaterial`/`.thinMaterial` per theme or `NSVisualEffectView` with a tint; the number is a hint |
| `shadow.*` | **`hasShadow = false` on the panel** and draw the layers with `.shadow(color:radius:x:y:)` (`radius` ≈ CSS blur / 2); the system shadow is not a token. Padding around the view must leave room for the shadow |
| `radius.pill` | `Capsule()` |
| `border.*` | `strokeBorder(color, lineWidth:)`; 0 = no overlay |

Fonts in the prototype are stand-ins: Inter ≈ SF Pro, Charter ≈ New York, JetBrains Mono ≈ SF Mono. Relative sizes are what count. `rounded` has no stand-in here and is drawn with Inter.
