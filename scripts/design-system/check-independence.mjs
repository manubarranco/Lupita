// Each demo variant docs/design-system/variants/ind-<group>.json must change exactly one independent group.
//   node scripts/design-system/check-independence.mjs
import { existsSync, readFileSync } from 'node:fs'
import { DS, GROUPS, loadTheme, groupOf, leaves } from './lib.mjs'

const problems = []
const fail = m => problems.push(m)
const base = loadTheme('lupita')

// Group of a resolved-map path (primitive and semantic names do not clash, so one lookup table is enough).
function groupOfResolved(path) {
  const a = path.split('.')[0]
  if (a === 'component') return null // derived
  return { text: 'type', font: 'type', color: 'color', palette: 'color', radius: 'shape', border: 'shape', space: 'space', size: 'space', shadow: 'shadow' }[a] ?? '?'
}
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)

// Composite tokens mix groups: a text role carries its colour, a shadow layer carries its colour. Split them so a
// colour change that flows into text.repo or shadow.md counts for «color», not for «type» / «shadow».
function parts(path, v) {
  const a = path.split('.')[0]
  if (a === 'text' && v && typeof v === 'object') {
    const { color, ...rest } = v
    return [[path, 'type', rest], [`${path}.color`, 'color', color]]
  }
  if (a === 'shadow' && Array.isArray(v)) {
    return [[path, 'shadow', v.map(({ color, ...r }) => r)], ...v.map((l, i) => [`${path}[${i}].color`, 'color', l.color])] // layer count changes show up in the geometry part
  }
  const g = groupOfResolved(path)
  return g === null ? [] : [[path, g, v]]
}

for (const g of GROUPS) {
  const id = `ind-${g}`
  const file = `${DS}/variants/${id}.json`
  if (!existsSync(file)) { fail(`${id}: missing variants/${id}.json`); continue }
  let doc, theme
  try { doc = JSON.parse(readFileSync(file, 'utf8')); theme = loadTheme(id) } catch (e) { fail(`${id}: cannot load (${e.message})`); continue }
  const ov = doc.overrides ?? {}
  if (!same(doc.axes, [g])) fail(`${id}: axes must be ["${g}"], found ${JSON.stringify(doc.axes)}`)
  const ovLeaves = [...leaves(ov.primitive ?? {}, '', 'primitive').map(([p]) => ['primitive', p]), ...leaves(ov.semantic ?? {}, '', 'semantic').map(([p]) => ['semantic', p])]
  if (!ovLeaves.length) fail(`${id}: overrides are empty`)
  const touched = new Set(ovLeaves.map(([l, p]) => groupOf(l, p)))
  for (const t of touched) if (t !== g) fail(`${id}: overrides touch group ${t ?? 'unknown'} (${ovLeaves.filter(([l, p]) => groupOf(l, p) === t).map(([, p]) => p).slice(0, 3).join(', ')})`)
  theme.errors.forEach(e => fail(`${id}: ${e}`))
  let changed = 0
  for (const mode of ['light', 'dark']) {
    const keys = new Set([...Object.keys(base[mode]), ...Object.keys(theme[mode])])
    for (const key of keys) {
      const A = new Map(parts(key, base[mode][key]).map(([p, grp, v]) => [p, [grp, v]]))
      for (const [p, grp, v] of parts(key, theme[mode][key])) {
        if (/\]\.color$/.test(p) && !A.has(p)) continue
        if (same(A.get(p)?.[1], v)) continue
        if (grp === g) changed++
        else fail(`${id}: ${mode} ${p} differs but belongs to ${grp}`)
      }
    }
  }
  if (ovLeaves.length && !changed) fail(`${id}: overrides change nothing in group ${g}`)
}
const files = existsSync(`${DS}/variants`) ? (await import('node:fs')).readdirSync(`${DS}/variants`).filter(f => /^ind-.*\.json$/.test(f)) : []
for (const f of files) if (!GROUPS.some(g => f === `ind-${g}.json`)) fail(`unexpected variant file ${f}`)

problems.forEach(p => console.log('  ' + p))
console.log(`independence: ${GROUPS.length} variants expected · problems: ${problems.length}`)
process.exit(problems.length ? 1 : 0)
