#!/usr/bin/env node
// Renders contact sheets of the tooltip prototype with Playwright.
//   node scripts/design-system/render-sheets.mjs [--themes a,b,c] [--only theme|compare|independence] [--state definition] [--out docs/design-system/sheets]
// One browser, one page, fonts awaited once. Every render also runs the overflow check
// (scrollWidth <= clientWidth + 1 on the tooltip root and each [data-role] element; width == size.width).
import { createRequire } from 'node:module'
import { mkdirSync, readFileSync, writeFileSync, existsSync, copyFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { ROOT, DS, listThemes } from './lib.mjs'
import { buildPrototype, listVariants } from './build-prototype.mjs'

const { chromium } = createRequire(import.meta.url)('playwright')

const args = process.argv.slice(2)
const opt = (name, d) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : d }
const only = opt('only', null)
const out = resolve(ROOT, opt('out', 'docs/design-system/sheets'))
const compareState = opt('state', 'definition')
const t0 = Date.now()
const log = m => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`)

writeFileSync(`${DS}/prototype.html`, buildPrototype())
mkdirSync(out, { recursive: true })

const known = new Set([...listThemes(), ...listVariants()])
const themeIds = (opt('themes', null)?.split(',').filter(Boolean) ?? listThemes())
for (const id of themeIds) if (!known.has(id)) { console.error(`unknown theme: ${id}`); process.exit(2) }

const SHEET_CSS = `
body { margin: 0; background: #FFFFFF; }
#sheet { box-sizing: border-box; padding: 28px 32px 32px; background: #FAFAFB; color: #1d1d1f; font: 13px/1.4 Inter, sans-serif; }
#sheet h1 { margin: 0; font-size: 22px; font-weight: 650; }
#sheet .sub { margin: 4px 0 18px; color: #6e6e73; max-width: 1100px; }
#sheet .grid { display: grid; gap: 16px 18px; align-items: start; }
#sheet .head { font-weight: 650; color: #6e6e73; font-size: 12px; text-transform: uppercase; letter-spacing: .06em; }
#sheet .rowlabel { padding-top: 10px; }
#sheet .rowlabel b { display: block; font-size: 15px; }
#sheet .rowlabel span { display: block; color: #6e6e73; font-size: 12px; margin-top: 2px; }
#sheet .cap { margin: 0 0 5px; color: #6e6e73; font-size: 12px; font-weight: 600; }
#sheet .stage { height: 100%; }
`

async function renderSheet(page, spec, file) {
  const result = await page.evaluate(spec => {
    const sheet = document.createElement('div'); sheet.id = 'sheet'; sheet.style.width = spec.width + 'px'
    const h1 = document.createElement('h1'); h1.textContent = spec.title
    const sub = document.createElement('div'); sub.className = 'sub'; sub.textContent = spec.sub || ''
    sheet.append(h1, sub)
    const grid = document.createElement('div'); grid.className = 'grid'
    grid.style.gridTemplateColumns = (spec.labelWidth ? spec.labelWidth + 'px ' : '') + 'repeat(' + spec.cols.length + ', minmax(0, 1fr))'
    const mk = (cls, text) => { const d = document.createElement('div'); d.className = cls; if (text) d.textContent = text; return d }
    if (spec.heads) { if (spec.labelWidth) grid.append(mk('head', '')); spec.cols.forEach(c => grid.append(mk('head', c))) }
    const jobs = []
    spec.rows.forEach(row => {
      if (spec.labelWidth) { const l = mk('rowlabel'); const b = document.createElement('b'); b.textContent = row.label; const s = document.createElement('span'); s.textContent = row.sub || ''; l.append(b, s); grid.append(l) }
      row.cells.forEach(c => {
        const box = mk('card')
        if (c.caption) box.append(mk('cap', c.caption))
        const cell = PROTO.makeCell(c.mode); box.append(cell.stage); grid.append(box)
        jobs.push({ c, scope: cell.scope })
      })
    })
    sheet.append(grid); document.body.replaceChildren(sheet)
    const checks = jobs.map(({ c, scope }) => {
      const el = PROTO.renderState(scope, c.state, c.theme, c.mode, {}, c.size, c.density)
      return { theme: c.theme, mode: c.mode, state: c.state, size: c.size, density: c.density, violations: PROTO.overflowCheck(el) }
    })
    return checks
  }, spec)
  await page.locator('#sheet').screenshot({ path: file })
  return result
}

const report = existsSync(`${out}/overflow-report.json`) ? JSON.parse(readFileSync(`${out}/overflow-report.json`, 'utf8')) : { themes: {} }
let renders = 0, violations = 0
function record(checks, { keep = true } = {}) {
  for (const c of checks) {
    if (!keep) { renders++; violations += c.violations.length; if (c.violations.length) console.error('overflow', c.theme, c.mode, c.state, c.size, c.violations); continue }
    const t = report.themes[c.theme] ??= { results: {} }
    t.results[`${c.mode}/${c.state}`] = c.violations
    renders++; violations += c.violations.length
  }
  for (const t of Object.values(report.themes)) {
    t.renders = Object.keys(t.results).length
    t.violations = Object.values(t.results).reduce((n, v) => n + v.length, 0)
  }
  writeFileSync(`${out}/overflow-report.json`, JSON.stringify(report, null, 2) + '\n')
}

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 })
page.on('pageerror', e => console.error('page error:', e.message))
await page.goto(`file://${DS}/prototype.html?noinit=1`)
await page.addStyleTag({ content: SHEET_CSS })
await page.evaluate(() => document.fonts.ready)
const meta = await page.evaluate(() => PROTO.themes)
const states = await page.evaluate(() => PROTO.states.map(s => ({ id: s.id, label: s.label })))
const info = id => meta.find(t => t.id === id)
const PROTO_SIZES = await page.evaluate(() => PROTO.sizes), PROTO_DENSITIES = await page.evaluate(() => PROTO.densities)

if (!only || only === 'theme') for (const id of themeIds) {
  const th = info(id), t1 = Date.now()
  const spec = {
    title: `${th.name}`, sub: th.blurb + (th.axes?.length ? `  ·  cambia: ${th.axes.join(', ')}` : ''), width: 1320, cols: ['Claro', 'Oscuro'], heads: true,
    rows: states.map(s => ({ cells: ['light', 'dark'].map(mode => ({ theme: id, mode, state: s.id, caption: s.label })) })),
  }
  record(await renderSheet(page, spec, `${out}/theme-${id}.png`))
  log(`theme-${id}.png (${((Date.now() - t1) / 1000).toFixed(1)}s)`)
}

if (!only || only === 'compare') {
  for (const st of [...new Set(['definition', 'stress', compareState])]) {
    const label = states.find(s => s.id === st)?.label ?? st
    const spec = {
      title: `Comparativa de temas · ${label}`, sub: `El mismo estado («${st}») en cada tema, claro y oscuro.`, width: 1400, labelWidth: 170, cols: ['Claro', 'Oscuro'], heads: true,
      rows: themeIds.map(id => ({ label: info(id).name, sub: info(id).axes?.length ? info(id).axes.join(', ') : '', cells: ['light', 'dark'].map(mode => ({ theme: id, mode, state: st })) })),
    }
    const file = `${out}/compare-${st}.png`
    record(await renderSheet(page, spec, file))
    if (st === compareState) copyFileSync(file, `${out}/compare.png`)
    log(`compare-${st}.png`)
  }
}

if (!only || only === 'independence') {
  const wanted = ['cristal', 'ind-type', 'ind-color', 'ind-shape', 'ind-space', 'ind-shadow']
  const present = wanted.filter(id => info(id)), missing = wanted.filter(id => !info(id))
  console.log(`independence: present ${present.join(', ') || '-'}; skipped (not found) ${missing.join(', ') || '-'}`)
  const sts = ['definition', 'otherRepo']
  const spec = {
    title: 'Independencia de los ejes', sub: 'Cada variante cambia UN grupo de tokens sobre Cristal; lo demás debe quedarse igual.', width: 2500, labelWidth: 200,
    cols: sts.flatMap(s => ['light', 'dark'].map(m => `${states.find(x => x.id === s).label} · ${m === 'light' ? 'claro' : 'oscuro'}`)), heads: true,
    rows: present.map(id => ({ label: info(id).name, sub: id === 'cristal' ? 'referencia' : `cambia solo: ${info(id).axes?.join(', ') || id.replace('ind-', '')}`, cells: sts.flatMap(s => ['light', 'dark'].map(m => ({ theme: id, mode: m, state: s }))) })),
  }
  record(await renderSheet(page, spec, `${out}/independence.png`))
  log('independence.png')
}

if (!only || only === 'sizes') {
  const spec = {
    title: 'Los cuatro tamaños', sub: 'El estado «ID definido» de cada tema en S, M, L y XL, claro, densidad normal. El ancho y la letra crecen con el paso; el resto de la jerarquía no cambia.', width: 2800, labelWidth: 150,
    cols: PROTO_SIZES, heads: true,
    rows: themeIds.map(id => ({ label: info(id).name, cells: PROTO_SIZES.map(size => ({ theme: id, mode: 'light', state: 'definition', size, density: 'normal' })) })),
  }
  record(await renderSheet(page, spec, `${out}/compare-sizes.png`), { keep: false })
  log('compare-sizes.png')
}

// The whole matrix, overflow check only (no screenshots): themes × states × modes × sizes × densities.
if (!only || only === 'matrix') {
  const t1 = Date.now(), rows = []
  const res = await page.evaluate(({ themes, states, sizes, densities }) => {
    const out = []
    const cell = PROTO.makeCell('light'); document.body.replaceChildren(cell.stage)
    for (const theme of themes) for (const state of states) for (const mode of ['light', 'dark']) for (const size of sizes) for (const density of densities) {
      const el = PROTO.renderState(cell.scope, state, theme, mode, {}, size, density)
      out.push({ k: [theme, state, mode, size, density].join('/'), v: PROTO.overflowCheck(el) })
    }
    return out
  }, { themes: themeIds, states: states.map(s => s.id), sizes: PROTO_SIZES, densities: PROTO_DENSITIES })
  const bad = res.filter(r => r.v.length)
  report.matrix = { themes: themeIds.length, states: states.length, modes: 2, sizes: PROTO_SIZES.length, densities: PROTO_DENSITIES.length, renders: res.length, violations: bad.reduce((n, r) => n + r.v.length, 0), failing: bad.slice(0, 40) }
  writeFileSync(`${out}/overflow-report.json`, JSON.stringify(report, null, 2) + '\n')
  log(`matrix: ${res.length} renders, ${report.matrix.violations} violations (${((Date.now() - t1) / 1000).toFixed(1)}s)`)
}

await browser.close()
console.log(`overflow: ${renders} renders, ${violations} violations`)
log('done')
