// Token loader and resolver for the tooltip design system. No dependencies.
//
//   loadTheme('papel')  → { id, name, blurb, axes, overrides, merged, light, dark, errors }
//
// `merged` is the default tokens with the theme's overrides applied (still with «{refs}»).
// `light` / `dark` are resolved flat maps: path → value, e.g.
//   'text.title'           → { familyKey:'sans', family:'default', size:13, weight:500, italic:false, lineHeight:1.2, tracking:0, color:'#000000D9' }
//   'color.surface'        → '#F6F6F6D1'
//   'radius.container'     → 10
//   'shadow.container'     → [{ x:0, y:8, blur:24, spread:0, color:'#00000047' }, …]
//   'component.badge.pad-x'→ 5
// Paths of the primitive layer are kept too (`font.size.lg` → 13, `palette.ink` → '#000000').
import { readFileSync, readdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
export const DS = `${ROOT}/docs/design-system`
export const GROUPS = ['type', 'color', 'shape', 'space', 'shadow']

const readJSON = p => JSON.parse(readFileSync(p, 'utf8'))
const isObj = v => v && typeof v === 'object' && !Array.isArray(v)

export function deepMerge(base, over) {
  if (!isObj(base) || !isObj(over)) return over === undefined ? base : over
  const out = { ...base }
  for (const k of Object.keys(over)) out[k] = k in base ? deepMerge(base[k], over[k]) : over[k]
  return out
}

/** Which independent group a token path belongs to. `layer` is primitive | semantic. */
export function groupOf(layer, path) {
  const [a] = path.split('.')
  if (layer === 'primitive') return { font: 'type', palette: 'color', radius: 'shape', space: 'space', shadow: 'shadow' }[a]
  return { text: 'type', color: 'color', radius: 'shape', border: 'shape', space: 'space', size: 'space', shadow: 'shadow' }[a]
}

/** Flat list of [dotted path, value] for every leaf (arrays and composite text/colour tokens count as one leaf each). */
export function leaves(node, prefix = '', layer = '') {
  const out = []
  for (const [k, v] of Object.entries(node)) {
    const path = prefix ? `${prefix}.${k}` : k
    const composite = layer === 'semantic' && (/^text\./.test(path) && path.split('.').length === 2 || /^color\./.test(path) && path.split('.').length === 2)
    if (isObj(v) && !composite) out.push(...leaves(v, path, layer))
    else out.push([path, v])
  }
  return out
}

const REF = /^\{([^}]+)\}$/

export function loadTheme(id) {
  const base = readJSON(`${DS}/tokens.json`)
  let doc
  try { doc = readJSON(`${DS}/themes/${id}.json`) } catch { doc = readJSON(`${DS}/variants/${id}.json`) } // variants/: single-group demos
  const overrides = doc.overrides ?? {}
  const merged = {
    primitive: deepMerge(base.primitive, overrides.primitive ?? {}),
    semantic: deepMerge(base.semantic, overrides.semantic ?? {}),
    component: base.component,
  }
  const errors = []
  const theme = { id: doc.id, name: doc.name, blurb: doc.blurb, axes: doc.axes ?? [], baseline: !!doc.baseline, notes: doc.notes ?? [], overrides, merged, errors }
  for (const mode of ['light', 'dark']) theme[mode] = resolveMode(merged, mode, errors)
  return theme
}

export function listThemes() {
  return readdirSync(`${DS}/themes`).filter(f => f.endsWith('.json')).map(f => f.replace(/\.json$/, '')).sort()
}

function resolveMode(merged, mode, errors) {
  // Raw index: path → raw value, over primitive then semantic (names do not clash; the validator checks that).
  const raw = new Map()
  for (const layer of ['primitive', 'semantic'])
    for (const [p, v] of leaves(merged[layer], '', layer)) raw.set(p, v)
  for (const [p, v] of leaves(merged.component, 'component', 'component')) raw.set(p, v)

  const cache = new Map()
  const stack = []
  const get = (path, from) => {
    if (cache.has(path)) return cache.get(path)
    if (!raw.has(path)) { errors.push(`unresolved reference {${path}} in ${from}`); return undefined }
    if (stack.includes(path)) { errors.push(`reference cycle: ${[...stack, path].join(' → ')}`); return undefined }
    stack.push(path)
    const value = resolveValue(raw.get(path), path)
    stack.pop()
    cache.set(path, value)
    return value
  }
  const resolveValue = (v, from) => {
    if (typeof v === 'string') { const m = v.match(REF); return m ? get(m[1], from) : v }
    if (Array.isArray(v)) return v.map(x => resolveValue(x, from))
    if (isObj(v)) {
      if ('light' in v && 'dark' in v) return resolveValue(v[mode], from)
      const o = {}
      for (const [k, x] of Object.entries(v)) o[k] = resolveValue(x, from)
      if (/^text\./.test(from) && 'family' in v) { o.familyKey = (v.family.match(REF)?.[1] ?? '').split('.').pop(); }
      return o
    }
    return v
  }
  const out = {}
  for (const p of raw.keys()) out[p] = get(p, p)
  return out
}

// ── colour maths (WCAG 2.x) ─────────────────────────────────────────────────

export function parseHex(hex) {
  const h = hex.replace('#', '')
  const n = h.length === 3 ? h.split('').map(c => c + c).join('') : h
  const v = parseInt(n.slice(0, 6), 16)
  return { r: (v >> 16) & 255, g: (v >> 8) & 255, b: v & 255, a: n.length === 8 ? parseInt(n.slice(6), 16) / 255 : 1 }
}
export function over(fg, bg) { // fg with alpha over an opaque bg
  const a = fg.a
  return { r: fg.r * a + bg.r * (1 - a), g: fg.g * a + bg.g * (1 - a), b: fg.b * a + bg.b * (1 - a), a: 1 }
}
export function luminance({ r, g, b }) {
  const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4 }
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
}
export function ratio(a, b) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}
/** Contrast of `fgHex` on `surfaceHex`, with the surface laid over each worst-case page colour (white, black). Returns the minimum. */
export function contrastWorst(fgHex, surfaceHex, pages = ['#FFFFFF', '#000000']) {
  let worst = Infinity
  for (const page of pages) {
    const bg = over(parseHex(surfaceHex), parseHex(page))
    const fg = over(parseHex(fgHex), bg)
    worst = Math.min(worst, ratio(fg, bg))
  }
  return worst
}
