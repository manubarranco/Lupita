// Pins the resolved LIGHT map of theme `cristal` (the default, size M, density normal) to the numbers the SwiftUI port is tested against
// (Tests/LupitaCoreTests/ThemeParityTests.swift repeats this table).
//   node scripts/design-system/check-parity.mjs
import { loadTheme } from './lib.mjs'

const T = [
  // [description, token path, expected]  — theme Cristal, size M, density normal
  ['width at M', 'size.width', 440],
  ['padding 18', 'space.padding', 18],
  ['radius container 20', 'radius.container', 20],
  ['notice radius 14', 'radius.notice', 14],
  ['swatch radius 10', 'radius.swatch', 10],
  ['badge Capsule', 'radius.badge', 999],
  ['swatch size 20 at M', 'size.swatch', 20],
  ['spacing range-gap 10', 'space.range-gap', 10],
  ['spacing range-line-gap 6', 'space.range-line-gap', 6],
  ['spacing entry-gap 10', 'space.entry-gap', 10],
  ['spacing inline-gap 8', 'space.inline-gap', 8],
  ['spacing block-gap 12', 'space.block-gap', 12],
  ['spacing row-gap 5', 'space.row-gap', 5],
  ['spacing name-gap 3', 'space.name-gap', 3],
  ['row padding x 8 (hover band)', 'space.row-pad-x', 8],
  ['row padding y 4', 'space.row-pad-y', 4],
  ['gap above the meta line 4', 'space.meta-gap', 4],
  ['row radius 8', 'radius.row', 8],
  ['spacing swatch-gap 12', 'space.swatch-gap', 12],
  ['spacing swatch-inner-gap 6', 'space.swatch-inner-gap', 6],
  ['padding badge-x 8', 'space.badge-x', 8],
  ['padding badge-y 2', 'space.badge-y', 2],
  ['padding notice-x 16', 'space.notice-x', 16],
  ['padding notice-y 10', 'space.notice-y', 10],
  ['border container 1', 'border.container', 1],
  ['border swatch 1', 'border.swatch', 1],
  ['border notice 1', 'border.notice', 1],
  ['opacity 0.72 (suggestion)', 'color.suggestion-opacity', 0.72],
  ['title heading 14', 'text.title.size', 14],
  ['title .medium', 'text.title.weight', 500],
  ['title font role heading', 'text.title.familyKey', 'heading'],
  ['id code 11', 'text.id.size', 11],
  ['id .semibold', 'text.id.weight', 600],
  ['id font role code', 'text.id.familyKey', 'code'],
  ['description body 12', 'text.description.size', 12],
  ['description regular', 'text.description.weight', 400],
  ['repo label 10', 'text.repo.size', 10],
  ['repo .semibold', 'text.repo.weight', 600],
  ['location label 10', 'text.location.size', 10],
  ['location regular', 'text.location.weight', 400],
  ['location font role code', 'text.location.familyKey', 'code'],
  ['badge label 10', 'text.badge.size', 10],
  ['badge .semibold', 'text.badge.weight', 600],
  ['eyebrow label 10', 'text.eyebrow.size', 10],
  ['footnote label 10', 'text.footnote.size', 10],
  ['placeholder heading 14', 'text.placeholder.size', 14],
  ['placeholder .italic()', 'text.placeholder.italic', true],
  ['swatch label 10', 'text.swatch.size', 10],
  ['swatch font role code', 'text.swatch.familyKey', 'code'],
  ['notice body 12', 'text.notice.size', 12],
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

const theme = loadTheme('cristal')
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
