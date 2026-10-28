// Compares the resolved LIGHT map of theme `lupita` with the literals used in the SwiftUI code (0.9.0).
//   node scripts/design-system/check-parity.mjs
import { loadTheme } from './lib.mjs'

const T = [
  // [swift literal, token path, expected]
  ['width 440', 'size.width', 440],
  ['padding 14', 'space.padding', 14],
  ['radius container 10', 'radius.container', 10],
  ['notice radius 8', 'radius.notice', 8],
  ['swatch radius 4', 'radius.swatch', 4],
  ['badge Capsule', 'radius.badge', 999],
  ['swatch size 20', 'size.swatch', 20],
  ['spacing range-gap 8', 'space.range-gap', 8],
  ['spacing range-line-gap 5', 'space.range-line-gap', 5],
  ['spacing entry-gap 8', 'space.entry-gap', 8],
  ['spacing inline-gap 6', 'space.inline-gap', 6],
  ['spacing block-gap 10', 'space.block-gap', 10],
  ['spacing row-gap 4', 'space.row-gap', 4],
  ['spacing name-gap 2', 'space.name-gap', 2],
  ['spacing swatch-gap 10', 'space.swatch-gap', 10],
  ['spacing swatch-inner-gap 5', 'space.swatch-inner-gap', 5],
  ['padding badge-x 5', 'space.badge-x', 5],
  ['padding badge-y 1', 'space.badge-y', 1],
  ['padding notice-x 12', 'space.notice-x', 12],
  ['padding notice-y 8', 'space.notice-y', 8],
  ['border container 1', 'border.container', 1],
  ['border swatch 1', 'border.swatch', 1],
  ['border notice 0', 'border.notice', 0],
  ['opacity 0.75 (suggestion)', 'color.suggestion-opacity', 0.75],
  ['title .body 13', 'text.title.size', 13],
  ['title .medium', 'text.title.weight', 500],
  ['id .callout 12', 'text.id.size', 12],
  ['id .semibold', 'text.id.weight', 600],
  ['id .monospaced', 'text.id.familyKey', 'mono'],
  ['description .callout 12', 'text.description.size', 12],
  ['description regular', 'text.description.weight', 400],
  ['repo .caption 10', 'text.repo.size', 10],
  ['repo .semibold', 'text.repo.weight', 600],
  ['location .caption 10', 'text.location.size', 10],
  ['location regular', 'text.location.weight', 400],
  ['location .monospaced', 'text.location.familyKey', 'mono'],
  ['badge .caption2 10', 'text.badge.size', 10],
  ['badge .semibold', 'text.badge.weight', 600],
  ['eyebrow .caption 10', 'text.eyebrow.size', 10],
  ['footnote .caption 10', 'text.footnote.size', 10],
  ['placeholder .body 13', 'text.placeholder.size', 13],
  ['placeholder .italic()', 'text.placeholder.italic', true],
  ['swatch .caption 10', 'text.swatch.size', 10],
  ['swatch .monospaced', 'text.swatch.familyKey', 'mono'],
  ['notice .callout 12', 'text.notice.size', 12],
  ['lineLimit title 4', 'component.limits.title-lines', 4],
  ['lineLimit range title 1', 'component.limits.range-title-lines', 1],
  ['lineLimit id 2', 'component.limits.id-lines', 2],
  ['lineLimit description 4', 'component.limits.description-lines', 4],
  ['lineLimit location 1', 'component.limits.location-lines', 1],
  ['max rows 3', 'component.limits.max-rows', 3],
]

// text.<role>.<field> → look inside the composite text token; everything else is a flat key of the resolved map.
function lookup(map, path) {
  if (path in map) return map[path]
  const m = path.match(/^(text\.[^.]+)\.(.+)$/)
  return m ? map[m[1]]?.[m[2]] : undefined
}

const theme = loadTheme('lupita')
const light = theme.light
let bad = 0
const show = v => v === undefined ? 'undefined' : JSON.stringify(v)
const w = [Math.max(...T.map(r => r[0].length)), Math.max(...T.map(r => r[1].length))]
for (const [lit, path, exp] of T) {
  const act = lookup(light, path)
  const ok = act === exp
  if (!ok) bad++
  console.log(`${lit.padEnd(w[0])} → ${path.padEnd(w[1])}  expected ${show(exp).padEnd(6)} actual ${show(act).padEnd(6)} ${ok ? '✓' : '✗'}`)
}
const undef = Object.entries(light).filter(([p, v]) => p.startsWith('component.') && v === undefined).map(([p]) => p)
undef.forEach(p => { bad++; console.log(`component path resolves to undefined: ${p} ✗`) })
theme.errors.forEach(e => { bad++; console.log(`resolver error: ${e} ✗`) })
console.log(`parity: ${T.length} checks · mismatches: ${bad}${undef.length ? ` (undefined component paths: ${undef.length})` : ''}`)
process.exit(bad ? 1 : 0)
