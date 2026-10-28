#!/usr/bin/env node
// Builds docs/design-system/prototype.html: ONE self-contained page that renders the 10 tooltip states
// for every theme and variant, with every style value coming from CSS custom properties generated
// from the resolved tokens (the static stylesheet only references var(--…); see check-no-raw-style.mjs).
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs'
import { DS, ROOT, loadTheme, listThemes, leaves } from './lib.mjs'

const ROLES = ['title', 'id', 'description', 'repo', 'location', 'badge', 'eyebrow', 'footnote', 'placeholder', 'swatch', 'notice']

export function listVariants() {
  const dir = `${DS}/variants`
  return existsSync(dir) ? readdirSync(dir).filter(f => f.endsWith('.json')).map(f => f.replace(/\.json$/, '')).sort() : []
}

export function buildPrototype() {
  const base = JSON.parse(readFileSync(`${DS}/tokens.json`, 'utf8'))
  const states = JSON.parse(readFileSync(`${DS}/states.json`, 'utf8')).states
  // Semantic keys we expose as CSS variables (primitive names such as radius.lg clash with semantic ones, so the base file is the whitelist).
  const semanticKeys = leaves(base.semantic, '', 'semantic').map(([p]) => p)
  const limitKeys = leaves(base.component.limits, 'component.limits', 'component').map(([p]) => p)
  const keep = new Set([...semanticKeys, ...limitKeys])
  const pick = flat => Object.fromEntries(Object.entries(flat).filter(([k]) => keep.has(k)))

  const ids = [...listThemes().map(id => [id, false]), ...listVariants().map(id => [id, true])]
  const themes = ids.map(([id, variant]) => {
    const t = loadTheme(id)
    if (t.errors.length) console.warn(`warning: theme ${id}: ${t.errors.join('; ')}`)
    return { id: t.id, name: t.name, blurb: t.blurb, axes: t.axes, baseline: t.baseline, variant, light: pick(t.light), dark: pick(t.dark) }
  })
  const def = themes.find(t => t.baseline) ?? themes.find(t => t.id === 'lupita') ?? themes[0]

  // Default variables (baseline theme, light): the page is usable before any script runs. The client sets the same names inline per tooltip.
  const vars = defaultVars(def.light)
  const generated = `/*GENERATED-VARS*/
:root {
  /* Font mapping (this machine): sans → Inter, serif → Bitstream Charter, rounded → Inter (approximation: no SF Rounded here), mono → JetBrains Mono. 1 pt = 1 px. */
  --font-sans: Inter, system-ui, sans-serif;
  --font-serif: 'Bitstream Charter', Charter, serif;
  --font-rounded: Inter, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;
  /* Constant of the material (macOS regularMaterial saturates what it blurs). */
  --color-surface-saturate: 1.8;
${Object.entries(vars).map(([k, v]) => `  ${k}: ${v};`).join('\n')}
}
/*END-GENERATED-VARS*/`

  const textRules = ROLES.map(r => `.t-${r} { font-family: var(--text-${r}-family); font-size: var(--text-${r}-size); font-weight: var(--text-${r}-weight); font-style: var(--text-${r}-style); line-height: var(--text-${r}-lh); letter-spacing: var(--text-${r}-tracking); color: var(--text-${r}-color); }`).join('\n')

  const staticCss = `/*STATIC*/
${textRules}
.tooltip { position: relative; box-sizing: border-box; display: flex; flex-direction: column; align-items: stretch; width: var(--size-width); padding: var(--space-padding); gap: var(--space-block-gap); background: var(--color-surface); -webkit-backdrop-filter: blur(var(--color-surface-blur)) saturate(var(--color-surface-saturate)); backdrop-filter: blur(var(--color-surface-blur)) saturate(var(--color-surface-saturate)); border-radius: var(--radius-container); box-shadow: var(--shadow-container); text-align: left; }
.tooltip::after, .notice::after { content: ""; position: absolute; inset: 0; box-sizing: border-box; border-radius: inherit; pointer-events: none; }
.tooltip::after { border: var(--border-container) solid var(--color-border); }
.tooltip.range { gap: var(--space-range-gap); }
.notice { position: relative; box-sizing: border-box; display: block; width: max-content; max-width: var(--size-width); padding: var(--space-notice-y) var(--space-notice-x); background: var(--color-notice-surface); -webkit-backdrop-filter: blur(var(--color-surface-blur)) saturate(var(--color-surface-saturate)); backdrop-filter: blur(var(--color-surface-blur)) saturate(var(--color-surface-saturate)); border-radius: var(--radius-notice); box-shadow: var(--shadow-notice); }
.notice::after { border: var(--border-notice) solid var(--color-border); }
.row { display: flex; flex-direction: column; align-items: stretch; gap: var(--space-row-gap); min-width: 0; }
.row.hover { background: var(--color-row-hover); }
.row.muted { opacity: var(--color-suggestion-opacity); }
.name { display: flex; flex-direction: column; align-items: stretch; gap: var(--space-name-gap); min-width: 0; }
.clamp { display: -webkit-box; -webkit-box-orient: vertical; overflow: hidden; }
.clamp-title { -webkit-line-clamp: var(--limit-title-lines); }
.clamp-description { -webkit-line-clamp: var(--limit-description-lines); }
.one-line { white-space: nowrap; overflow: hidden; min-width: 0; }
.multi-line { overflow-wrap: anywhere; min-width: 0; }
.swatches { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-swatch-gap); }
.swatch { display: flex; align-items: center; gap: var(--space-swatch-inner-gap); }
.chip { flex: none; box-sizing: border-box; width: var(--size-swatch); height: var(--size-swatch); border: var(--border-swatch) solid var(--color-swatch-border); border-radius: var(--radius-swatch); }
.meta { display: flex; flex-wrap: nowrap; align-items: center; gap: var(--space-inline-gap); min-width: 0; }
.meta > .repo { flex: none; max-width: 100%; white-space: nowrap; }
.meta > .location { flex: 0 1 auto; }
.badge { flex: none; padding: var(--space-badge-y) var(--space-badge-x); border-radius: var(--radius-badge); background: var(--color-badge-bg); white-space: nowrap; }
.badge.origin { background: var(--color-origin-bg); color: var(--color-origin-fg); }
.lines { display: flex; flex-direction: column; align-items: stretch; gap: var(--space-range-line-gap); }
.entry { display: flex; align-items: baseline; gap: var(--space-entry-gap); min-width: 0; }
.entry-id { flex: none; white-space: nowrap; }
.entry-title { flex: 1 1 0; min-width: 0; }
/*END-STATIC*/`

  const data = { themes, states, semanticKeys, defaultTheme: def.id }
  const json = JSON.stringify(data).replace(/</g, '\\u003c')
  const client = readFileSync(new URL('./prototype-client.js', import.meta.url), 'utf8')

  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lupita · prototipo de tooltips</title>
<!-- Generated by scripts/design-system/build-prototype.mjs. Do not edit by hand. -->
<style id="tooltip">
${generated}
${staticCss}
</style>
<style id="chrome">
/* Page chrome (toolbar, labels, faux backdrop). Exempt from check-no-raw-style. */
html { color-scheme: light dark; }
html[data-mode="light"] { --page: #F2F2F4; --ink: #1d1d1f; --ink2: #6e6e73; --panel: #FFFFFF; --line: #D8D8DC; --faux: #C9C9CE; }
html[data-mode="dark"] { --page: #1C1C1E; --ink: #f5f5f7; --ink2: #98989d; --panel: #2C2C2E; --line: #3A3A3C; --faux: #48484C; }
html:not([data-mode]) { --page: #F2F2F4; --ink: #1d1d1f; --ink2: #6e6e73; --panel: #FFFFFF; --line: #D8D8DC; --faux: #C9C9CE; }
body { margin: 0; background: var(--page); color: var(--ink); font: 13px/1.4 Inter, system-ui, sans-serif; }
.bar { position: sticky; top: 0; z-index: 5; display: flex; flex-wrap: wrap; gap: 10px 14px; align-items: center; padding: 10px 16px; background: var(--panel); border-bottom: 1px solid var(--line); }
.bar h1 { margin: 0 6px 0 0; font-size: 14px; font-weight: 600; }
.bar label { display: flex; gap: 6px; align-items: center; color: var(--ink2); }
.bar select, .bar input, .bar button { font: inherit; color: var(--ink); background: var(--page); border: 1px solid var(--line); border-radius: 6px; padding: 4px 8px; }
.bar input[type=number], .bar input[type=text] { width: 110px; }
.bar input[type=color] { width: 34px; padding: 1px; height: 28px; }
.bar button { cursor: pointer; }
.bar .sep { width: 1px; align-self: stretch; background: var(--line); }
.bar small { color: var(--ink2); }
#blurb { margin: 10px 16px 0; color: var(--ink2); max-width: 900px; }
main { padding: 16px; }
main.single { display: flex; }
main.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(520px, 1fr)); gap: 18px; }
.card { margin: 0; min-width: 0; }
.card figcaption { margin: 0 0 6px; color: var(--ink2); font-size: 12px; font-weight: 600; }
.stage { position: relative; overflow: hidden; box-sizing: border-box; padding: 28px; min-height: 120px; border-radius: 10px; border: 1px solid var(--line); }
.stage[data-mode="light"] { background: #F2F2F4; }
.stage[data-mode="dark"] { background: #1C1C1E; }
.faux { position: absolute; inset: 0; display: flex; flex-direction: column; justify-content: space-between; padding: 14px 20px; }
.faux i { display: block; height: 7px; border-radius: 4px; flex: none; }
.stage[data-mode="light"] .faux i { background: #C4C4CA; }
.stage[data-mode="dark"] .faux i { background: #55555B; }
.faux b { position: absolute; left: 0; right: 0; top: 34%; height: 26%; background: linear-gradient(90deg, #E5484D, #F5A524 45%, #3E63DD); opacity: .85; }
.scope { position: relative; width: fit-content; max-width: 100%; }
footer { padding: 4px 16px 24px; color: var(--ink2); font-size: 12px; max-width: 900px; }
</style>
</head>
<body>
<header class="bar">
  <h1>Lupita · tooltips</h1>
  <label>Tema <select id="theme"></select></label>
  <button id="mode" type="button" title="Claro / oscuro">Claro</button>
  <label>Estado <select id="state"></select></label>
  <button id="viewbtn" type="button" title="Un estado o los diez">Un estado</button>
  <span class="sep"></span>
  <label>Token <select id="tok"></select></label>
  <input id="tokval" type="number" aria-label="Valor del token"><input id="tokcol" type="color" hidden aria-label="Color">
  <button id="reset" type="button">reset</button><button id="resetall" type="button">reset todo</button>
  <small id="tokdef"></small>
</header>
<p id="blurb"></p>
<main id="view" class="single"></main>
<footer>Fuentes de sustitución: Inter ≈ SF Pro · Charter ≈ New York · JetBrains Mono ≈ SF Mono. Lo que cuenta son los tamaños relativos, no el trazo exacto. La familia «rounded» se aproxima con Inter (no hay SF Rounded en esta máquina). 1 pt = 1 px.</footer>
<script id="proto-data" type="application/json">${json}</script>
<script>
${client}
</script>
</body>
</html>
`

  function defaultVars(res) {
    // Same transformation as varsFor() in the client; kept in sync by test (the page overrides these inline anyway).
    const px = n => `${n}px`, v = {}
    for (const [k, val] of Object.entries(res)) {
      const name = '--' + k.replace(/^component\.limits\./, 'limit-').replace(/\./g, '-')
      if (k.startsWith('text.')) {
        const fam = { sans: 'sans', serif: 'serif', rounded: 'rounded', mono: 'mono' }[val.familyKey] ?? { default: 'sans', monospaced: 'mono', serif: 'serif', rounded: 'rounded' }[val.family] ?? 'sans'
        Object.assign(v, { [`${name}-family`]: `var(--font-${fam})`, [`${name}-size`]: px(val.size), [`${name}-weight`]: String(val.weight), [`${name}-style`]: val.italic ? 'italic' : 'normal', [`${name}-lh`]: String(val.lineHeight), [`${name}-tracking`]: px(val.tracking), [`${name}-color`]: val.color })
      } else if (k.startsWith('shadow.')) {
        v[name] = val.length ? val.map(l => `${px(l.x)} ${px(l.y)} ${px(l.blur)} ${px(l.spread)} ${l.color}`).join(', ') : '0 0 0 0 transparent'
      } else if (k.startsWith('component.limits.')) { if (typeof val === 'number') v[name] = String(val) }
      else if (typeof val === 'number') v[name] = k === 'color.suggestion-opacity' ? String(val) : px(val)
      else v[name] = String(val)
    }
    return v
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const html = buildPrototype()
  writeFileSync(`${DS}/prototype.html`, html)
  console.log(`wrote docs/design-system/prototype.html (${(html.length / 1024).toFixed(0)} KB)`)
}
